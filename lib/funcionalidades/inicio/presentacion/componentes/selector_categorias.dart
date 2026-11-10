import 'package:flutter/material.dart';

import '../../../../nucleo/tema/colores_app.dart';

const categoriasInicio = <String, IconData>{
  'Todas': Icons.apps_rounded,
  'Soporte técnico': Icons.computer_outlined,
  'Tutorías': Icons.menu_book_outlined,
  'Reparaciones': Icons.handyman_outlined,
  'Hogar': Icons.chair_outlined,
  'Mascotas': Icons.pets_outlined,
  'Mudanzas': Icons.local_shipping_outlined,
};

class SelectorCategorias extends StatelessWidget {
  const SelectorCategorias({
    super.key,
    required this.seleccionada,
    required this.alSeleccionar,
  });

  final String seleccionada;
  final ValueChanged<String> alSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categoriasInicio.entries.map((categoria) {
        final activa = seleccionada == categoria.key;

        return SizedBox(
          width: 118,
          child: Semantics(
            button: true,
            selected: activa,
            child: Material(
              color: activa ? ColoresApp.verdeMenta : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: activa
                      ? ColoresApp.verdeAzulado
                      : const Color(0xFFE1E8EF),
                  width: activa ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => alSeleccionar(categoria.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categoria.value,
                        size: 27,
                        color: ColoresApp.verdeAzulado,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        categoria.key,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColoresApp.azulMarino,
                          fontWeight: activa
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
