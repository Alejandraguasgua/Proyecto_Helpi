import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../registro/datos/repositorio_perfil.dart';

class PantallaEditarPerfil extends StatefulWidget {
  const PantallaEditarPerfil({super.key, required this.perfil});

  final Map<String, dynamic> perfil;

  @override
  State<PantallaEditarPerfil> createState() => _EstadoPantallaEditarPerfil();
}

class _EstadoPantallaEditarPerfil extends State<PantallaEditarPerfil> {
  final _formulario = GlobalKey<FormState>();
  final _repositorio = RepositorioPerfil();

  late final TextEditingController _nombre;
  late final TextEditingController _telefono;
  late final TextEditingController _ciudad;
  late final TextEditingController _sector;
  late final TextEditingController _presentacion;
  late final TextEditingController _disponibilidad;
  late final TextEditingController _habilidades;

  final Set<String> _categoriasSeleccionadas = {};

  static const _catalogoCategorias = [
    'Soporte técnico',
    'Tutorías',
    'Reparaciones',
    'Hogar',
    'Mascotas',
    'Mudanzas',
  ];

  bool _guardando = false;
  String? _error;

  bool get _esPrestador => widget.perfil['rol'] == 'prestador';

  String _extraerDigitosCelular(String telefono) {
    final limpio = telefono.trim();
    if (limpio.startsWith('+593')) {
      return limpio.substring(4);
    }
    if (limpio.startsWith('0') && limpio.length == 10) {
      return limpio.substring(1);
    }
    return limpio;
  }

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(
      text: (widget.perfil['nombre'] ?? '').toString(),
    );
    _telefono = TextEditingController(
      text: _extraerDigitosCelular(
        (widget.perfil['telefono'] ?? '').toString(),
      ),
    );
    _ciudad = TextEditingController(
      text: (widget.perfil['ciudad'] ?? '').toString(),
    );
    _sector = TextEditingController(
      text: (widget.perfil['sector'] ?? '').toString(),
    );
    _presentacion = TextEditingController(
      text: (widget.perfil['presentacion'] ?? '').toString(),
    );
    _disponibilidad = TextEditingController(
      text: (widget.perfil['disponibilidad'] ?? '').toString(),
    );
    _habilidades = TextEditingController(
      text: (widget.perfil['habilidades'] ?? '').toString(),
    );

    final cats = widget.perfil['categorias'];
    if (cats is List) {
      for (final c in cats) {
        final textoCat = c.toString();
        if (_catalogoCategorias.contains(textoCat)) {
          _categoriasSeleccionadas.add(textoCat);
        }
      }
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _ciudad.dispose();
    _sector.dispose();
    _presentacion.dispose();
    _disponibilidad.dispose();
    _habilidades.dispose();
    super.dispose();
  }

  bool get _hayCambiosSinGuardar {
    final telOriginal = _extraerDigitosCelular(
      (widget.perfil['telefono'] ?? '').toString(),
    );
    final catsOriginales = <String>{};
    final cats = widget.perfil['categorias'];
    if (cats is List) {
      for (final c in cats) {
        catsOriginales.add(c.toString());
      }
    }

    return _nombre.text.trim() !=
            (widget.perfil['nombre'] ?? '').toString().trim() ||
        _telefono.text.trim() != telOriginal ||
        _ciudad.text.trim() !=
            (widget.perfil['ciudad'] ?? '').toString().trim() ||
        _sector.text.trim() !=
            (widget.perfil['sector'] ?? '').toString().trim() ||
        _presentacion.text.trim() !=
            (widget.perfil['presentacion'] ?? '').toString().trim() ||
        _disponibilidad.text.trim() !=
            (widget.perfil['disponibilidad'] ?? '').toString().trim() ||
        _habilidades.text.trim() !=
            (widget.perfil['habilidades'] ?? '').toString().trim() ||
        !_categoriasSeleccionadas.containsAll(catsOriginales) ||
        !catsOriginales.containsAll(_categoriasSeleccionadas);
  }

