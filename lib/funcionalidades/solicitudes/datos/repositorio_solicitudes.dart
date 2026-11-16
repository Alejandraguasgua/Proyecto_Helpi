import '../../../nucleo/servicios/cliente_api.dart';

class PaginaSolicitudes {
  const PaginaSolicitudes(this.datos, this.cursor);

  final List<Map<String, dynamic>> datos;
  final String? cursor;
}

class PaginaCalificaciones {
  const PaginaCalificaciones({
    required this.datos,
    required this.promedio,
    required this.totalCalificaciones,
    this.cursor,
  });

  final List<Map<String, dynamic>> datos;
  final double? promedio;
  final int totalCalificaciones;
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

  Future<Map<String, dynamic>> guardar(
    Map<String, dynamic> datos, {
    String? id,
  }) async {
    final respuesta = await _api.enviar(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/solicitudes' : '/solicitudes/${Uri.encodeComponent(id)}',
      datos: datos,
    );

    return Map<String, dynamic>.from(respuesta);
  }

  Future<Map<String, dynamic>> duplicar(
    String idOrigen,
    Map<String, dynamic> datos,
  ) async {
    final respuesta = await _api.enviar(
      'POST',
      '/solicitudes/${Uri.encodeComponent(idOrigen)}/duplicar',
      datos: datos,
    );

    return Map<String, dynamic>.from(respuesta);
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

  Future<Map<String, dynamic>> calificar(
    String idSolicitud, {
    required int estrellas,
    String comentario = '',
  }) async {
    final respuesta = await _api.enviar(
      'POST',
      '/solicitudes/${Uri.encodeComponent(idSolicitud)}/calificaciones',
      datos: {'estrellas': estrellas, 'comentario': comentario.trim()},
    );

    return Map<String, dynamic>.from(respuesta);
  }

  Future<PaginaCalificaciones> listarCalificacionesPerfil(
    String uidPrestador, {
    String? cursor,
    int limite = 10,
  }) async {
    final consulta = <String, String>{
      'limite': '$limite',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };

    final respuesta = await _api.enviar(
      'GET',
      '/perfiles/${Uri.encodeComponent(uidPrestador)}/calificaciones',
      consulta: consulta,
    );

    final elementos = respuesta['datos'];
    final lista = elementos is List
        ? elementos
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    final promedioRaw = respuesta['promedio'];
    final promedio = promedioRaw is num ? promedioRaw.toDouble() : null;
    final totalRaw = respuesta['totalCalificaciones'];
    final total = totalRaw is num ? totalRaw.toInt() : 0;

    return PaginaCalificaciones(
      datos: lista,
      promedio: promedio,
      totalCalificaciones: total,
      cursor: respuesta['siguienteCursor']?.toString(),
    );
  }
}
