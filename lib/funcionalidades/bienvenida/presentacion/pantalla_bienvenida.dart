import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../administrador/presentacion/destino_sesion.dart';

class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.grisClaro,
      body: FondoHelpi(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, restricciones) {
              final pantallaAmplia = restricciones.maxWidth >= 900;
              final margen = pantallaAmplia ? 48.0 : 24.0;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: restricciones.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(margen),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: pantallaAmplia
                            ? const _DistribucionEscritorio()
                            : const _DistribucionMovil(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DistribucionMovil extends StatelessWidget {
  const _DistribucionMovil();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LogoAcceso(),
            SizedBox(height: 20),
            _IlustracionAcceso(),
            SizedBox(height: 26),
            _PanelAcceso(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _DistribucionEscritorio extends StatelessWidget {
  const _DistribucionEscritorio();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LogoAcceso(),
              SizedBox(height: 24),
              _IlustracionAcceso(),
            ],
          ),
        ),
        SizedBox(width: 64),
        Expanded(
          flex: 5,
          child: TarjetaHelpi(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: _PanelAcceso(),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoAcceso extends StatelessWidget {
  const _LogoAcceso();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/imagenes/portada.png',
        width: 150,
        fit: BoxFit.contain,
        semanticLabel: 'Helpi',
      ),
    );
  }
}

class _IlustracionAcceso extends StatelessWidget {
  const _IlustracionAcceso();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AspectRatio(
        aspectRatio: 852 / 1060,
        child: Image.asset(
          'assets/imagenes/Fondo_acceso.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _PanelAcceso extends StatefulWidget {
  const _PanelAcceso();

  @override
  State<_PanelAcceso> createState() => _EstadoPanelAcceso();
}

class _EstadoPanelAcceso extends State<_PanelAcceso> {
  static Future<void>? _inicializacionGoogle;

  static const _webClientId =
      '400034948021-3rc82p0fle2jd2r3i95e451rcit6t615'
      '.apps.googleusercontent.com';

  bool _procesando = false;

  Future<void> _iniciarSesion() async {
    if (_procesando) return;

    if (Firebase.apps.isEmpty) {
      aviso(
        context,
        'Falta inicializar Firebase en main.dart.',
      );
      return;
    }

    setState(() => _procesando = true);

    try {
      final autenticacion = FirebaseAuth.instance;
      late final UserCredential resultado;

      if (kIsWeb) {
        final proveedor = GoogleAuthProvider();

        proveedor.setCustomParameters({
          'prompt': 'select_account',
        });

        resultado = await autenticacion.signInWithPopup(proveedor);
      } else {
        final googleSignIn = GoogleSignIn.instance;

        await (_inicializacionGoogle ??= googleSignIn.initialize(
          serverClientId: _webClientId,
        ));

        if (!googleSignIn.supportsAuthenticate()) {
          if (!mounted) return;

          aviso(
            context,
            'El acceso con Google no está disponible '
            'en esta plataforma.',
          );
          return;
        }

        final usuarioGoogle = await googleSignIn.authenticate();
        final idToken = usuarioGoogle.authentication.idToken;

        if (idToken == null || idToken.isEmpty) {
          if (!mounted) return;

          aviso(
            context,
            'Google no devolvió la credencial de acceso. '
            'Revisa la configuración de Google y Firebase.',
          );
          return;
        }

        final credencial = GoogleAuthProvider.credential(
          idToken: idToken,
        );

        resultado = await autenticacion.signInWithCredential(
          credencial,
        );
      }

      if (!mounted) return;

      if (resultado.user == null) {
        aviso(context, 'No se pudo completar el inicio de sesión.');
        return;
      }

      // Administrador, cuenta suspendida, registro pendiente o inicio.
      final destino = await destinoTrasSesion();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => destino),
      );
    } on GoogleSignInException catch (error) {
      if (!mounted) return;

      if (error.code == GoogleSignInExceptionCode.canceled) {
        aviso(context, 'Se canceló el inicio de sesión.');
      } else {
        aviso(
          context,
          'No se pudo acceder con Google: ${error.code.name}.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      aviso(context, _mensajeFirebase(error));
    } on FirebaseException catch (error) {
      if (!mounted) return;

      debugPrint('Error de Firebase: $error');

      aviso(
        context,
        'No pudimos consultar tu perfil (${error.code}). '
        'Revisa la conexión y los permisos de Firestore.',
      );
    } catch (error) {
      debugPrint('Error al iniciar sesión: $error');

      if (!mounted) return;

      aviso(
        context,
        'No se pudo completar el acceso. '
        'Comprueba tu conexión e intenta nuevamente.',
      );
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  String _mensajeFirebase(FirebaseAuthException error) {
    switch (error.code) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Se canceló el inicio de sesión.';

      case 'popup-blocked':
        return 'El navegador bloqueó la ventana de Google. '
            'Permite las ventanas emergentes para este sitio.';

      case 'unauthorized-domain':
        return 'Este dominio no está autorizado en Firebase. '
            'Revisa los dominios autorizados de Authentication.';

      case 'operation-not-allowed':
        return 'Activa el proveedor Google en '
            'Firebase Authentication.';

      case 'network-request-failed':
        return 'No se pudo conectar. Revisa tu conexión a internet.';

      case 'account-exists-with-different-credential':
        return 'Este correo ya está registrado con otro '
            'método de acceso.';

      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';

      case 'invalid-credential':
        return 'La credencial no es válida. '
            'Revisa la configuración de Google y Firebase.';

      default:
        return 'No se pudo iniciar sesión (${error.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Te damos la bienvenida',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: ColoresApp.azulMarino,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'a Helpi',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: ColoresApp.verdeAzulado,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Encuentra ayuda cerca de ti o comparte '
          'tus habilidades con tu comunidad.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: ColoresApp.grisOscuro,
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: _procesando ? null : _iniciarSesion,
          style: OutlinedButton.styleFrom(
            backgroundColor: ColoresApp.blanco,
            foregroundColor: ColoresApp.azulMarino,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            side: const BorderSide(
              color: Color(0xFFDCE5ED),
            ),
            shape: const StadiumBorder(),
          ),
          icon: _procesando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.login_rounded),
          label: Text(
            _procesando ? 'Conectando…' : 'Continuar con Google',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('o'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _procesando ? null : _iniciarSesion,
          child: const Text(
            'Iniciar sesión',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ColoresApp.verdeAzulado,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                informacion(
                  context,
                  'Términos de servicio',
                  'Los términos definitivos se prepararán '
                      'antes del lanzamiento.',
                );
              },
              child: const Text('Términos'),
            ),
            TextButton(
              onPressed: () {
                informacion(
                  context,
                  'Privacidad',
                  'Google y Firebase procesan el acceso a tu cuenta. '
                      'Los datos que completes en tu perfil se '
                      'guardarán en Cloud Firestore. '
                      'La fotografía personalizada aún no se '
                      'sincroniza con la nube. '
                      'La política definitiva está pendiente.',
                );
              },
              child: const Text('Privacidad'),
            ),
          ],
        ),
      ],
    );
  }
}