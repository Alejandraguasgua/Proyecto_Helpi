import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../nucleo/tema/colores_app.dart';
import '../../bienvenida/presentacion/pantalla_bienvenida.dart';
import '../../inicio/presentacion/pantalla_inicio.dart';
import '../../registro/datos/repositorio_perfil.dart';
import '../../registro/presentacion/pantalla_roles.dart';
import '../datos/repositorio_admin.dart';
import 'pantalla_admin.dart';

/// Decide a qué pantalla va el usuario autenticado:
/// administrador, cuenta suspendida, registro pendiente o inicio.
Future<Widget> destinoTrasSesion() async {
  if (await RepositorioAdmin().esAdministrador()) {
    return const PantallaAdmin();
  }

  final perfil = await RepositorioPerfil().leer();

  if (perfil == null) return const PantallaRoles();
  if (perfil['suspendido'] == true) return const PantallaSuspendida();

  return PantallaInicio(perfil: perfil);
}

class PantallaSuspendida extends StatelessWidget {
  const PantallaSuspendida({super.key});

  Future<void> _salir(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PantallaBienvenida()),
      (_) => false,
    );
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
              const Icon(Icons.block, size: 56, color: ColoresApp.coral),
              const SizedBox(height: 16),
              const Text(
                'Tu cuenta está suspendida',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.azulMarino,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Contacta al equipo de Helpi si crees que es un error.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _salir(context),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
