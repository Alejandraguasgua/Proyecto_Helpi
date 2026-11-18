import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../nucleo/tema/colores_app.dart';

class BarraSuperiorHelpi extends StatelessWidget {
  const BarraSuperiorHelpi({
    super.key,
    required this.seccion,
    required this.rol,
    required this.ciudad,
    required this.sector,
    required this.nombre,
    required this.alCambiarSeccion,
    required this.alCambiarRol,
    required this.alCambiarUbicacion,
    this.foto,
    this.guardandoRol = false,
    this.notificacionesSinLeer = 0,
  });

  final int seccion;
  final String rol;
  final String ciudad;
  final String sector;
  final String nombre;

  final ValueChanged<int> alCambiarSeccion;
  final ValueChanged<String> alCambiarRol;
  final VoidCallback alCambiarUbicacion;

  final Uint8List? foto;
  final bool guardandoRol;

  /// Número que aparece sobre la campanita (0 = no se muestra).
  final int notificacionesSinLeer;

  @override
  Widget build(BuildContext context) {
    final nombreLimpio = nombre.trim();

    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/imagenes/portada.png',
                  width: 75,
                  semanticLabel: 'Helpi',
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: alCambiarUbicacion,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: ColoresApp.verdeAzulado,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Explorar en',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: ColoresApp.grisOscuro,
                                  ),
                                ),
                                Text(
                                  sector.isEmpty
                                      ? '$ciudad, Ecuador'
                                      : '$sector, $ciudad',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ColoresApp.azulMarino,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),

                IconButton(
                  tooltip: notificacionesSinLeer > 0
                      ? 'Notificaciones ($notificacionesSinLeer sin leer)'
                      : 'Notificaciones',
                  onPressed: () => alCambiarSeccion(2),
                  icon: Badge(
                    isLabelVisible: notificacionesSinLeer > 0,
                    backgroundColor: ColoresApp.coral,
                    label: Text(
                      notificacionesSinLeer > 9
                          ? '9+'
                          : '$notificacionesSinLeer',
                    ),
                    child: Icon(
                      notificacionesSinLeer > 0
                          ? Icons.notifications
                          : Icons.notifications_none,
                      color: ColoresApp.azulMarino,
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Mi perfil',
                  onPressed: () => alCambiarSeccion(3),
                  icon: CircleAvatar(
                    radius: 18,
                    backgroundColor: ColoresApp.verdeMenta,
                    backgroundImage: foto == null ? null : MemoryImage(foto!),
                    child: foto == null
                        ? Text(
                            nombreLimpio.isEmpty
                                ? '?'
                                : nombreLimpio.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: ColoresApp.verdeAzulado,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('Solicitante'),
                  selected: rol != 'prestador',
                  selectedColor: ColoresApp.verdeMenta,
                  onSelected: guardandoRol
                      ? null
                      : (_) => alCambiarRol('solicitante'),
                ),
                ChoiceChip(
                  avatar: const Icon(
                    Icons.volunteer_activism_outlined,
                    size: 18,
                  ),
                  label: const Text('Prestador'),
                  selected: rol == 'prestador',
                  selectedColor: ColoresApp.verdeMenta,
                  onSelected: guardandoRol
                      ? null
                      : (_) => alCambiarRol('prestador'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
