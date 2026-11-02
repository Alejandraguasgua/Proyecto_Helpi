import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema/colores_app.dart';

class IlustracionComunidad extends StatelessWidget {
  const IlustracionComunidad({super.key, this.altura = 240});

  final double altura;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dos personas de la comunidad ayudándose',
      image: true,
      child: SizedBox(
        height: altura,
        width: double.infinity,
        child: CustomPaint(painter: _PintorComunidad()),
      ),
    );
  }
}

class _PintorComunidad extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Tamaño de referencia para adaptar el dibujo a la pantalla.
    const ancho = 380.0;
    const alto = 260.0;

    final escala = math.min(size.width / ancho, size.height / alto);

    canvas.save();

    canvas.translate(
      (size.width - ancho * escala) / 2,
      (size.height - alto * escala) / 2,
    );

    canvas.scale(escala);

    _dibujarFondo(canvas);
    _dibujarTelefono(canvas);

    // Persona de la izquierda, mirando hacia el centro.
    _dibujarPersona(
      canvas,
      posicion: const Offset(95, 0),
      reflejada: false,
      ropa: ColoresApp.verdeAzulado,
    );

    // Persona de la derecha, mirando hacia el centro.
    _dibujarPersona(
      canvas,
      posicion: const Offset(285, 0),
      reflejada: true,
      ropa: ColoresApp.azulMarino,
    );

    _dibujarPaquete(canvas);
    _dibujarInsignias(canvas);

    canvas.restore();
  }

  void _rectangulo(
    Canvas canvas,
    Rect rectangulo,
    Color color, {
    double radio = 0,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rectangulo, Radius.circular(radio)),
      Paint()..color = color,
    );
  }

  void _circulo(Canvas canvas, Offset centro, double radio, Color color) {
    canvas.drawCircle(centro, radio, Paint()..color = color);
  }

  void _linea(
    Canvas canvas,
    Offset inicio,
    Offset fin,
    Color color,
    double grosor,
  ) {
    final pintura = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(inicio, fin, pintura);
  }

  void _dibujarFondo(Canvas canvas) {
    // Edificios suaves al fondo.
    for (var i = 0; i < 6; i++) {
      _rectangulo(
        canvas,
        Rect.fromLTWH(25 + i * 58.0, 140 + (i % 3) * 12.0, 35, 85),
        const Color(0x1015324F),
        radio: 3,
      );
    }

    canvas.drawOval(
      const Rect.fromLTWH(30, 228, 320, 24),
      Paint()..color = const Color(0x18087F8C),
    );
  }

  void _dibujarTelefono(Canvas canvas) {
    _rectangulo(
      canvas,
      const Rect.fromLTWH(123, 22, 134, 203),
      const Color(0xFFB9DDE3),
      radio: 25,
    );

    _rectangulo(
      canvas,
      const Rect.fromLTWH(131, 30, 118, 186),
      const Color(0xFFF0F8F9),
      radio: 19,
    );

    _rectangulo(
      canvas,
      const Rect.fromLTWH(168, 37, 44, 6),
      const Color(0xFFB9DDE3),
      radio: 3,
    );

    // Marcador de ubicación.
    _circulo(canvas, const Offset(190, 88), 24, ColoresApp.verdeAzulado);

    final punta = Path()
      ..moveTo(171, 102)
      ..lineTo(190, 131)
      ..lineTo(209, 102)
      ..close();

    canvas.drawPath(punta, Paint()..color = ColoresApp.verdeAzulado);

    _circulo(canvas, const Offset(190, 86), 9, ColoresApp.blanco);
  }

  void _dibujarPersona(
    Canvas canvas, {
    required Offset posicion,
    required bool reflejada,
    required Color ropa,
  }) {
    const piel = Color(0xFFF2BE9C);

    canvas.save();
    canvas.translate(posicion.dx, posicion.dy);

    if (reflejada) {
      canvas.scale(-1, 1);
    }

    // Piernas.
    _rectangulo(
      canvas,
      const Rect.fromLTWH(-22, 218, 17, 28),
      ColoresApp.azulMarino,
      radio: 5,
    );

    _rectangulo(
      canvas,
      const Rect.fromLTWH(6, 218, 17, 28),
      ColoresApp.azulMarino,
      radio: 5,
    );

    // Cuerpo.
    _rectangulo(canvas, const Rect.fromLTWH(-33, 143, 66, 84), ropa, radio: 20);

    // Cuello y cabeza.
    _rectangulo(canvas, const Rect.fromLTWH(-8, 127, 18, 28), piel, radio: 6);

    _circulo(canvas, const Offset(0, 111), 25, piel);

    // Cabello.
    _circulo(canvas, const Offset(-16, 98), 17, ColoresApp.azulMarino);

    _circulo(canvas, const Offset(1, 89), 20, ColoresApp.azulMarino);

    _circulo(canvas, const Offset(19, 96), 12, ColoresApp.azulMarino);

    // Oreja y ojo.
    _circulo(canvas, const Offset(-19, 115), 6, piel);

    _circulo(canvas, const Offset(12, 112), 2, ColoresApp.azulMarino);

    // Brazos dirigidos hacia el paquete.
    _linea(canvas, const Offset(24, 163), const Offset(61, 186), piel, 16);

    _linea(canvas, const Offset(-18, 166), const Offset(-4, 199), piel, 15);

    _linea(canvas, const Offset(-4, 199), const Offset(59, 207), piel, 15);

    canvas.restore();
  }

  void _dibujarPaquete(Canvas canvas) {
    const piel = Color(0xFFF2BE9C);

    _rectangulo(
      canvas,
      const Rect.fromLTWH(154, 160, 72, 54),
      const Color(0xFFD7AF87),
      radio: 4,
    );

    // Cinta de la caja.
    _rectangulo(
      canvas,
      const Rect.fromLTWH(184, 160, 12, 27),
      const Color(0xFFBF936E),
    );

    // Manos sobre el paquete.
    _circulo(canvas, const Offset(155, 205), 8, piel);
    _circulo(canvas, const Offset(225, 192), 8, piel);
  }

  void _dibujarInsignias(Canvas canvas) {
    _circulo(canvas, const Offset(47, 62), 26, ColoresApp.verdeMenta);

    // Símbolo de confirmación.
    _linea(
      canvas,
      const Offset(35, 63),
      const Offset(45, 72),
      ColoresApp.verdeAzulado,
      5,
    );

    _linea(
      canvas,
      const Offset(45, 72),
      const Offset(60, 52),
      ColoresApp.verdeAzulado,
      5,
    );

    _circulo(canvas, const Offset(326, 62), 26, ColoresApp.verdeMenta);

    // Corazón decorativo.
    final corazon = Path()
      ..moveTo(326, 77)
      ..cubicTo(298, 59, 315, 42, 326, 54)
      ..cubicTo(337, 42, 354, 59, 326, 77)
      ..close();

    canvas.drawPath(corazon, Paint()..color = ColoresApp.verdeAzulado);
  }

  @override
  bool shouldRepaint(covariant _PintorComunidad oldDelegate) {
    return false;
  }
}
