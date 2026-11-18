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

  /// Cantidad de notificaciones sin leer (número de la campanita).
  Future<int> contarSinLeer() async {
    final respuesta = await _api.enviar('GET', '/notificaciones/sin-leer');
    final total = respuesta['total'];
    return total is num ? total.toInt() : 0;
  }

  /// Alertas del administrador que el usuario aún no ha visto.
  Future<List<Map<String, dynamic>>> avisosPendientes() async {
    final respuesta = await _api.enviar(
      'GET',
      '/notificaciones/avisos-pendientes',
    );

    final elementos = respuesta['datos'];
    if (elementos is! List) return [];

    return elementos
        .whereType<Map>()
        .map((elemento) => Map<String, dynamic>.from(elemento))
        .toList();
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
