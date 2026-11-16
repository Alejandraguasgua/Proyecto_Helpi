import 'dart:async';

import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/servicios/cliente_api.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../registro/datos/repositorio_perfil.dart';
import '../../terminos/presentacion/pantalla_terminos.dart';
import '../datos/repositorio_solicitudes.dart';
import 'pantalla_detalle_servicio.dart';

class VistaMisServicios extends StatefulWidget {
  const VistaMisServicios({
    super.key,
    required this.esPrestador,
    this.alActualizarPerfil,
  });

  final bool esPrestador;
  final ValueChanged<Map<String, dynamic>>? alActualizarPerfil;

  @override
  State<VistaMisServicios> createState() => _EstadoVistaMisServicios();
}

class _EstadoVistaMisServicios extends State<VistaMisServicios> {
  final _repositorio = RepositorioSolicitudes();
  final _busqueda = TextEditingController();
  final List<Map<String, dynamic>> _servicios = [];

  Timer? _temporizadorBusqueda;

  static const _estados = [
    'Todas',
    'Publicada',
    'Aceptada',
    'En Proceso',
    'Completada',
    'Cancelada',
  ];

  static const _categorias = [
    'Todas',
    'Soporte técnico',
    'Tutorías',
    'Reparaciones',
    'Hogar',
    'Mascotas',
    'Mudanzas',
  ];

  late bool _modoPrestador;
  String _filtroEstado = 'Todas';
  String _filtroCategoria = 'Todas';
  String _orden = 'recientes';

  int _versionConsulta = 0;
  bool _cargando = false;
  bool _cargandoMas = false;
  bool _requiereAceptarTerminos = false;
  String? _error;
  String? _cursor;

  bool get _tieneFiltrosActivos =>
      _filtroEstado != 'Todas' ||
      _filtroCategoria != 'Todas' ||
      _busqueda.text.trim().isNotEmpty ||
      _orden != 'recientes';

  @override
  void initState() {
    super.initState();
    _modoPrestador = widget.esPrestador;
    _cargar();
  }

