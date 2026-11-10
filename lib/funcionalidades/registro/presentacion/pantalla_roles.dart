import 'pantalla_datos.dart';

import 'package:flutter/material.dart';

import '../../../nucleo/tema/colores_app.dart';

class PantallaRoles extends StatefulWidget {
  const PantallaRoles({super.key});

  @override
  State<PantallaRoles> createState() => _EstadoPantallaRoles();
}

class _EstadoPantallaRoles extends State<PantallaRoles> {
  String? _rolSeleccionado;

  Widget _tarjetaRol({
    required String rol,
    required String titulo,
    required String descripcion,
    required IconData icono,
  }) {
    final seleccionada = _rolSeleccionado == rol;

    return Semantics(
      button: true,
      selected: seleccionada,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1015324F),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: seleccionada ? const Color(0xFFF0FBF9) : ColoresApp.blanco,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: seleccionada
                  ? ColoresApp.verdeAzulado
                  : const Color(0xFFE3EFF0),
              width: seleccionada ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              setState(() {
                _rolSeleccionado = rol;
              });

              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PantallaDatos(rol: rol),
                ),
              );
            },

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFD9F0ED),
                    child: Icon(
                      icono,
                      size: 34,
                      color: ColoresApp.verdeAzulado,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ColoresApp.azulMarino,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          descripcion,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: ColoresApp.grisOscuro,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    seleccionada
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: ColoresApp.verdeAzulado,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapa() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.asset(
        'assets/imagenes/mapa_roles.png',
        width: double.infinity,
        fit: BoxFit.contain,
        semanticLabel: 'Mapa con un marcador de ubicación',
      ),
    );
  }

  Widget _contenidoRoles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Qué quieres hacer hoy?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: ColoresApp.azulMarino,
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          'Puedes cambiar de rol cuando quieras.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: ColoresApp.grisOscuro,
          ),
        ),

        const SizedBox(height: 30),

        _tarjetaRol(
          rol: 'solicitante',
          titulo: 'Necesito ayuda',
          descripcion:
              'Encuentra personas que puedan ayudarte '
              'cerca de ti.',
          icono: Icons.location_on_outlined,
        ),

        const SizedBox(height: 20),

        _tarjetaRol(
          rol: 'prestador',
          titulo: 'Quiero ayudar',
          descripcion:
              'Ofrece tus habilidades y encuentra '
              'solicitudes cercanas.',
          icono: Icons.volunteer_activism_outlined,
        ),

        const SizedBox(height: 20),

        if (_rolSeleccionado != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _rolSeleccionado == 'solicitante'
                  ? 'Seleccionaste: Necesito ayuda'
                  : 'Seleccionaste: Quiero ayudar',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ColoresApp.verdeAzulado,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _FondoRoles())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, restricciones) {
                final pantallaAmplia = restricciones.maxWidth >= 900;

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: restricciones.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(pantallaAmplia ? 40 : 22),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1150),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const BackButton(),
                                  const SizedBox(width: 8),
                                  Image.asset(
                                    'assets/imagenes/portada.png',
                                    width: 110,
                                    semanticLabel: 'Helpi',
                                  ),
                                ],
                              ),

                              const SizedBox(height: 28),

                              if (pantallaAmplia)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(flex: 6, child: _mapa()),
                                    const SizedBox(width: 48),
                                    Expanded(flex: 5, child: _contenidoRoles()),
                                  ],
                                )
                              else
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 540,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _mapa(),
                                        const SizedBox(height: 28),
                                        _contenidoRoles(),
                                      ],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 48),

                              const Text(
                                'Una comunidad. Muchas formas '
                                'de ayudarnos.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ColoresApp.azulMarino,
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Decoración adaptable: fondo menta, ciudad y ondas.
class _FondoRoles extends CustomPainter {
  const _FondoRoles();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC6E8E9), Color(0xFFF0FAF8)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawCircle(
      Offset(size.width + 30, -50),
      size.width * 0.35,
      Paint()..color = const Color(0x18087F8C),
    );

    // Silueta de edificios al fondo.
    final pinturaCiudad = Paint()..color = const Color(0x12087F8C);

    for (var i = 0; i < 6; i++) {
      final anchoEdificio = size.width * 0.07;
      final altoEdificio = 45.0 + (i % 3) * 24;

      canvas.drawRect(
        Rect.fromLTWH(
          size.width * 0.48 + i * anchoEdificio * 1.15,
          size.height - 55 - altoEdificio,
          anchoEdificio,
          altoEdificio,
        ),
        pinturaCiudad,
      );
    }

    final onda = Path()
      ..moveTo(0, size.height - 120)
      ..cubicTo(
        size.width * 0.25,
        size.height - 80,
        size.width * 0.35,
        size.height + 20,
        size.width * 0.7,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(onda, Paint()..color = const Color(0x30087F8C));
  }

  @override
  bool shouldRepaint(covariant _FondoRoles oldDelegate) {
    return false;
  }
}