  Future<bool> _confirmarSalida() async {
    if (_guardando) return false;
    if (!_hayCambiosSinGuardar) return true;

    final salir = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text(
          'Tienes cambios sin guardar en tu perfil. ¿Deseas salir sin guardarlos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return salir == true;
  }

  Future<void> _guardarCambios() async {
    if (_guardando) return;

    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) {
      return;
    }

    if (_esPrestador && _categoriasSeleccionadas.isEmpty) {
      aviso(context, 'Selecciona al menos una categoría de ayuda.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final cambios = <String, dynamic>{
        'nombre': _nombre.text.trim(),
        'telefono': '+593${_telefono.text.trim()}',
        'ciudad': _ciudad.text.trim(),
        'sector': _sector.text.trim(),
        'presentacion': _presentacion.text.trim(),
        'disponibilidad': _disponibilidad.text.trim(),
        'habilidades': _habilidades.text.trim(),
        'categorias': _categoriasSeleccionadas.toList(),
      };

      final actualizado = await _repositorio.actualizarCampos(cambios);

      if (!mounted) return;

      Navigator.of(context).pop<Map<String, dynamic>>(actualizado);
    } catch (error) {
      if (!mounted) return;

      final mensaje = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = mensaje.isNotEmpty ? mensaje : 'No pudimos guardar los cambios de tu perfil. Inténtalo de nuevo.';
      });
      aviso(context, _error!);
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final correo = (widget.perfil['correo'] ?? '').toString().trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final puedeSalir = await _confirmarSalida();
        if (puedeSalir && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar mi perfil')),
        body: FondoHelpi(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formulario,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Actualiza tus datos',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tu información ayuda a coordinar servicios con confianza dentro de la comunidad.',
                          style: TextStyle(color: ColoresApp.grisOscuro),
                        ),
                        const SizedBox(height: 20),
                        TarjetaHelpi(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (correo.isNotEmpty) ...[
                                const Text(
                                  'Cuenta autenticada',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ColoresApp.verdeAzulado,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  correo,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: ColoresApp.grisOscuro,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                'Nombre completo *',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nombre,
                                maxLength: 80,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Ej. Camila Morales',
                                  prefixIcon: Icon(Icons.person_outline),
                                  counterText: '',
                                ),
                                validator: (valor) {
                                  final limpio = valor?.trim() ?? '';
                                  if (limpio.length < 3) {
                                    return 'Escribe al menos 3 caracteres.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Número de teléfono *',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _telefono,
                                keyboardType: TextInputType.phone,
                                maxLength: 9,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(9),
                                ],
                                decoration: const InputDecoration(
                                  hintText: '991234567',
                                  counterText: '',
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(
                                      left: 12,
                                      right: 12,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.phone_outlined),
                                        SizedBox(width: 10),
                                        Text(
                                          '+593',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: ColoresApp.azulMarino,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                      ],
                                    ),
                                  ),
                                ),
                                validator: (valor) {
                                  final tel = valor?.trim() ?? '';
                                  if (!RegExp(r'^9[0-9]{8}$').hasMatch(tel)) {
                                    return 'Ingresa 9 dígitos empezando por 9, sin el 0.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Ciudad *',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _ciudad,
                                maxLength: 80,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Ej. Riobamba',
                                  prefixIcon: Icon(
                                    Icons.location_city_outlined,
                                  ),
                                  counterText: '',
                                ),
                                validator: (valor) {
                                  if ((valor?.trim().length ?? 0) < 2) {
                                    return 'Escribe al menos 2 caracteres.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Sector aproximado *',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _sector,
                                maxLength: 100,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Ej. Sector ESPOCH',
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                  counterText: '',
                                ),
                                validator: (valor) {
                                  if ((valor?.trim().length ?? 0) < 3) {
                                    return 'Escribe al menos 3 caracteres.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Sobre mí (presentación)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _presentacion,
                                maxLength: 300,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Cuéntanos un poco sobre ti…',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Categorías de ayuda',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _catalogoCategorias.map((cat) {
                                  return FilterChip(
                                    label: Text(cat),
                                    selected: _categoriasSeleccionadas.contains(
                                      cat,
                                    ),
                                    selectedColor: ColoresApp.verdeMenta,
                                    onSelected: (sel) {
                                      setState(() {
                                        if (sel) {
                                          _categoriasSeleccionadas.add(cat);
                                        } else {
                                          _categoriasSeleccionadas.remove(cat);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Habilidades',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _habilidades,
                                maxLength: 500,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Ej. Instalo programas y configuro redes domésticas.',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Disponibilidad general',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _disponibilidad,
                                maxLength: 150,
                                maxLines: 2,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Ej. De lunes a viernes por las tardes.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE8E6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: ColoresApp.coral,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _guardando ? null : _guardarCambios,
                          icon: _guardando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _guardando ? 'Guardando…' : 'Guardar cambios',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _guardando
                              ? null
                              : () async {
                                  final salir = await _confirmarSalida();
                                  if (salir && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