  @override
  void didUpdateWidget(covariant VistaMisServicios oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.esPrestador != widget.esPrestador) {
      setState(() {
        _modoPrestador = widget.esPrestador;
      });
      _cargar();
    }
  }

  @override
  void dispose() {
    _temporizadorBusqueda?.cancel();
    _versionConsulta++;
    _busqueda.dispose();
    super.dispose();
  }

  void _alCambiarBusqueda(String _) {
    _temporizadorBusqueda?.cancel();
    setState(() {});
    _temporizadorBusqueda = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _cargar();
      }
    });
  }

  void _limpiarFiltros() {
    _temporizadorBusqueda?.cancel();
    setState(() {
      _filtroEstado = 'Todas';
      _filtroCategoria = 'Todas';
      _orden = 'recientes';
      _busqueda.clear();
    });
    _cargar();
  }

  Future<void> _cargar({bool mas = false}) async {
    if (mas && (_cargando || _cargandoMas || _cursor == null)) return;

    final int version = mas ? _versionConsulta : ++_versionConsulta;
    final String? cursorConsulta = mas ? _cursor : null;
    final textoBusqueda = _busqueda.text.trim();

    setState(() {
      _error = null;
      _requiereAceptarTerminos = false;
      if (mas) {
        _cargandoMas = true;
      } else {
        _cargando = true;
        _servicios.clear();
        _cursor = null;
      }
    });

    try {
      final filtros = <String, String>{
        if (_modoPrestador) 'aceptadas': 'true',
        if (!_modoPrestador) 'mias': 'true',
        if (_filtroEstado != 'Todas') 'estado': _filtroEstado,
        if (_filtroCategoria != 'Todas') 'categoria': _filtroCategoria,
        if (textoBusqueda.isNotEmpty) 'busqueda': textoBusqueda,
        'orden': _orden,
        if (mas && cursorConsulta != null) 'cursor': cursorConsulta,
      };

      final pagina = await _repositorio.listar(filtros);

      if (!mounted || version != _versionConsulta) return;

      setState(() {
        final ids = _servicios.map((s) => s['id']).toSet();

        _servicios.addAll(pagina.datos.where((s) => ids.add(s['id'])));

        _cursor = pagina.cursor;
        _cargando = false;
        _cargandoMas = false;
      });
    } catch (error) {
      if (!mounted || version != _versionConsulta) return;

      final faltaAceptacion =
          error is ErrorApiHelpi && error.esFaltaAceptacionTerminos;

      setState(() {
        _requiereAceptarTerminos = faltaAceptacion;
        _error = error.toString().replaceFirst('Exception: ', '');
        _cargando = false;
        _cargandoMas = false;
      });
    }
  }

  String _fecha(dynamic valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();

    if (fecha == null) return 'Sin fecha';

    String dos(int n) => n.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  IconData _iconoCategoria(String? categoria) {
    switch (categoria) {
      case 'Soporte técnico':
        return Icons.computer_outlined;
      case 'Tutorías':
        return Icons.menu_book_outlined;
      case 'Reparaciones':
        return Icons.handyman_outlined;
      case 'Hogar':
        return Icons.chair_outlined;
      case 'Mascotas':
        return Icons.pets_outlined;
      case 'Mudanzas':
        return Icons.local_shipping_outlined;
      default:
        return Icons.handshake_outlined;
    }
  }

  Widget _badgeEstado(String estado) {
    Color fondo;
    Color texto;
    String etiqueta = estado;

    switch (estado) {
      case 'Publicada':
        fondo = ColoresApp.verdeMenta;
        texto = ColoresApp.verdeAzulado;
        etiqueta = 'Disponible';
        break;
      case 'Aceptada':
        fondo = const Color(0xFFEDF3F9);
        texto = const Color(0xFF315F7C);
        break;
      case 'En Proceso':
        fondo = const Color(0xFFFEF3C7);
        texto = const Color(0xFF92400E);
        break;
      case 'Completada':
        fondo = const Color(0xFFE6F4EA);
        texto = const Color(0xFF137333);
        break;
      case 'Cancelada':
        fondo = const Color(0xFFFCE8E6);
        texto = const Color(0xFFC5221F);
        break;
      default:
        fondo = const Color(0xFFEDF2F7);
        texto = ColoresApp.grisOscuro;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        etiqueta,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: texto,
        ),
      ),
    );
  }

  Future<void> _abrirDetalle(Map<String, dynamic> servicio) async {
    final id = servicio['id']?.toString();

    if (id == null || id.isEmpty) {
      aviso(context, 'No se encontró el identificador del servicio.');
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => PantallaDetalleServicio(id: id)),
    );

    if (!mounted) return;

    // Actualiza la lista al regresar del detalle para reflejar cualquier cambio
    await _cargar();
  }

  Widget _selectorModo() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _botonModo(
              titulo: 'Servicios solicitados',
              activo: !_modoPrestador,
              alPresionar: () {
                if (_modoPrestador) {
                  setState(() {
                    _modoPrestador = false;
                  });
                  _cargar();
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _botonModo(
              titulo: 'Servicios prestados',
              activo: _modoPrestador,
              alPresionar: () {
                if (!_modoPrestador) {
                  setState(() {
                    _modoPrestador = true;
                  });
                  _cargar();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonModo({
    required String titulo,
    required bool activo,
    required VoidCallback alPresionar,
  }) {
    return Material(
      color: activo ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: activo ? 1 : 0,
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
              color: activo ? ColoresApp.verdeAzulado : ColoresApp.grisOscuro,
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelFiltros() {
    return TarjetaHelpi(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _busqueda,
            onChanged: _alCambiarBusqueda,
            onSubmitted: (_) {
              _temporizadorBusqueda?.cancel();
              _cargar();
            },
            decoration: InputDecoration(
              labelText: 'Buscar por título',
              hintText: 'Ej. Reparación, Tutoría…',
              helperText: 'Búsqueda por prefijo desde el inicio del título (sin distinguir tildes ni mayúsculas).',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busqueda.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _temporizadorBusqueda?.cancel();
                        setState(() => _busqueda.clear());
                        _cargar();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('cat_$_filtroCategoria'),
                  initialValue: _filtroCategoria,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  items: _categorias.map((categoria) {
                    return DropdownMenuItem(
                      value: categoria,
                      child: Text(
                        categoria == 'Todas'
                            ? 'Todas las categorías'
                            : categoria,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (valor) {
                    if (valor == null || valor == _filtroCategoria) return;
                    setState(() => _filtroCategoria = valor);
                    _cargar();
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('ord_$_orden'),
                  initialValue: _orden,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ordenar por',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'recientes',
                      child: Text('Más recientes'),
                    ),
                    DropdownMenuItem(
                      value: 'fecha_servicio',
                      child: Text('Fecha del servicio'),
                    ),
                  ],
                  onChanged: (valor) {
                    if (valor == null || valor == _orden) return;
                    setState(() => _orden = valor);
                    _cargar();
                  },
                ),
              ),
              if (_tieneFiltrosActivos)
                TextButton.icon(
                  onPressed: _limpiarFiltros,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Limpiar filtros'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _filtrosEstado(),
        ],
      ),
    );
  }

  Widget _filtrosEstado() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _estados.map((estado) {
          final activo = _filtroEstado == estado;
          final etiqueta = estado == 'Publicada' ? 'Disponible' : estado;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: activo,
              label: Text(etiqueta),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? ColoresApp.blanco : ColoresApp.grisOscuro,
              ),
              backgroundColor: ColoresApp.blanco,
              selectedColor: ColoresApp.verdeAzulado,
              checkmarkColor: ColoresApp.blanco,
              side: BorderSide(
                color: activo
                    ? ColoresApp.verdeAzulado
                    : const Color(0xFFE2E8F0),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) {
                if (_filtroEstado != estado) {
                  setState(() => _filtroEstado = estado);
                  _cargar();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> servicio) {
    final centavos = servicio['montoCentavos'];
    final monto = centavos is num ? (centavos / 100).toStringAsFixed(2) : '—';
    final categoria = servicio['categoria']?.toString() ?? 'Servicio';
    final estado = servicio['estado']?.toString() ?? 'Publicada';
    final finalizacionSolicitada = servicio['finalizacionSolicitada'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TarjetaHelpi(
        child: InkWell(
          onTap: () => _abrirDetalle(servicio),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ColoresApp.verdeMenta,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconoCategoria(categoria),
                      size: 24,
                      color: ColoresApp.verdeAzulado,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _badgeEstado(estado),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'USD $monto',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.azulMarino,
                        ),
                      ),
                      const Text(
                        'pago por servicio',
                        style: TextStyle(
                          fontSize: 10,
                          color: ColoresApp.grisOscuro,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                servicio['titulo']?.toString() ?? 'Solicitud',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                categoria,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.verdeAzulado,
                ),
              ),
              if ((servicio['descripcion']?.toString() ?? '')
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  servicio['descripcion'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ColoresApp.grisOscuro,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: ColoresApp.verdeAzulado,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${servicio['ciudad'] ?? ''} · ${servicio['sector'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ColoresApp.grisOscuro,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: ColoresApp.verdeAzulado,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _fecha(servicio['fechaServicio']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ColoresApp.grisOscuro,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (estado == 'En Proceso' && finalizacionSolicitada) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        size: 16,
                        color: Color(0xFF92400E),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _modoPrestador
                              ? 'Esperando confirmación del solicitante.'
                              : 'El prestador solicitó confirmar la finalización.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (estado == 'Cancelada' &&
                  (servicio['motivoCancelacion']?.toString() ?? '')
                      .trim()
                      .isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE8E6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF87171)),
                  ),
                  child: Text(
                    'Cancelado: ${servicio['motivoCancelacion']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFC5221F),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _cargando ? null : () => _abrirDetalle(servicio),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Ver servicio'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColoresApp.verdeAzulado,
                  side: const BorderSide(color: ColoresApp.verdeAzulado),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoVacio() {
    final conFiltros = _tieneFiltrosActivos;

    return TarjetaHelpi(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: ColoresApp.verdeMenta,
                shape: BoxShape.circle,
              ),
              child: Icon(
                conFiltros
                    ? Icons.search_off_rounded
                    : Icons.work_outline_rounded,
                size: 32,
                color: ColoresApp.verdeAzulado,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              conFiltros
                  ? 'No hay resultados para estos filtros'
                  : 'No tienes servicios',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              conFiltros
                  ? 'Ningún servicio coincide con la combinación de estado, categoría o prefijo de título seleccionada.'
                  : (_modoPrestador
                        ? 'Cuando aceptes servicios en la comunidad aparecerán en este espacio.'
                        : 'Las solicitudes que publiques para recibir ayuda aparecerán aquí.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresApp.grisOscuro),
            ),
            if (conFiltros) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _limpiarFiltros,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _modoPrestador ? 'Mis servicios' : 'Mis solicitudes',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Historial separado por tu participación en cada servicio.',
                    style: TextStyle(
                      fontSize: 13,
                      color: ColoresApp.grisOscuro,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: (_cargando || _cargandoMas) ? null : () => _cargar(),
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh, color: ColoresApp.verdeAzulado),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _selectorModo(),
        const SizedBox(height: 16),
        _panelFiltros(),
        const SizedBox(height: 20),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TarjetaHelpi(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: ColoresApp.coral),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (_requiereAceptarTerminos)
                        FilledButton.icon(
                          onPressed: (_cargando || _cargandoMas)
                              ? null
                              : () async {
                                  final perfil = await RepositorioPerfil()
                                      .leer();
                                  if (!context.mounted) return;
                                  final perfilActualizado =
                                      await Navigator.of(
                                        context,
                                      ).push<Map<String, dynamic>>(
                                        MaterialPageRoute<Map<String, dynamic>>(
                                          builder: (_) => PantallaTerminos(
                                            modo: ModoTerminos.obligatorio,
                                            perfil: perfil,
                                            retornarAlAceptar: true,
                                          ),
                                        ),
                                      );

                                  if (!mounted) return;
                                  if (perfilActualizado != null) {
                                    widget.alActualizarPerfil?.call(
                                      perfilActualizado,
                                    );
                                    await _cargar();
                                  }
                                },
                          icon: const Icon(Icons.gavel_rounded, size: 18),
                          label: const Text('Revisar y aceptar términos'),
                        ),
                      TextButton.icon(
                        onPressed: (_cargando || _cargandoMas)
                            ? null
                            : () => _cargar(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (!_cargando && _error == null && _servicios.isEmpty) _estadoVacio(),
        ..._servicios.map(_tarjeta),
        if (_cargando || _cargandoMas)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_cargando &&
            !_cargandoMas &&
            _cursor != null &&
            _error == null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _cargar(mas: true),
            icon: const Icon(Icons.expand_more_rounded),
            label: const Text('Cargar más'),
          ),
        ],
      ],
    );
  }
}
