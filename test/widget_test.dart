import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplicacion_helpi/funcionalidades/inicio/presentacion/pantalla_elegir_ubicacion.dart';
import 'package:aplicacion_helpi/funcionalidades/inicio/presentacion/pantalla_inicio.dart';
import 'package:aplicacion_helpi/nucleo/tema/tema_app.dart';

void main() {
  testWidgets(
    'Navega a Mi perfil sin fallos de layout y permite volver a otras pestañas',
    (WidgetTester tester) async {
      final perfilPrueba = <String, dynamic>{
        'uid': 'uid_prueba_1',
        'nombre': 'Camila Morales',
        'telefono': '+593991234567',
        'ciudad': 'Riobamba',
        'sector': 'Centro',
        'rol': 'solicitante',
        'categorias': ['Hogar', 'Reparaciones'],
        'habilidades': 'Organización y mantenimiento básico.',
        'presentacion': 'Vecina activa de la comunidad.',
        'disponibilidad': 'Fines de semana',
        'promedio': 4.8,
        'totalCalificaciones': 5,
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: TemaApp.claro,
          home: PantallaInicio(perfil: perfilPrueba),
        ),
      );
      await tester.pumpAndSettle();

      // Abre la pestaña "Mi perfil" desde la barra inferior de navegación.
      await tester.tap(find.text('Mi perfil'));
      await tester.pumpAndSettle();

      // Verifica que "Mi perfil" y sus secciones del módulo 4 se muestran sin excepciones.
      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Rol activo'), findsOneWidget);
      expect(find.text('Camila Morales'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Eliminar cuenta'), findsOneWidget);

      // Si no hay Firebase inicializado en el entorno de test, muestra el aviso con Reintentar sin quedar en blanco.
      expect(find.text('Reintentar'), findsOneWidget);

      // Sale de "Mi perfil" hacia "Inicio" y verifica que responde correctamente.
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('¿En qué podemos ayudarte?'), findsOneWidget);

      // Navega hacia "Mis servicios".
      await tester.tap(find.text('Mis servicios'));
      await tester.pumpAndSettle();
      expect(find.text('Mis solicitudes'), findsOneWidget);
    },
  );

  testWidgets(
    'PantallaElegirUbicacion permite cambiar ciudad y confirma coordenadas sin fallar con token de ejemplo',
    (WidgetTester tester) async {
      dotenv.loadFromString(
        envString: 'MAPBOX_ACCESS_TOKEN=PEGA_AQUI_MI_TOKEN_PUBLICO_PK',
      );
      addTearDown(dotenv.clean);

      Map<String, String>? resultado;

      await tester.pumpWidget(
        MaterialApp(
          theme: TemaApp.claro,
          home: Builder(
            builder: (contexto) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    resultado = await Navigator.push<Map<String, String>>(
                      contexto,
                      MaterialPageRoute<Map<String, String>>(
                        builder: (_) => const PantallaElegirUbicacion(
                          ciudad: 'Riobamba',
                          sector: 'Centro',
                        ),
                      ),
                    );
                  },
                  child: const Text('Abrir selector'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir selector'));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar ubicación'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Riobamba'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Quito'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Cuenca'), findsOneWidget);
      expect(
        find.text('Mapa interactivo pendiente de token público'),
        findsOneWidget,
      );
      expect(
        find.text('Latitud: -1.66360 · Longitud: -78.65460'),
        findsOneWidget,
      );

      final finderQuito = find.widgetWithText(ChoiceChip, 'Quito');
      await tester.ensureVisible(finderQuito);
      await tester.tap(finderQuito);
      await tester.pumpAndSettle();

      expect(
        find.text('Latitud: -0.18070 · Longitud: -78.46780'),
        findsOneWidget,
      );

      final finderConfirmar = find.text('Usar esta ubicación');
      await tester.ensureVisible(finderConfirmar);
      await tester.tap(finderConfirmar);
      await tester.pumpAndSettle();

      expect(resultado, isNotNull);
      expect(resultado!['ciudad'], 'Quito');
      expect(resultado!['sector'], 'Centro');
      expect(resultado!['latitud'], '-0.1807');
      expect(resultado!['longitud'], '-78.4678');
    },
  );

  testWidgets(
    'PantallaElegirUbicacion rechaza tokens privados sk. en .env.mapbox sin cerrar la app',
    (WidgetTester tester) async {
      dotenv.loadFromString(
        envString: 'MAPBOX_ACCESS_TOKEN=sk.ejemplo_no_permitido',
      );
      addTearDown(dotenv.clean);

      await tester.pumpWidget(
        MaterialApp(
          theme: TemaApp.claro,
          home: const PantallaElegirUbicacion(
            ciudad: 'Riobamba',
            sector: 'Centro',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Token de Mapbox no válido para cliente'),
        findsOneWidget,
      );
    },
  );
}
