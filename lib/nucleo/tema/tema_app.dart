import 'package:flutter/material.dart';

import 'colores_app.dart';

abstract final class TemaApp {
  static ThemeData get claro {
    return ThemeData(
      useMaterial3: true,

      // Fondo general.
      scaffoldBackgroundColor: ColoresApp.grisClaro,

      // Colores de los componentes de Flutter.
      colorScheme: ColorScheme.fromSeed(
        seedColor: ColoresApp.verdeAzulado,
        primary: ColoresApp.verdeAzulado,
        onPrimary: ColoresApp.blanco,
        secondary: ColoresApp.coral,
        surface: ColoresApp.blanco,
        onSurface: ColoresApp.grisOscuro,
      ),

      // Títulos y textos.
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: ColoresApp.azulMarino,
          height: 1.15,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: ColoresApp.azulMarino,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: ColoresApp.grisOscuro,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: ColoresApp.grisOscuro,
        ),
      ),

      // Barra superior.
      appBarTheme: const AppBarTheme(
        backgroundColor: ColoresApp.grisClaro,
        foregroundColor: ColoresApp.azulMarino,
        centerTitle: false,
        elevation: 0,
      ),

      // Botones principales.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ColoresApp.verdeAzulado,
          foregroundColor: ColoresApp.blanco,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Campos de los formularios.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColoresApp.blanco,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ColoresApp.verdeAzulado,
            width: 2,
          ),
        ),
      ),
    );
  }
}
