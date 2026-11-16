import 'dart:math';

import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../inicio/presentacion/pantalla_elegir_ubicacion.dart';
import '../datos/repositorio_solicitudes.dart';

enum ModoFormularioSolicitud { crear, editar, duplicar }

class PantallaSolicitud extends StatefulWidget {
  const PantallaSolicitud({
    super.key,
    this.modo = ModoFormularioSolicitud.crear,
    this.solicitudInicial,
    this.categoriaInicial,
  });

  final ModoFormularioSolicitud modo;
  final Map<String, dynamic>? solicitudInicial;
  final String? categoriaInicial;

  @override
  State<PantallaSolicitud> createState() => _EstadoPantallaSolicitud();
}

class _EstadoPantallaSolicitud extends State<PantallaSolicitud> {
  final _formulario = GlobalKey<FormState>();
  final _repositorio = RepositorioSolicitudes();

  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _horario = TextEditingController();
  final _monto = TextEditingController();

  static const _categorias = [
    'Soporte técnico',
    'Tutorías',
    'Reparaciones',
    'Hogar',
    'Mascotas',
    'Mudanzas',
  ];

  String _categoria = 'Soporte técnico';
  String _ciudad = '';
  String _sector = '';

  double? _latitud;
  double? _longitud;
  DateTime? _fechaServicio;

  // Valores iniciales para detectar cambios sin guardar
  String _tituloInicial = '';
  String _descripcionInicial = '';
  String _categoriaInicial = 'Soporte técnico';
  String _horarioInicial = '';
  String _montoInicial = '';
  String _ciudadInicial = '';
  String _sectorInicial = '';
  double? _latitudInicial;
  double? _longitudInicial;
  DateTime? _fechaInicial;

  late final String _claveIdempotencia;
  bool _fechaOriginalVencida = false;
  bool _guardando = false;

  bool get _esEdicion => widget.modo == ModoFormularioSolicitud.editar;
  bool get _esDuplicacion => widget.modo == ModoFormularioSolicitud.duplicar;

  @override
  void initState() {
    super.initState();
    _claveIdempotencia = _generarClaveIdempotencia();
    _precargarDatos();
  }

  String _generarClaveIdempotencia() {
    final random = Random();
    final bytes = List<int>.generate(12, (_) => random.nextInt(36));
    final sufijo = bytes.map((v) => v.toRadixString(36)).join();
    return 'op_${DateTime.now().millisecondsSinceEpoch}_$sufijo';
  }

  void _precargarDatos() {
    final inicial = widget.solicitudInicial;

    if (inicial == null) {
      if (widget.categoriaInicial != null &&
          _categorias.contains(widget.categoriaInicial)) {
        _categoria = widget.categoriaInicial!;
        _categoriaInicial = _categoria;
      }
      return;
    }

    _titulo.text = (inicial['titulo'] ?? '').toString().trim();
    _descripcion.text = (inicial['descripcion'] ?? '').toString().trim();
    _horario.text = (inicial['horario'] ?? '').toString().trim();

    final cat = (inicial['categoria'] ?? '').toString().trim();
    if (_categorias.contains(cat)) {
      _categoria = cat;
    }

    final centavos = inicial['montoCentavos'];
    if (centavos is num && centavos > 0) {
      final valorUsd = centavos / 100;
      _monto.text = (centavos % 100 == 0)
          ? valorUsd.toInt().toString()
          : valorUsd.toStringAsFixed(2);
    }

    _ciudad = (inicial['ciudad'] ?? '').toString().trim();
    _sector = (inicial['sector'] ?? '').toString().trim();

    final ubicacion = inicial['ubicacion'];
    if (ubicacion is Map) {
      final lat = ubicacion['latitud'];
      final lng = ubicacion['longitud'];
      if (lat is num) _latitud = lat.toDouble();
      if (lng is num) _longitud = lng.toDouble();
    }

    final fechaParseada = DateTime.tryParse(
      (inicial['fechaServicio'] ?? '').toString(),
    )?.toLocal();

    if (fechaParseada != null) {
      if (_esDuplicacion && !fechaParseada.isAfter(DateTime.now())) {
        // En duplicación no se reutiliza automáticamente una fecha vencida
        _fechaServicio = null;
        _fechaOriginalVencida = true;
      } else {
        _fechaServicio = fechaParseada;
      }
    }

    _tituloInicial = _titulo.text;
    _descripcionInicial = _descripcion.text;
    _categoriaInicial = _categoria;
    _horarioInicial = _horario.text;
    _montoInicial = _monto.text;
    _ciudadInicial = _ciudad;
    _sectorInicial = _sector;
    _latitudInicial = _latitud;
    _longitudInicial = _longitud;
    _fechaInicial = _fechaServicio;
  }

