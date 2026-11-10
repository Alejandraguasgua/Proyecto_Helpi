import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';

class PantallaPersonalizar extends StatefulWidget {
  const PantallaPersonalizar({super.key, required this.datos});

  final Map<String, dynamic> datos;

  @override
  State<PantallaPersonalizar> createState() => _EstadoPantallaPersonalizar();
}

class _EstadoPantallaPersonalizar extends State<PantallaPersonalizar> {
  final _presentacion = TextEditingController();
  final _disponibilidad = TextEditingController();

  Uint8List? _foto;
  bool _cargandoFoto = false;

  bool get _esPrestador => widget.datos['rol'] == 'prestador';

  @override
  void dispose() {
    _presentacion.dispose();
    _disponibilidad.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    setState(() {
      _cargandoFoto = true;
    });

    try {
      final imagen = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
        requestFullMetadata: false,
      );

      if (imagen == null) return;

      final contenido = await imagen.readAsBytes();

      if (contenido.length > 5 * 1024 * 1024) {
        if (mounted) {
          aviso(context, 'Selecciona una imagen menor de 5 MB.');
        }
        return;
      }

      // Comprueba que el archivo puede mostrarse como imagen.
      final imagenDecodificada = await decodeImageFromList(contenido);
      imagenDecodificada.dispose();

      if (!mounted) return;

      setState(() {
        _foto = contenido;
      });
    } catch (_) {
      if (mounted) {
        aviso(
          context,
          'No pudimos abrir la foto. Prueba con una imagen JPG o PNG.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargandoFoto = false;
        });
      }
    }
  }

  void _terminar({bool omitir = false}) {
    Navigator.of(context).pop<Map<String, dynamic>>({
      ...widget.datos,
      'presentacion': omitir ? '' : _presentacion.text.trim(),
      'disponibilidad': omitir ? '' : _disponibilidad.text.trim(),
      'foto': omitir ? null : _foto,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personaliza tu perfil')),
      body: FondoHelpi(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Chip(label: Text('Paso 2 de 2 · Opcional')),
                    ),

                    const SizedBox(height: 12),

                    const LinearProgressIndicator(value: 1, minHeight: 5),

                    const SizedBox(height: 28),

                    Text(
                      'Personaliza tu perfil',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Ayuda a que la comunidad te conozca. '
                      'Puedes completar estos datos después.',
                    ),

                    const SizedBox(height: 26),

                    TarjetaHelpi(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: ColoresApp.verdeMenta,
                            backgroundImage: _foto == null
                                ? null
                                : MemoryImage(_foto!),
                            child: _foto == null
                                ? const Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 36,
                                    color: ColoresApp.verdeAzulado,
                                  )
                                : null,
                          ),

                          const SizedBox(height: 14),

                          TextButton(
                            onPressed: _cargandoFoto ? null : _seleccionarFoto,
                            child: Text(
                              _cargandoFoto
                                  ? 'Abriendo imagen…'
                                  : 'Seleccionar foto',
                            ),
                          ),

                          if (_foto != null)
                            TextButton(
                              onPressed: _cargandoFoto
                                  ? null
                                  : () {
                                      setState(() {
                                        _foto = null;
                                      });
                                    },
                              child: const Text('Quitar foto'),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Presentación breve',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _presentacion,
                      maxLength: 300,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Cuéntanos un poco sobre ti…',
                      ),
                    ),

                    if (_esPrestador) ...[
                      const SizedBox(height: 16),

                      Text(
                        'Disponibilidad general',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _disponibilidad,
                        maxLength: 150,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Ej. De lunes a viernes por las tardes.',
                        ),
                      ),

                      const Text(
                        'La fecha y el horario de cada trabajo '
                        'se acuerdan en la solicitud.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 28),

                    FilledButton(
                      onPressed: _cargandoFoto ? null : () => _terminar(),
                      child: const Text('Completar mi perfil'),
                    ),

                    TextButton(
                      onPressed: _cargandoFoto
                          ? null
                          : () => _terminar(omitir: true),
                      child: const Text('Hacerlo después'),
                    ),

                    const EtiquetaDemo(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
