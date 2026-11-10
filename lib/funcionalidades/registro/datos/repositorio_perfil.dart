import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RepositorioPerfil {
  User _usuarioActual() {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión para acceder al perfil.');
    }

    return usuario;
  }

  Future<void> guardar(Map<String, dynamic> perfil) async {
    final usuario = _usuarioActual();
    final datos = Map<String, dynamic>.from(perfil);

    // La imagen se conectará a Storage por separado.
    datos.remove('foto');

    // Estos datos corresponden a la cuenta autenticada.
    datos['uid'] = usuario.uid;
    datos['correo'] = usuario.email ?? '';
    datos['perfilCompleto'] = true;
    datos['fechaActualizacion'] = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .set(datos, SetOptions(merge: true));
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