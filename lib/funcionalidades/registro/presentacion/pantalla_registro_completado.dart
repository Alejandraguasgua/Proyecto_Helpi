import 'dart:async';

import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../inicio/presentacion/pantalla_inicio.dart';

class PantallaRegistroCompletado extends StatefulWidget {
  const PantallaRegistroCompletado({super.key, required this.perfil});

  final Map<String, dynamic> perfil;

  @override
  State<PantallaRegistroCompletado> createState() =>
      _EstadoRegistroCompletado();
}

class _EstadoRegistroCompletado extends State<PantallaRegistroCompletado> {
  Timer? _temporizador;
  bool _abriendoInicio = false;

  @override
  void initState() {
    super.initState();

    _temporizador = Timer(const Duration(seconds: 2), _abrirInicio);
  }

  void _abrirInicio() {
    if (!mounted || _abriendoInicio) return;

    _abriendoInicio = true;
    _temporizador?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PantallaInicio(perfil: widget.perfil),
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
      body: FondoHelpi(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: ColoresApp.verdeMenta,
                        child: Icon(
                          Icons.check_rounded,
                          size: 64,
                          color: ColoresApp.verdeAzulado,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      '¡Registro completado!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Tu perfil de demostración se guardó '
                      'localmente. Te estamos llevando al inicio.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: _abrirInicio,
                      child: const Text('Ir al inicio ahora'),
                    ),

                    const EtiquetaDemo(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
