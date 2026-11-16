import '../../../nucleo/servicios/cliente_api.dart';

class PaginaNotificaciones {
  const PaginaNotificaciones(this.datos, this.cursor);

  final List<Map<String, dynamic>> datos;
  final String? cursor;
}

class RepositorioNotificaciones {
  final _api = ClienteApi();

  Future<PaginaNotificaciones> listar({String? cursor}) async {
    final consulta = <String, String>{
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };

    final respuesta = await _api.enviar(
      'GET',
      '/notificaciones',
      consulta: consulta.isEmpty ? null : consulta,
    );

    final elementos = respuesta['datos'];

    if (elementos is! List) {
      throw Exception('No se pudo interpretar la lista de notificaciones.');
    }

    final datos = elementos.map((elemento) {
      if (elemento is! Map) {
        throw Exception('Se recibió una notificación con formato incorrecto.');
      }

      return Map<String, dynamic>.from(elemento);
    }).toList();

    return PaginaNotificaciones(datos, respuesta['siguienteCursor'] as String?);
  }

  Future<Map<String, dynamic>?> marcarLeida(String id) async {
    final respuesta = await _api.enviar(
      'PATCH',
      '/notificaciones/${Uri.encodeComponent(id)}',
    );

    final datos = respuesta['datos'];
    if (datos is Map) {
      return Map<String, dynamic>.from(datos);
    }
    return null;
  }
}
