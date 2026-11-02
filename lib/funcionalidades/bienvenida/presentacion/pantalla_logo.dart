import 'dart:async';

import 'package:flutter/material.dart';

import '../../../nucleo/tema/colores_app.dart';
import 'pantalla_bienvenida.dart';

class PantallaLogo extends StatefulWidget {
  const PantallaLogo({super.key});

  @override
  State<PantallaLogo> createState() => _EstadoPantallaLogo();
}

class _EstadoPantallaLogo extends State<PantallaLogo> {
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();

    _temporizador = Timer(
      const Duration(seconds: 3),
      _abrirBienvenida,
    );
  }

  void _abrirBienvenida() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const PantallaBienvenida(),
      ),
    );
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.grisClaro,
      body: Center(
        child: Image.asset(
          'assets/imagenes/portada.png',
          width: 160,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}