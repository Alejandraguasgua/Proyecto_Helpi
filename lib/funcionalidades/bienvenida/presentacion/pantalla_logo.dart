import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../nucleo/tema/colores_app.dart';
import '../../inicio/presentacion/pantalla_inicio.dart';
import '../../registro/datos/repositorio_perfil.dart';
import '../../registro/presentacion/pantalla_roles.dart';
import 'pantalla_bienvenida.dart';

class PantallaLogo extends StatefulWidget {
  const PantallaLogo({super.key});

  @override
  State<PantallaLogo> createState() => _EstadoPantallaLogo();
}

class _EstadoPantallaLogo extends State<PantallaLogo> {
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _abrirAplicacion();
  }

  Future<void> _abrirAplicacion() async {
    if (_cargando) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // Espera a que Firebase restaure la sesión guardada.
      final usuario =
          await FirebaseAuth.instance.authStateChanges().first;

      Widget destino;

      if (usuario == null) {
        destino = const PantallaBienvenida();
      } else {
        final perfil = await RepositorioPerfil().leer();

        destino = perfil == null
            ? const PantallaRoles()
            : PantallaInicio(perfil: perfil);
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => destino,
        ),
      );
    } catch (error) {
      debugPrint('Error al recuperar el perfil: $error');

      if (!mounted) return;

      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar tu perfil. '
            'Revisa tu conexión e intenta nuevamente.';
      });
    }
  }

  Future<void> _usarOtraCuenta() async {
    if (_cargando) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const PantallaBienvenida(),
        ),
      );
    } catch (error) {
      debugPrint('Error al cerrar sesión: $error');

      if (!mounted) return;

      setState(() {
        _cargando = false;
        _error = 'No pudimos cerrar la sesión. Intenta nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.grisClaro,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/imagenes/portada.png',
                width: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              if (_error == null)
                const CircularProgressIndicator()
              else ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _abrirAplicacion,
                  child: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: _usarOtraCuenta,
                  child: const Text('Usar otra cuenta'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}