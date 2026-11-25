import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'firebase_options.dart';
import 'nucleo/tema/tema_app.dart';
import 'nucleo/servicios/servicio_notificaciones.dart';
import 'funcionalidades/bienvenida/presentacion/pantalla_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env.mapbox', isOptional: true);
  } catch (_) {
    debugPrint('No se pudo cargar .env.mapbox');
  }

  final String token =
      (dotenv.isInitialized ? dotenv.maybeGet('MAPBOX_ACCESS_TOKEN') : null)
          ?.trim() ??
      '';

  if (token.isNotEmpty &&
      token != 'PEGA_AQUI_MI_TOKEN_PUBLICO_PK' &&
      token.startsWith('pk.')) {
    MapboxOptions.setAccessToken(token);
  }

  // Inicialización de Firebase.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  debugPrint('Firebase inicializado correctamente');
  debugPrint('Proyecto Firebase: ${Firebase.app().options.projectId}');
  debugPrint('App ID: ${Firebase.app().options.appId}');

  //Notificaciones desactivadas temporalmente.
  await ServicioNotificaciones.iniciar();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpi',
      debugShowCheckedModeBanner: false,
      navigatorKey: ServicioNotificaciones.navegador,
      scaffoldMessengerKey: ServicioNotificaciones.mensajes,
      theme: TemaApp.claro,
      home: const PantallaLogo(),
    );
  }
}
