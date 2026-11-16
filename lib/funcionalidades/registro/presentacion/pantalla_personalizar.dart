import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../terminos/datos/contenido_terminos.dart';
import '../../terminos/presentacion/pantalla_terminos.dart';
import '../datos/repositorio_perfil.dart';
import 'pantalla_registro_completado.dart';

class PantallaPersonalizar extends StatefulWidget {
  const PantallaPersonalizar({
    super.key,
    required this.datos,
    this.borradorInicial,
    this.alCambiarBorrador,
  });

  final Map<String, dynamic> datos;
  final Map<String, dynamic>? borradorInicial;
  final ValueChanged<Map<String, dynamic>>? alCambiarBorrador;

  @override
  State<PantallaPersonalizar> createState() => _EstadoPantallaPersonalizar();
}

class _EstadoPantallaPersonalizar extends State<PantallaPersonalizar> {
  final _repositorioPerfil = RepositorioPerfil();
  final _presentacion = TextEditingController();
  final _disponibilidad = TextEditingController();

  Uint8List? _foto;
  bool _cargandoFoto = false;
  bool _aceptoTerminos = false;
  bool _guardandoRegistro = false;
  String? _errorRegistro;

  bool get _esPrestador => widget.datos['rol'] == 'prestador';

  @override
  void initState() {
    super.initState();
    final borrador = widget.borradorInicial;
    if (borrador != null) {
      _presentacion.text = (borrador['presentacion'] ?? '').toString();
      _disponibilidad.text = (borrador['disponibilidad'] ?? '').toString();
      if (borrador['foto'] is Uint8List) {
        _foto = borrador['foto'] as Uint8List;
      }
      _aceptoTerminos = borrador['aceptoTerminos'] == true;
    }
    _presentacion.addListener(_notificarBorrador);
    _disponibilidad.addListener(_notificarBorrador);
  }

  void _notificarBorrador() {
    widget.alCambiarBorrador?.call({
      'presentacion': _presentacion.text,
      'disponibilidad': _disponibilidad.text,
      'foto': _foto,
      'aceptoTerminos': _aceptoTerminos,
    });
  }

  @override
  void dispose() {
    _presentacion.removeListener(_notificarBorrador);
    _disponibilidad.removeListener(_notificarBorrador);
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
      _notificarBorrador();
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

  void _abrirDocumentoLegal(int pestanaInicial) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaTerminos(
          modo: ModoTerminos.consulta,
          pestanaInicial: pestanaInicial,
        ),
      ),
    );
  }

  Future<void> _terminar({bool omitir = false}) async {
    if (_cargandoFoto || _guardandoRegistro) return;

    if (!_aceptoTerminos) {
      aviso(
        context,
        'Debes marcar la casilla de aceptación de Términos y condiciones y Política de privacidad para completar el registro.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _guardandoRegistro = true;
      _errorRegistro = null;
    });

    final datosCompletos = <String, dynamic>{
      ...widget.datos,
      'presentacion': omitir ? '' : _presentacion.text.trim(),
      'disponibilidad': omitir ? '' : _disponibilidad.text.trim(),
      'foto': omitir ? null : _foto,
    };

    try {
      // 1. Guarda los datos del perfil en usuarios/{uid}
      await _repositorioPerfil.guardar(datosCompletos);

      // 2. Registra la aceptación de términos asociada al UID autenticado en servidor y Firestore
      final aceptacion = await _repositorioPerfil.registrarAceptacionTerminos(
        versionTerminos: versionTerminosVigente,
        versionPrivacidad: versionPrivacidadVigente,
      );

      // 3. Relee el perfil desde Firestore para asegurar consistencia total
      final perfilLeido = await _repositorioPerfil.leer();

      final perfilFinal = <String, dynamic>{
        ...datosCompletos,
        ...?perfilLeido,
        'terminosAceptados': perfilLeido?['terminosAceptados'] ?? aceptacion,
        if (!omitir && _foto != null) 'foto': _foto,
      };

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => PantallaRegistroCompletado(perfil: perfilFinal),
        ),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;

      final mensaje = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorRegistro = mensaje.isNotEmpty ? mensaje : 'No pudimos completar tu registro. Revisa tu conexión e inténtalo nuevamente.';
      });
      aviso(context, _errorRegistro!);
    } finally {
      if (mounted) {
        setState(() {
          _guardandoRegistro = false;
        });
      }
    }
  }

  Widget _panelConsentimientoTerminos() {
    return TarjetaHelpi(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _aceptoTerminos,
                activeColor: ColoresApp.verdeAzulado,
                onChanged: _guardandoRegistro
                    ? null
                    : (valor) {
                        setState(() {
                          _aceptoTerminos = valor ?? false;
                          _errorRegistro = null;
                        });
                        _notificarBorrador();
                      },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _guardandoRegistro
                      ? null
                      : () {
                          setState(() {
                            _aceptoTerminos = !_aceptoTerminos;
                            _errorRegistro = null;
                          });
                          _notificarBorrador();
                        },
                  child: const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'He leído y acepto los Términos y condiciones y la Política de privacidad de HELPI.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.azulMarino,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _abrirDocumentoLegal(0),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text(
                    'Leer Términos y condiciones (v1.0)',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _abrirDocumentoLegal(1),
                  icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                  label: const Text(
                    'Leer Política de privacidad (v1.0)',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_aceptoTerminos) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                'Marca la casilla para habilitar la finalización de tu registro.',
                style: TextStyle(fontSize: 11, color: ColoresApp.grisOscuro),
              ),
            ),
          ],
          if (_errorRegistro != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE8E6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorRegistro!,
                style: const TextStyle(fontSize: 12, color: ColoresApp.coral),
              ),
            ),
          ],
        ],
      ),
    );
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
                              onPressed: (_cargandoFoto || _guardandoRegistro)
                                  ? null
                                  : () {
                                      setState(() {
                                        _foto = null;
                                      });
                                      _notificarBorrador();
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

                    const SizedBox(height: 24),

                    _panelConsentimientoTerminos(),

                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed:
                          (_cargandoFoto ||
                              _guardandoRegistro ||
                              !_aceptoTerminos)
                          ? null
                          : () => _terminar(),
                      child: Text(
                        _guardandoRegistro
                            ? 'Completando registro…'
                            : 'Completar mi perfil',
                      ),
                    ),

                    TextButton(
                      onPressed:
                          (_cargandoFoto ||
                              _guardandoRegistro ||
                              !_aceptoTerminos)
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
