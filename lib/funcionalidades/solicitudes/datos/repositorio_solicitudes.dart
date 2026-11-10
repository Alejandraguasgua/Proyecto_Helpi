import '../../../nucleo/servicios/cliente_api.dart';

class PaginaSolicitudes {
  const PaginaSolicitudes(this.datos, this.cursor);

  final List<Map<String, dynamic>> datos;
  final String? cursor;
}

class RepositorioSolicitudes {
  final _api = ClienteApi();

  Future<PaginaSolicitudes> listar(Map<String, String> filtros) async {
    final respuesta = await _api.enviar(
      'GET',
      '/solicitudes',
      consulta: filtros,
    );

    final elementos = respuesta['datos'];

    if (elementos is! List) {
      throw Exception('No se pudo interpretar la lista de solicitudes.');
    }

    final datos = elementos.map((elemento) {
      if (elemento is! Map) {
        throw Exception('Se recibió una solicitud con formato incorrecto.');
      }

      return Map<String, dynamic>.from(elemento);
    }).toList();

    return PaginaSolicitudes(datos, respuesta['siguienteCursor'] as String?);
  }

  Future<Map<String, dynamic>> obtener(String id) async {
    final respuesta = await _api.enviar(
      'GET',
      '/solicitudes/${Uri.encodeComponent(id)}',
    );

    return Map<String, dynamic>.from(respuesta);
  }

  Future<Map<String, dynamic>?> obtenerPerfilPublico(String uid) async {
    try {
      final respuesta = await _api.enviar(
        'GET',
        '/perfiles/${Uri.encodeComponent(uid)}',
      );

      final datos = respuesta['datos'];
      if (datos is Map) {
        return Map<String, dynamic>.from(datos);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(Map<String, dynamic> datos, {String? id}) async {
    await _api.enviar(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/solicitudes' : '/solicitudes/${Uri.encodeComponent(id)}',
      datos: datos,
    );
  }

  Future<void> accion(
    String id,
    String accion, {
    Map<String, dynamic>? datos,
  }) async {
    await _api.enviar(
      'POST',
      '/solicitudes/${Uri.encodeComponent(id)}/'
          '${Uri.encodeComponent(accion)}',
      datos: datos ?? {},
    );
  }
}
