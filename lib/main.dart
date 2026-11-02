import 'package:flutter/material.dart';

import 'nucleo/tema/tema_app.dart';
import 'funcionalidades/bienvenida/presentacion/pantalla_logo.dart';

void main() {
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
