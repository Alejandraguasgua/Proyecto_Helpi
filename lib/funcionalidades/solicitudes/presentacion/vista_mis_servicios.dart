import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../datos/repositorio_solicitudes.dart';
import 'pantalla_detalle_servicio.dart';

class VistaMisServicios extends StatefulWidget {
  const VistaMisServicios({super.key, required this.esPrestador});

  final bool esPrestador;

  @override
  State<VistaMisServicios> createState() => _EstadoVistaMisServicios();
}

class _EstadoVistaMisServicios extends State<VistaMisServicios> {
  final _repositorio = RepositorioSolicitudes();
  final List<Map<String, dynamic>> _servicios = [];

  static const _estados = [
    'Todas',
    'Publicada',
    'Aceptada',
    'En Proceso',
    'Completada',
    'Cancelada',
  ];

  late bool _modoPrestador;
  String _filtroEstado = 'Todas';

  bool _cargando = false;
  String? _error;
  String? _cursor;

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

  Future<void> _cargar({bool mas = false}) async {
    if (_cargando) return;

    final modoActual = _modoPrestador;
    final estadoActual = _filtroEstado;

    setState(() {
      _cargando = true;
      _error = null;

      if (!mas) {
        _servicios.clear();
        _cursor = null;
      }
    });

    try {
      final filtros = <String, String>{
        if (modoActual) 'aceptadas': 'true',
        if (!modoActual) 'mias': 'true',
        if (estadoActual != 'Todas') 'estado': estadoActual,
        if (mas && _cursor != null) 'cursor': _cursor!,
      };

      final pagina = await _repositorio.listar(filtros);

      if (!mounted) return;

      // Descartar si el usuario cambió de modo o filtro mientras se esperaba la red
      if (_modoPrestador != modoActual || _filtroEstado != estadoActual) {
        return;
      }

      setState(() {
        final ids = _servicios.map((s) => s['id']).toSet();

        _servicios.addAll(pagina.datos.where((s) => ids.add(s['id'])));

        _cursor = pagina.cursor;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;

      if (_modoPrestador != modoActual || _filtroEstado != estadoActual) {
        return;
      }

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _cargando = false;
      });
    }
  }

  String _fecha(dynamic valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();

    if (fecha == null) return 'Sin fecha';

    String dos(int n) => n.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} ${dos(fecha.hour)}:${dos(fecha.minute)}';
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
                    _filtroEstado = 'Todas';
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
                    _filtroEstado = 'Todas';
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: ColoresApp.verdeAzulado,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${servicio['ciudad'] ?? ''} · ${servicio['sector'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ColoresApp.grisOscuro,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
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
              child: const Icon(
                Icons.work_outline_rounded,
                size: 32,
                color: ColoresApp.verdeAzulado,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay actividades aquí',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _filtroEstado != 'Todas'
                  ? 'No hay servicios con estado "$_filtroEstado".'
                  : (_modoPrestador
                        ? 'Cuando aceptes servicios en la comunidad aparecerán en este espacio.'
                        : 'Las solicitudes que publiques para recibir ayuda aparecerán aquí.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresApp.grisOscuro),
            ),
            if (_filtroEstado != 'Todas') ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: () {
                  setState(() => _filtroEstado = 'Todas');
                  _cargar();
                },
                child: const Text('Ver todos los estados'),
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
              onPressed: _cargando ? null : () => _cargar(),
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh, color: ColoresApp.verdeAzulado),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _selectorModo(),
        const SizedBox(height: 14),
        _filtrosEstado(),
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
                  TextButton.icon(
                    onPressed: _cargando ? null : () => _cargar(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        if (!_cargando && _error == null && _servicios.isEmpty) _estadoVacio(),
        ..._servicios.map(_tarjeta),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_cargando && _cursor != null && _error == null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _cargar(mas: true),
            child: const Text('Cargar más'),
          ),
        ],
      ],
    );
  }
}
