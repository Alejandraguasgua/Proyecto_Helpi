import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ErrorApiHelpi implements Exception {
  const ErrorApiHelpi({
    required this.mensaje,
    this.codigoEstado,
    this.codigoError,
    this.ruta,
  });

  final String mensaje;
  final int? codigoEstado;
  final String? codigoError;
  final String? ruta;

  bool get esFaltaAceptacionTerminos =>
      codigoEstado == 403 &&
      mensaje.contains('Debes aceptar los Términos y condiciones');

  @override
  String toString() => mensaje;
}

class ClienteApi {
  static const base = String.fromEnvironment(
    'HELPI_API_BASE_URL',
    defaultValue: 'https://servidor-helpi.onrender.com/api',
  );

  Future<Map<String, dynamic>> enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? datos,
    Map<String, String>? consulta,
  }) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      throw const ErrorApiHelpi(
        mensaje: 'Inicia sesión para continuar.',
        codigoEstado: 401,
      );
    }

    final token = await usuario.getIdToken();

    if (token == null || token.isEmpty) {
      throw const ErrorApiHelpi(
        mensaje: 'No se pudo validar tu sesión. Vuelve a iniciar sesión.',
        codigoEstado: 401,
      );
    }

    final uri = Uri.parse('$base$ruta').replace(queryParameters: consulta);

    final cliente = http.Client();

    try {
      final peticion = http.Request(metodo, uri);

      peticion.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });

      if (datos != null) {
        peticion.body = jsonEncode(datos);
      }

      final flujo = await cliente
          .send(peticion)
          .timeout(const Duration(seconds: 30));

      final respuesta = await http.Response.fromStream(flujo)
          .timeout(const Duration(seconds: 30));

      final Object? contenido;

      try {
        contenido = jsonDecode(respuesta.body);
      } on FormatException {
        debugPrint(
          '[ClienteApi] Respuesta no JSON en $metodo $ruta '
          '(HTTP ${respuesta.statusCode})',
        );
        throw ErrorApiHelpi(
          mensaje:
              'El servidor devolvió una respuesta inesperada '
              '(HTTP ${respuesta.statusCode}). Pulsa Reintentar.',
          codigoEstado: respuesta.statusCode,
          ruta: ruta,
        );
      }

      if (contenido is! Map<String, dynamic>) {
        throw ErrorApiHelpi(
          mensaje: 'La respuesta del servidor tiene un formato incorrecto.',
          codigoEstado: respuesta.statusCode,
          ruta: ruta,
        );
      }

      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        final mensajeServidor = contenido['mensaje']?.toString().trim();
        final mensajeFinal =
            (mensajeServidor != null && mensajeServidor.isNotEmpty)
            ? mensajeServidor
            : 'El servidor no pudo completar la solicitud '
                  '(HTTP ${respuesta.statusCode}). Pulsa Reintentar.';

        debugPrint(
          '[ClienteApi] Error en $metodo $ruta -> '
          'HTTP ${respuesta.statusCode}: $mensajeFinal',
        );

        throw ErrorApiHelpi(
          mensaje: mensajeFinal,
          codigoEstado: respuesta.statusCode,
          codigoError: contenido['codigo']?.toString(),
          ruta: ruta,
        );
      }

      return contenido;
    } on TimeoutException {
      debugPrint('[ClienteApi] Tiempo agotado en $metodo $ruta');
      throw ErrorApiHelpi(
        mensaje:
            'El servidor tardó demasiado en responder. '
            'Revisa tu conexión y pulsa Reintentar.',
        ruta: ruta,
      );
    } on http.ClientException {
      debugPrint('[ClienteApi] Fallo de red al conectar con $base$ruta');
      throw ErrorApiHelpi(
        mensaje:
            'No se pudo conectar con el servidor de Helpi ($base). '
            'Comprueba que el servidor esté ejecutándose y pulsa Reintentar.',
        ruta: ruta,
      );
    } finally {
      cliente.close();
    }
  }
}
