import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'firebase_options.dart';
import 'nucleo/tema/tema_app.dart';
import 'funcionalidades/bienvenida/presentacion/pantalla_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env.mapbox', isOptional: true);
  } catch (_) {
    // Si el archivo .env.mapbox falta o no es legible, la pantalla del mapa mostrará un aviso claro.
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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpi',
      debugShowCheckedModeBanner: false,
      theme: TemaApp.claro,
      home: const PantallaLogo(),
    );
  }
}
