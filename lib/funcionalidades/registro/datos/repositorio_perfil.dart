import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../nucleo/servicios/cliente_api.dart';
import '../../terminos/datos/contenido_terminos.dart';

class RepositorioPerfil {
  static Future<void>? _inicializacionGoogle;

  static const _webClientId =
      '400034948021-3rc82p0fle2jd2r3i95e451rcit6t615'
      '.apps.googleusercontent.com';
  User _usuarioActual() {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión para acceder al perfil.');
    }

    return usuario;
  }

  static const Set<String> _idsDocumentoValidos = {
    documentoTerminosId,
    'terminos_y_privacidad_helpi',
  };

  static bool tieneAceptacionVigente(
    Map<String, dynamic>? perfil, {
    String? uidAutenticado,
  }) {
    if (perfil == null) return false;
    final aceptacion = perfil['terminosAceptados'];
    if (aceptacion is! Map) return false;

    final uidEsperado =
        uidAutenticado ??
        perfil['uid']?.toString() ??
        FirebaseAuth.instance.currentUser?.uid;
    final uidAceptacion = aceptacion['uid']?.toString().trim();

    if (uidEsperado != null &&
        uidEsperado.isNotEmpty &&
        uidAceptacion != null &&
        uidAceptacion.isNotEmpty &&
        uidAceptacion != uidEsperado) {
      return false;
    }

    final docId = aceptacion['documentoId']?.toString();
    final documentoValido =
        docId == null || _idsDocumentoValidos.contains(docId);
    final fecha = aceptacion['fechaAceptacion']?.toString().trim() ?? '';

    return documentoValido &&
        aceptacion['versionTerminos'] == versionTerminosVigente &&
        aceptacion['versionPrivacidad'] == versionPrivacidadVigente &&
        fecha.isNotEmpty;
  }

  Future<Map<String, dynamic>> registrarAceptacionTerminos({
    required String versionTerminos,
    required String versionPrivacidad,
  }) async {
    final usuario = _usuarioActual();

    // 1. Envía al backend para validar y registrar con timestamp del servidor e historial
    final respuesta = await ClienteApi().enviar(
      'POST',
      '/terminos/aceptar',
      datos: {
        'versionTerminos': versionTerminos,
        'versionPrivacidad': versionPrivacidad,
      },
    );

    final datosRespuesta = respuesta['datos'];
    final fecha =
        (datosRespuesta is Map ? datosRespuesta['fechaAceptacion'] : null)
            ?.toString() ??
        DateTime.now().toUtc().toIso8601String();
    final idRegistro = (datosRespuesta is Map ? datosRespuesta['id'] : null)
        ?.toString();

    final datosAceptacion = <String, dynamic>{
      if (idRegistro != null && idRegistro.isNotEmpty) 'id': idRegistro,
      'uid': usuario.uid,
      'documentoId': documentoTerminosId,
      'versionTerminos': versionTerminos,
      'avisoPrivacidadId': documentoPrivacidadId,
      'versionPrivacidad': versionPrivacidad,
      'fechaAceptacion': fecha,
    };

    // 2. Asegura la persistencia en el documento del usuario autenticado en Firestore
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .set({
          'uid': usuario.uid,
          'terminosAceptados': datosAceptacion,
          'fechaActualizacion': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    return datosAceptacion;
  }

  Future<void> guardar(Map<String, dynamic> perfil) async {
    final usuario = _usuarioActual();
    final datos = Map<String, dynamic>.from(perfil);

    // La imagen se conectará a Storage por separado.
    datos.remove('foto');

    // Nunca sobrescribe ni invalida terminosAceptados o su historial al guardar otros campos o cambiar rol.
    if (!tieneAceptacionVigente(datos, uidAutenticado: usuario.uid)) {
      datos.remove('terminosAceptados');
    }
    datos.remove('historialAceptacionesTerminos');

    // Estos datos corresponden exclusivamente a la cuenta autenticada.
    datos['uid'] = usuario.uid;
    datos['correo'] = usuario.email ?? '';
    datos['perfilCompleto'] = true;
    datos['fechaActualizacion'] = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .set(datos, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> actualizarCampos(
    Map<String, dynamic> cambios,
  ) async {
    final usuario = _usuarioActual();

    const llavesEditables = <String>{
      'rol',
      'nombre',
      'telefono',
      'ciudad',
      'sector',
      'presentacion',
      'disponibilidad',
      'habilidades',
      'categorias',
    };

    final cargaUtil = <String, dynamic>{};
    for (final entrada in cambios.entries) {
      if (llavesEditables.contains(entrada.key)) {
        cargaUtil[entrada.key] = entrada.value;
      }
    }

    // 1. Valida y persiste en el servidor (transacción que protege UID, correo, términos y reputación)
    final respuesta = await ClienteApi().enviar(
      'PATCH',
      '/perfil',
      datos: cargaUtil,
    );

    // 2. Sincroniza únicamente los campos editables en Firestore sin sobrescribir campos protegidos
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .set({
          ...cargaUtil,
          'fechaActualizacion': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    final leido = await leer();
    if (leido != null) {
      return leido;
    }

    final datosServidor = respuesta['datos'];
    if (datosServidor is Map) {
      return Map<String, dynamic>.from(datosServidor);
    }

    return cargaUtil;
  }

  Future<void> reautenticarUsuario() async {
    final usuario = _usuarioActual();

    if (kIsWeb) {
      final proveedor = GoogleAuthProvider();
      proveedor.setCustomParameters({'prompt': 'select_account'});
      await usuario.reauthenticateWithPopup(proveedor);
      return;
    }

    final googleSignIn = GoogleSignIn.instance;
    await (_inicializacionGoogle ??= googleSignIn.initialize(
      serverClientId: _webClientId,
    ));

    if (!googleSignIn.supportsAuthenticate()) {
      throw StateError('No se pudo verificar tu identidad en esta plataforma.');
    }

    final usuarioGoogle = await googleSignIn.authenticate();
    final idToken = usuarioGoogle.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'No se recibió la credencial de Google para verificar tu identidad.',
      );
    }

    final credencial = GoogleAuthProvider.credential(idToken: idToken);
    await usuario.reauthenticateWithCredential(credencial);
  }

  Future<void> eliminarCuenta() async {
    final usuario = _usuarioActual();

    // 1. Verifica de nuevo la identidad del usuario con Google Sign-In
    await reautenticarUsuario();

    // 2. Fuerza la renovación del ID token tras la reautenticación
    await usuario.getIdToken(true);

    // 3. Solicita al servidor eliminar los datos personales y la cuenta de autenticación
    // (el servidor valida que no existan servicios activos y usa exclusivamente el UID del token)
    await ClienteApi().enviar('DELETE', '/perfil');

    // 4. Limpia preferencias locales y cierra cualquier sesión local remanente
    await borrar();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Si el servidor ya eliminó el usuario en Auth, signOut puede completarse o ignorarse
    }
  }

  Future<Map<String, dynamic>?> leer() async {
    final usuario = _usuarioActual();

    // Si falla la conexión o faltan permisos, el error se propaga.
    // No se interpreta un error como si el usuario no tuviera perfil.
    final documento = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .get(const GetOptions(source: Source.server));

    final datos = documento.data();

    if (!documento.exists || datos == null) {
      return null;
    }

    // Un documento con solo los datos de Google no es un perfil completo.
    if (datos['perfilCompleto'] != true) {
      return null;
    }

    return Map<String, dynamic>.from(datos);
  }

  Future<void> borrar() async {
    // Conserva la eliminación del antiguo perfil local.
    // No elimina el perfil de Firestore.
    await SharedPreferencesAsync().remove('helpi_perfil_demo');
  }
}
