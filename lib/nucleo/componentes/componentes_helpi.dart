import 'package:flutter/material.dart';

import '../tema/colores_app.dart';

// Logotipo: el marcador representa la letra "i".
class LogoHelpi extends StatelessWidget {
  const LogoHelpi({super.key, this.tamano = 38});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Helpi',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Help',
            style: TextStyle(
              fontSize: tamano,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              color: ColoresApp.azulMarino,
            ),
          ),
          Icon(
            Icons.location_on_rounded,
            size: tamano * 0.86,
            color: ColoresApp.verdeAzulado,
          ),
        ],
      ),
    );
  }
}

// Fondo decorativo compartido.
class FondoHelpi extends StatelessWidget {
  const FondoHelpi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _OndasHelpi())),
        child,
      ],
    );
  }
}

class _OndasHelpi extends CustomPainter {
  const _OndasHelpi();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ColoresApp.grisClaro);

    // Círculos suaves en la esquina superior.
    canvas.drawCircle(
      Offset(size.width * 0.04, -60),
      size.width * 0.52,
      Paint()..color = const Color(0x1D087F8C),
    );

    canvas.drawCircle(
      const Offset(-60, -50),
      size.width * 0.48,
      Paint()..color = const Color(0x12087F8C),
    );

    // Primera onda inferior.
    final primeraOnda = Path()
      ..moveTo(0, size.height - 80)
      ..cubicTo(
        size.width * 0.3,
        size.height - 130,
        size.width * 0.7,
        size.height + 50,
        size.width,
        size.height - 95,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(primeraOnda, Paint()..color = const Color(0x26087F8C));

    // Segunda onda inferior.
    final segundaOnda = Path()
      ..moveTo(size.width * 0.45, size.height)
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height - 110,
        size.width,
        size.height - 65,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(segundaOnda, Paint()..color = const Color(0x55087F8C));
  }

  @override
  bool shouldRepaint(covariant _OndasHelpi oldDelegate) {
    return false;
  }
}

// Estructura compartida de las pantallas.
class PaginaHelpi extends StatelessWidget {
  const PaginaHelpi({
    super.key,
    required this.child,
    this.barra,
    this.inferior,
  });

  final Widget child;
  final PreferredSizeWidget? barra;
  final Widget? inferior;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barra,
      bottomNavigationBar: inferior,
      body: FondoHelpi(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// Tarjeta reutilizable.
class TarjetaHelpi extends StatelessWidget {
  const TarjetaHelpi({
    super.key,
    required this.child,
    this.color = ColoresApp.blanco,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4EBF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B15324F),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Mensaje breve en la parte inferior.
void aviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
}

// Ventana informativa.
void informacion(BuildContext context, String titulo, String texto) {
  showDialog<void>(
    context: context,
    builder: (contextoDialogo) {
      return AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(child: Text(texto)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(contextoDialogo);
            },
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );
}

// Identifica claramente la versión de demostración.
const notaDemostracion = 'Demostración local · sin cuenta en la nube';

class EtiquetaDemo extends StatelessWidget {
  const EtiquetaDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Text(
        notaDemostracion,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: ColoresApp.verdeAzulado),
      ),
    );
  }
}