  bool get _hayCambiosSinGuardar {
    if (_esDuplicacion) {
      // En duplicación existe un borrador abierto pendiente de publicar
      return true;
    }

    return _titulo.text.trim() != _tituloInicial ||
        _descripcion.text.trim() != _descripcionInicial ||
        _categoria != _categoriaInicial ||
        _horario.text.trim() != _horarioInicial ||
        _monto.text.trim() != _montoInicial ||
        _ciudad != _ciudadInicial ||
        _sector != _sectorInicial ||
        _latitud != _latitudInicial ||
        _longitud != _longitudInicial ||
        _fechaServicio?.toIso8601String() != _fechaInicial?.toIso8601String();
  }

  Future<void> _intentarSalir() async {
    if (_guardando) return;

    if (!_hayCambiosSinGuardar) {
      Navigator.of(context).pop(false);
      return;
    }

    final descartar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(
          _esEdicion ? '¿Descartar cambios?' : '¿Salir sin publicar?',
        ),
        content: Text(
          _esEdicion
              ? 'Tienes modificaciones sin guardar en esta solicitud. Si sales ahora, se perderán los cambios realizados.'
              : 'Los datos ingresados en este formulario aún no se han publicado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.coral),
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );

    if (descartar == true && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  String _mostrarFecha(DateTime fecha) {
    String dos(int numero) => numero.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final fechaBase = (_fechaServicio != null && _fechaServicio!.isAfter(ahora))
        ? _fechaServicio!
        : ahora.add(const Duration(hours: 2));

    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaBase,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: DateTime(ahora.year + 2, 12, 31),
    );

    if (fecha == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fechaBase),
    );

    if (hora == null || !mounted) return;

    final seleccion = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      hora.hour,
      hora.minute,
    );

    if (!seleccion.isAfter(DateTime.now())) {
      aviso(context, 'Selecciona una fecha y hora futuras.');
      return;
    }

