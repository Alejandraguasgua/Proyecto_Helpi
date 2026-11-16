import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../nucleo/servicios/cliente_api.dart';

class RepositorioAdmin {
  final _db = FirebaseFirestore.instance;
  final _api = ClienteApi();

  /// Es administrador quien tiene la claim `admin: true` en su token.
  /// La misma claim la exige el servidor en las rutas /admin/*.
  /// Se asigna con servidor_helpi/scripts/crear_admin.js.
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

  /// Reportes abiertos, desde el servidor (GET /admin/reportes).
  Future<List<Map<String, dynamic>>> reportes() async {
    final respuesta = await _api.enviar('GET', '/admin/reportes');
    final datos = respuesta['datos'];

    if (datos is! List) return [];

    return datos
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// PATCH /admin/usuarios/:id
  Future<void> suspenderUsuario(String uid, bool suspendido) async {
    await _api.enviar(
      'PATCH',
      '/admin/usuarios/${Uri.encodeComponent(uid)}',
      datos: {'suspendido': suspendido},
    );
  }

  /// DELETE /admin/solicitudes/:id (la deja como Cancelada).
  Future<void> retirarSolicitud(String id) async {
    await _api.enviar(
      'DELETE',
      '/admin/solicitudes/${Uri.encodeComponent(id)}',
    );
  }
}
