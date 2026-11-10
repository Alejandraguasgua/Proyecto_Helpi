import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../nucleo/tema/colores_app.dart';

class PantallaElegirUbicacion extends StatefulWidget {
  const PantallaElegirUbicacion({
    super.key,
    required this.ciudad,
    required this.sector,
    this.latitud,
    this.longitud,
  });

  final String ciudad;
  final String sector;
  final double? latitud;
  final double? longitud;

  @override
  State<PantallaElegirUbicacion> createState() =>
      _EstadoPantallaElegirUbicacion();
}

class _EstadoPantallaElegirUbicacion extends State<PantallaElegirUbicacion> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _ciudad;
  late final TextEditingController _sector;

  GoogleMapController? _controladorMapa;

  late LatLng _punto;

  static const _centrosCiudades = <String, LatLng>{
    'Riobamba': LatLng(-1.6636, -78.6546),
    'Quito': LatLng(-0.1807, -78.4678),
    'Cuenca': LatLng(-2.9001, -79.0059),
  };

  @override
  void initState() {
    super.initState();

    _ciudad = TextEditingController(text: widget.ciudad);
    _sector = TextEditingController(text: widget.sector);

    final latitud = widget.latitud;
    final longitud = widget.longitud;

    final coordenadasValidas =
        latitud != null &&
        longitud != null &&
        latitud.isFinite &&
        longitud.isFinite &&
        latitud >= -90 &&
        latitud <= 90 &&
        longitud >= -180 &&
        longitud <= 180;

    if (coordenadasValidas) {
      _punto = LatLng(latitud, longitud);
    } else {
      _punto = _buscarCentro(widget.ciudad) ?? _centrosCiudades['Riobamba']!;
    }
  }

  LatLng? _buscarCentro(String ciudad) {
    final nombre = ciudad.trim().toLowerCase();

    for (final entrada in _centrosCiudades.entries) {
      if (entrada.key.toLowerCase() == nombre) {
        return entrada.value;
      }
    }

    return null;
  }

  void _seleccionarCiudad(String ciudad) {
    final centro = _buscarCentro(ciudad);

    if (centro == null) return;

    setState(() {
      _ciudad.text = ciudad;
      _sector.clear();
      _punto = centro;
    });

    _controladorMapa?.animateCamera(CameraUpdate.newLatLngZoom(centro, 13));
  }

  void _seleccionarPunto(LatLng punto) {
    setState(() => _punto = punto);
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;

    Navigator.pop<Map<String, String>>(context, {
      'ciudad': _ciudad.text.trim(),
      'sector': _sector.text.trim(),
      'latitud': _punto.latitude.toString(),
      'longitud': _punto.longitude.toString(),
    });
  }

  @override
  void dispose() {
    _ciudad.dispose();
    _sector.dispose();
    _controladorMapa?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.grisClaro,
      appBar: AppBar(
        title: const Text('Cambiar ubicación'),
        backgroundColor: Colors.white,
        foregroundColor: ColoresApp.azulMarino,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, espacio) {
            final esMovil = espacio.maxWidth < 600;

            return SingleChildScrollView(
              padding: EdgeInsets.all(esMovil ? 16 : 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Form(
                    key: _formulario,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '¿Dónde quieres buscar?',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'Toca el mapa o arrastra el marcador '
                          'hasta la ubicación que prefieras.',
                        ),

                        const SizedBox(height: 18),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _centrosCiudades.keys.map((ciudad) {
                            return ActionChip(
                              avatar: const Icon(
                                Icons.location_city,
                                size: 18,
                                color: ColoresApp.verdeAzulado,
                              ),
                              label: Text(ciudad),
                              onPressed: () {
                                _seleccionarCiudad(ciudad);
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 18),

                        SizedBox(
                          height: esMovil ? 300 : 420,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _punto,
                                zoom: 13,
                              ),
                              onMapCreated: (controlador) {
                                _controladorMapa = controlador;
                              },
                              onTap: _seleccionarPunto,
                              markers: {
                                Marker(
                                  markerId: const MarkerId(
                                    'ubicacion_seleccionada',
                                  ),
                                  position: _punto,
                                  draggable: true,
                                  onDragEnd: _seleccionarPunto,
                                ),
                              },
                              myLocationEnabled: false,
                              myLocationButtonEnabled: false,
                              mapToolbarEnabled: false,
                              zoomControlsEnabled: true,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Punto seleccionado: '
                          '${_punto.latitude.toStringAsFixed(5)}, '
                          '${_punto.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ColoresApp.grisOscuro,
                          ),
                        ),

                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _ciudad,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Ciudad',
                            hintText: 'Confirma la ciudad del punto elegido',
                            prefixIcon: Icon(Icons.location_city),
                          ),
                          validator: (valor) {
                            if ((valor?.trim().length ?? 0) < 2) {
                              return 'Escribe la ciudad.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _sector,
                          maxLength: 100,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Sector (opcional)',
                            hintText: 'Ejemplo: Centro o Sector ESPOCH',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          'Confirma manualmente la ciudad y el sector '
                          'del marcador seleccionado.',
                          style: TextStyle(
                            fontSize: 12,
                            color: ColoresApp.grisOscuro,
                          ),
                        ),

                        const SizedBox(height: 24),

                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: ColoresApp.verdeAzulado,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          onPressed: _guardar,
                          icon: const Icon(Icons.check),
                          label: const Text('Usar esta ubicación'),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
