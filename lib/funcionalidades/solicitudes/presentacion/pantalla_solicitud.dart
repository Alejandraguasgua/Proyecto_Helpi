import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../inicio/presentacion/pantalla_elegir_ubicacion.dart';
import '../datos/repositorio_solicitudes.dart';

class PantallaSolicitud extends StatefulWidget {
  const PantallaSolicitud({super.key});

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

  bool _guardando = false;

  String _mostrarFecha(DateTime fecha) {
    String dos(int numero) => numero.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();

    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaServicio ?? ahora,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: DateTime(ahora.year + 2, 12, 31),
    );

    if (fecha == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _fechaServicio ?? ahora.add(const Duration(hours: 1)),
      ),
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
    // La validación garantiza como máximo dos decimales.
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

    // Bloquea el formulario mientras se confirma y guarda.
    setState(() {
      _guardando = true;
    });

    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (contextoDialogo) => AlertDialog(
          title: const Text('Revisar solicitud'),
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
              child: const Text('Publicar'),
            ),
          ],
        ),
      );

      if (confirmar != true || !mounted) return;

      await _repositorio.guardar(datos);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        aviso(context, error.toString().replaceFirst('Exception: ', ''));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar ayuda')),
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
                      '¿Qué ayuda necesitas?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    _campo(
                      etiqueta: 'Título',
                      controlador: _titulo,
                      minimo: 5,
                      maximo: 100,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _categoria,
                      decoration: const InputDecoration(labelText: 'Categoría'),
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
                            ? 'Seleccionar fecha y hora'
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
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _guardando
                              ? 'Procesando…'
                              : 'Revisar y publicar solicitud',
                        ),
                      ),
                    ),
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
