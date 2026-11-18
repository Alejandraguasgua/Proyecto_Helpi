import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../nucleo/servicios/cliente_api.dart';

class RepositorioAdmin {
  final _db = FirebaseFirestore.instance;
  final _api = ClienteApi();

  /// Es administrador quien tiene la claim `admin: true` en su token.
  /// La misma claim la exige el servidor en las rutas /admin/*.
  /// Se asigna con servidor_helpi/scripts/crear_admin.js o desde el panel.
  Future<bool> esAdministrador() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return false;

    try {
      // true = fuerza renovar el token para ver claims recién asignadas.
      final token = await usuario.getIdTokenResult(true);
      return token.claims?['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  String? get uidActual => FirebaseAuth.instance.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Suspensión
  // ---------------------------------------------------------------------------

  /// Fecha en la que termina una suspensión temporal (null si es indefinida).
  static DateTime? suspendidoHasta(Map<String, dynamic> usuario) {
    final valor = usuario['suspendidoHasta'];
    if (valor == null) return null;
    if (valor is Timestamp) return valor.toDate();
    return DateTime.tryParse(valor.toString());
  }

  /// true si la cuenta está suspendida ahora mismo.
  /// Una suspensión temporal vencida ya no cuenta.
  static bool estaSuspendido(Map<String, dynamic> usuario) {
    if (usuario['suspendido'] != true) return false;
    final hasta = suspendidoHasta(usuario);
    return hasta == null || hasta.isAfter(DateTime.now());
  }

  /// `dias` = null → suspensión indefinida.
  Future<void> suspenderUsuario(
    String uid, {
    int? dias,
    String? motivo,
  }) async {
    await _api.enviar(
      'PATCH',
      '/admin/usuarios/${Uri.encodeComponent(uid)}',
      datos: {
        'suspendido': true,
        'dias': dias,
        if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      },
    );
  }

  Future<void> reactivarUsuario(String uid) async {
    await _api.enviar(
      'PATCH',
      '/admin/usuarios/${Uri.encodeComponent(uid)}',
      datos: {'suspendido': false},
    );
  }

  /// Envía una alerta: le llega en Notificaciones y le aparece en una
  /// ventana flotante la próxima vez que abra la app.
  Future<void> enviarAviso(String uid, String mensaje, {String? titulo}) async {
    await _api.enviar(
      'POST',
      '/admin/usuarios/${Uri.encodeComponent(uid)}/aviso',
      datos: {
        'mensaje': mensaje.trim(),
        if (titulo != null && titulo.trim().isNotEmpty) 'titulo': titulo.trim(),
      },
    );
  }

  /// Da o quita el permiso de administrador.
  Future<void> cambiarAdministrador(String uid, bool admin) async {
    await _api.enviar(
      'PATCH',
      '/admin/usuarios/${Uri.encodeComponent(uid)}/administrador',
      datos: {'admin': admin},
    );
  }

  // ---------------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------------

  Future<int> contar(String coleccion, {String? campo, Object? valor}) async {
    Query<Map<String, dynamic>> consulta = _db.collection(coleccion);

    if (campo != null) {
      consulta = consulta.where(campo, isEqualTo: valor);
    }

    final resultado = await consulta.count().get();
    return resultado.count ?? 0;
  }

  Stream<List<Map<String, dynamic>>> usuarios() {
    return _db.collection('usuarios').limit(200).snapshots().map(
          (instantanea) => instantanea.docs
              .map((doc) => {...doc.data(), 'uid': doc.id})
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> solicitudes() {
    return _db.collection('solicitudes').limit(200).snapshots().map(
          (instantanea) => instantanea.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Solicitudes
  // ---------------------------------------------------------------------------

  /// DELETE /admin/solicitudes/:id (la deja como Cancelada).
  Future<void> retirarSolicitud(String id) async {
    await _api.enviar(
      'DELETE',
      '/admin/solicitudes/${Uri.encodeComponent(id)}',
    );
  }

  /// Borra la solicitud de la base de datos, con sus calificaciones y avisos.
  Future<void> eliminarSolicitud(String id, {String? motivo}) async {
    await _api.enviar(
      'DELETE',
      '/admin/solicitudes/${Uri.encodeComponent(id)}/definitivo',
      datos: {
        if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Reportes
  // ---------------------------------------------------------------------------

  /// `estado`: abierto, resuelto o descartado.
  Future<List<Map<String, dynamic>>> reportes({String estado = 'abierto'}) async {
    final respuesta = await _api.enviar(
      'GET',
      '/admin/reportes',
      consulta: {'estado': estado},
    );
    return _lista(respuesta['datos']);
  }

  /// `estado`: resuelto o descartado.
  Future<void> atenderReporte(String id, String estado, {String? nota}) async {
    await _api.enviar(
      'PATCH',
      '/admin/reportes/${Uri.encodeComponent(id)}',
      datos: {
        'estado': estado,
        if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Historial
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> historial() async {
    final respuesta = await _api.enviar('GET', '/admin/historial');
    return _lista(respuesta['datos']);
  }

  List<Map<String, dynamic>> _lista(Object? datos) {
    if (datos is! List) return [];

    return datos
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
