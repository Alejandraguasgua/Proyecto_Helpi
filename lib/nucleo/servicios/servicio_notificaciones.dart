import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../funcionalidades/solicitudes/presentacion/pantalla_detalle_servicio.dart';
import 'cliente_api.dart';

class ServicioNotificaciones {
  /// Se conectan en MaterialApp (ver main.dart).
  static final navegador = GlobalKey<NavigatorState>();
  static final mensajes = GlobalKey<ScaffoldMessengerState>();

  static bool _iniciado = false;

  static Future<void> iniciar() async {
    // El push en web necesita service worker y clave VAPID (aparte).
    if (kIsWeb || _iniciado) return;
    _iniciado = true;

    await FirebaseMessaging.instance.requestPermission();

    // Registra el token cada vez que hay una sesión activa.
    FirebaseAuth.instance.authStateChanges().listen((usuario) {
      if (usuario != null) _registrarToken();
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _registrarToken());

    // App abierta (primer plano): FCM no muestra banner, lo mostramos nosotros.
    FirebaseMessaging.onMessage.listen(_enPrimerPlano);

    // App en segundo plano y el usuario toca la notificación.
    FirebaseMessaging.onMessageOpenedApp.listen(_abrirDetalle);

    // App cerrada y el usuario toca la notificación.
    final inicial = await FirebaseMessaging.instance.getInitialMessage();
    if (inicial != null) {
      Future<void>.delayed(
        const Duration(seconds: 3),
        () => _abrirDetalle(inicial),
      );
    }
  }

  /// Llamar antes de cerrar sesión: invalida el token de este teléfono para que
  /// no siga recibiendo avisos de la cuenta anterior (el servidor limpia el
  /// token muerto la próxima vez que intente enviarle algo).
  static Future<void> quitarToken() async {
    if (kIsWeb) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('No se pudo invalidar el token: $e');
    }
  }

  static Future<void> _registrarToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.length < 20) return;
      // Para probar desde Firebase Console > Messaging > "Enviar mensaje de prueba".
      debugPrint('FCM TOKEN: $token');
      await ClienteApi().enviar(
        'POST',
        '/dispositivos',
        datos: {'token': token},
      );
    } catch (e) {
      debugPrint('No se pudo registrar el dispositivo: $e');
    }
  }

  static void _enPrimerPlano(RemoteMessage mensaje) {
    final n = mensaje.notification;
    if (n == null) return;

    mensajes.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n.title != null)
                Text(
                  n.title!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (n.body != null) Text(n.body!),
            ],
          ),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => _abrirDetalle(mensaje),
          ),
        ),
      );
  }

  static void _abrirDetalle(RemoteMessage mensaje) {
    final id = mensaje.data['solicitudId']?.toString();
    if (id == null || id.isEmpty) return;
    navegador.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => PantallaDetalleServicio(id: id)),
    );
  }
}
