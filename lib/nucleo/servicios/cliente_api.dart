import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ClienteApi {
  static const base = String.fromEnvironment(
    'HELPI_API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  Future<Map<String, dynamic>> enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? datos,
    Map<String, String>? consulta,
  }) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      throw Exception('Inicia sesión para continuar.');
    }

    final token = await usuario.getIdToken();

    if (token == null) {
      throw Exception('No se pudo validar tu sesión. Vuelve a iniciar sesión.');
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
        throw Exception(
          'El servidor devolvió una respuesta inesperada '
          '(${respuesta.statusCode}).',
        );
      }

      if (contenido is! Map<String, dynamic>) {
        throw Exception(
          'La respuesta del servidor tiene un formato incorrecto.',
        );
      }

      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        throw Exception(
          contenido['mensaje']?.toString() ??
              'No se pudo completar la operación '
                  '(${respuesta.statusCode}).',
        );
      }

      return contenido;
    } on TimeoutException {
      throw Exception(
        'El servidor tardó demasiado. Revisa la conexión e inténtalo otra vez.',
      );
    } on http.ClientException {
      throw Exception(
        'No se pudo conectar con el servidor de Helpi. '
        'Comprueba que esté ejecutándose.',
      );
    } finally {
      cliente.close();
    }
  }
}
