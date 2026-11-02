import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/componentes/ilustracion_comunidad.dart';
import '../../../nucleo/tema/colores_app.dart';

class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  void _continuarConGoogle(BuildContext context) {
    informacion(
      context,
      'Acceso con Google',
      'Aquí conectaremos Firebase Authentication para iniciar sesión '
      'con tu cuenta de Google.\n\n'
      'Por ahora estamos construyendo la interfaz. '
      'Todavía no se crea una cuenta ni se inicia una sesión real.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final estilos = Theme.of(context).textTheme;

    return PaginaHelpi(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 40),
        children: [
          const Center(
            child: LogoHelpi(tamano: 52),
          ),

          const SizedBox(height: 28),

          const IlustracionComunidad(
            altura: 245,
          ),

          const SizedBox(height: 24),

          Text(
            'Te damos la bienvenida',
            textAlign: TextAlign.center,
            style: estilos.headlineLarge,
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

          const SizedBox(height: 14),

          Text(
            'Conecta con personas cercanas para recibir ayuda '
            'o compartir tus habilidades.',
            textAlign: TextAlign.center,
            style: estilos.bodyLarge,
          ),

          const SizedBox(height: 30),

          OutlinedButton.icon(
            onPressed: () => _continuarConGoogle(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: ColoresApp.blanco,
              foregroundColor: ColoresApp.azulMarino,
              minimumSize: const Size.fromHeight(58),
              side: const BorderSide(
                color: Color(0xFFDCE5ED),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: const Icon(Icons.login_rounded),
            label: const Text(
              'Continuar con Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 18),

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

          TextButton(
            onPressed: () => _continuarConGoogle(context),
            child: const Text(
              'Iniciar sesión',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Conoce las condiciones de uso de Helpi',
            textAlign: TextAlign.center,
          ),

          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  informacion(
                    context,
                    'Términos de servicio',
                    'Los términos definitivos se prepararán antes '
                    'de habilitar el registro real.\n\n'
                    'Esta versión permite revisar la interfaz '
                    'y no realiza contrataciones ni cobros.',
                  );
                },
                child: const Text('Términos'),
              ),
              TextButton(
                onPressed: () {
                  informacion(
                    context,
                    'Privacidad',
                    'Esta pantalla todavía no solicita acceso '
                    'a Google ni envía datos personales.\n\n'
                    'La política de privacidad definitiva deberá '
                    'explicar el tratamiento de perfiles, ubicación '
                    'y fotografías antes del lanzamiento.',
                  );
                },
                child: const Text('Privacidad'),
              ),
            ],
          ),

          const EtiquetaDemo(),
        ],
      ),
    );
  }
}