    setState(() {
      _fechaServicio = seleccion;
      _fechaOriginalVencida = false;
    });
  }

  Future<void> _elegirUbicacion() async {
    final resultado = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => PantallaElegirUbicacion(
          ciudad: _ciudad.isEmpty ? 'Riobamba' : _ciudad,
          sector: _sector,
          latitud: _latitud,
          longitud: _longitud,
        ),
      ),
    );

    if (resultado == null || !mounted) return;

    setState(() {
      _ciudad = resultado['ciudad']?.trim() ?? '';
      _sector = resultado['sector']?.trim() ?? '';
      _latitud = double.tryParse(resultado['latitud'] ?? '');
      _longitud = double.tryParse(resultado['longitud'] ?? '');
    });
  }

  int _montoCentavos() {
    final texto = _monto.text.trim().replaceAll(',', '.');
    final partes = texto.split('.');
    final enteros = int.parse(partes[0]);

    final decimales = partes.length == 2
        ? int.parse(partes[1].padRight(2, '0'))
        : 0;

    return enteros * 100 + decimales;
  }

  String? _validarMonto(String? valor) {
    final texto = (valor ?? '').trim().replaceAll(',', '.');

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(texto)) {
      return 'Escribe un monto con máximo dos decimales.';
    }

    final numero = double.tryParse(texto);

    if (numero == null || numero < 1 || numero > 10000) {
      return 'El monto debe estar entre USD 1 y USD 10.000.';
    }

    return null;
  }

  Future<void> _mostrarConflictoEdicion(String mensaje) async {
    final actualizar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('No se pudo guardar la edición'),
        content: Text(
          '$mensaje\n\n'
          'Puedes volver al detalle para actualizar el estado actual de la solicitud, '
          'o permanecer aquí si deseas copiar lo que escribiste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Permanecer aquí'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Actualizar detalle'),
          ),
        ],
      ),
    );

    if (actualizar == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) return;

    final fecha = _fechaServicio;

    if (fecha == null || !fecha.isAfter(DateTime.now())) {
      aviso(context, 'Selecciona una fecha y hora futuras.');
      return;
    }

    if (_ciudad.length < 2 ||
        _sector.length < 2 ||
        _latitud == null ||
        _longitud == null) {
      aviso(context, 'Selecciona el punto, la ciudad y el sector.');
      return;
    }

    final datos = <String, dynamic>{
      'titulo': _titulo.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'categoria': _categoria,
      'fechaServicio': fecha.toUtc().toIso8601String(),
      'horario': _horario.text.trim(),
      'montoCentavos': _montoCentavos(),
      'ciudad': _ciudad,
      'sector': _sector,
      'ubicacion': {'latitud': _latitud, 'longitud': _longitud},
    };

    setState(() {
      _guardando = true;
    });

    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (contextoDialogo) => AlertDialog(
          title: Text(
            _esEdicion
                ? 'Confirmar cambios'
                : (_esDuplicacion
                      ? 'Publicar solicitud similar'
                      : 'Revisar solicitud'),
          ),
          content: SingleChildScrollView(
            child: Text(
              '${datos['titulo']}\n\n'
              'Categoría: $_categoria\n'
              'Ubicación: $_ciudad · $_sector\n'
              'Fecha: ${_mostrarFecha(fecha)}\n'
              'Horario: ${_horario.text.trim()}\n'
              'Monto ofrecido: USD '
              '${((datos['montoCentavos'] as int) / 100).toStringAsFixed(2)}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextoDialogo, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(contextoDialogo, true),
              child: Text(_esEdicion ? 'Guardar cambios' : 'Publicar'),
            ),
          ],
        ),
      );

      if (confirmar != true || !mounted) return;

      if (_esEdicion) {
        final id = widget.solicitudInicial?['id']?.toString() ?? '';
        final version = widget.solicitudInicial?['version'];
        await _repositorio.guardar({
          ...datos,
          'version': version is int ? version : 1,
        }, id: id);
      } else if (_esDuplicacion) {
        final idOrigen = widget.solicitudInicial?['id']?.toString() ?? '';
        await _repositorio.duplicar(idOrigen, {
          ...datos,
          'claveIdempotencia': _claveIdempotencia,
        });
      } else {
        await _repositorio.guardar({
          ...datos,
          'claveIdempotencia': _claveIdempotencia,
        });
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final mensaje = error.toString().replaceFirst('Exception: ', '');

      if (_esEdicion &&
          (mensaje.contains('cambió') ||
              mensaje.contains('aceptada') ||
              mensaje.contains('Solo puedes editar'))) {
        await _mostrarConflictoEdicion(mensaje);
      } else {
        aviso(context, mensaje);
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  Widget _campo({
    required String etiqueta,
    required TextEditingController controlador,
    required int minimo,
    required int maximo,
    int lineas = 1,
    TextInputType? teclado,
    String? Function(String?)? validar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controlador,
        enabled: !_guardando,
        maxLength: maximo,
        maxLines: lineas,
        keyboardType: teclado,
        decoration: InputDecoration(labelText: etiqueta),
        validator:
            validar ??
            (valor) {
              if ((valor?.trim().length ?? 0) < minimo) {
                return 'Escribe al menos $minimo caracteres.';
              }

              return null;
            },
      ),
    );
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _horario.dispose();
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tituloAppBar = _esEdicion
        ? 'Editar solicitud'
        : (_esDuplicacion ? 'Crear solicitud similar' : 'Solicitar ayuda');

    final subtituloFormulario = _esEdicion
        ? 'Modifica los datos de tu solicitud publicada'
        : (_esDuplicacion
              ? 'Revisa los datos precargados para la nueva solicitud'
              : '¿Qué ayuda necesitas?');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _intentarSalir();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _guardando ? null : _intentarSalir,
          ),
          title: Text(tituloAppBar),
        ),
        body: FondoHelpi(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        subtituloFormulario,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (_esDuplicacion) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ColoresApp.verdeMenta,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.copy_all_outlined,
                                color: ColoresApp.verdeAzulado,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _fechaOriginalVencida
                                      ? 'La fecha original ya pasó. Selecciona una nueva fecha y hora futuras para publicar esta solicitud similar.'
                                      : 'Se creará una solicitud nueva e independiente sin modificar la solicitud original.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ColoresApp.azulMarino,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _campo(
                        etiqueta: 'Título',
                        controlador: _titulo,
                        minimo: 5,
                        maximo: 100,
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_categoria),
                        initialValue: _categoria,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
                        items: _categorias.map((categoria) {
                          return DropdownMenuItem(
                            value: categoria,
                            child: Text(categoria),
                          );
                        }).toList(),
                        onChanged: _guardando
                            ? null
                            : (valor) {
                                if (valor == null) return;

                                setState(() {
                                  _categoria = valor;
                                });
                              },
                      ),
                      const SizedBox(height: 20),
                      _campo(
                        etiqueta: 'Describe la ayuda que necesitas',
                        controlador: _descripcion,
                        minimo: 15,
                        maximo: 1000,
                        lineas: 4,
                      ),
                      OutlinedButton.icon(
                        onPressed: _guardando ? null : _elegirFecha,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          _fechaServicio == null
                              ? 'Seleccionar fecha y hora futuras'
                              : _mostrarFecha(_fechaServicio!),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _campo(
                        etiqueta: 'Horario o duración acordada',
                        controlador: _horario,
                        minimo: 3,
                        maximo: 100,
                      ),
                      _campo(
                        etiqueta: 'Monto ofrecido en USD',
                        controlador: _monto,
                        minimo: 1,
                        maximo: 8,
                        teclado: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validar: _validarMonto,
                      ),
                      OutlinedButton.icon(
                        onPressed: _guardando ? null : _elegirUbicacion,
                        icon: const Icon(Icons.location_on_outlined),
                        label: Text(
                          _ciudad.isEmpty
                              ? 'Seleccionar ubicación'
                              : '$_ciudad · $_sector',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _esEdicion
                                    ? Icons.save_outlined
                                    : Icons.publish_outlined,
                              ),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _guardando
                                ? 'Procesando…'
                                : (_esEdicion
                                      ? 'Guardar cambios'
                                      : 'Revisar y publicar solicitud'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _guardando ? null : _intentarSalir,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Cancelar'),
                        ),
                      ),
                    ],
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
