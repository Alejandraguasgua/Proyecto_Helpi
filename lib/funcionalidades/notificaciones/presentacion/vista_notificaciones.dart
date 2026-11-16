import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../solicitudes/presentacion/pantalla_detalle_servicio.dart';
import '../datos/repositorio_notificaciones.dart';

class VistaNotificaciones extends StatefulWidget {
  const VistaNotificaciones({super.key});

  @override
  State<VistaNotificaciones> createState() => _EstadoVistaNotificaciones();
}

class _EstadoVistaNotificaciones extends State<VistaNotificaciones> {
  final _repositorio = RepositorioNotificaciones();
  final List<Map<String, dynamic>> _notificaciones = [];

  int _idPeticionActiva = 0;
  bool _cargandoInicial = false;
  bool _cargandoMas = false;
  bool _abriendoAviso = false;
  String? _idAbriendo;
  String? _error;
  String? _cursor;

  int get _sinLeer =>
      _notificaciones.where((item) => item['leida'] != true).length;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool mas = false}) async {
    if (mas) {
      if (_cargandoInicial || _cargandoMas || _cursor == null) return;
    }

    // Incrementa el token en cargas completas para descartar respuestas antiguas en vuelo
    final int idPeticion = mas ? _idPeticionActiva : ++_idPeticionActiva;
    final String? cursorConsulta = mas ? _cursor : null;

    setState(() {
      _error = null;
      if (mas) {
        _cargandoMas = true;
      } else {
        _cargandoInicial = true;
      }
    });

    try {
      final pagina = await _repositorio.listar(cursor: cursorConsulta);

      if (!mounted || idPeticion != _idPeticionActiva) return;

      setState(() {
        if (!mas) {
          _notificaciones.clear();
        }

        final idsExistentes = _notificaciones
            .map((item) => item['id']?.toString())
            .whereType<String>()
            .toSet();

        for (final avisoItem in pagina.datos) {
          final id = avisoItem['id']?.toString();
          if (id != null && idsExistentes.add(id)) {
            _notificaciones.add(avisoItem);
          }
        }

        _cursor = pagina.cursor;
        _cargandoInicial = false;
        _cargandoMas = false;
      });
    } catch (error) {
      if (!mounted || idPeticion != _idPeticionActiva) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _cargandoInicial = false;
        _cargandoMas = false;
      });
    }
  }

  String _formatearFechaLocal(dynamic valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();

    if (fecha == null) return 'Fecha no disponible';

    String dos(int n) => n.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  IconData _iconoPorTipo(String? tipo) {
    switch (tipo) {
      case 'solicitud_aceptada':
        return Icons.handshake_outlined;
      case 'servicio_iniciado':
        return Icons.play_circle_outline_rounded;
      case 'finalizacion_solicitada':
        return Icons.fact_check_outlined;
      case 'servicio_completado':
        return Icons.verified_outlined;
      case 'servicio_cancelado':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _tituloFallback(Map<String, dynamic> item) {
    final titulo = (item['titulo'] ?? '').toString().trim();
    if (titulo.isNotEmpty) return titulo;

    switch (item['tipo']?.toString()) {
      case 'solicitud_aceptada':
        return 'Solicitud aceptada';
      case 'servicio_iniciado':
        return 'Servicio iniciado';
      case 'finalizacion_solicitada':
        return 'Confirmación de finalización pendiente';
      case 'servicio_completado':
        return 'Servicio completado';
      case 'servicio_cancelado':
        return 'Servicio cancelado';
      default:
        return 'Aviso del servicio';
    }
  }

  Future<void> _abrirNotificacion(Map<String, dynamic> item) async {
    if (_abriendoAviso) return;

    final idNotificacion = (item['id'] ?? '').toString().trim();
    final solicitudId = (item['solicitudId'] ?? '').toString().trim();

    if (solicitudId.isEmpty) {
      aviso(
        context,
        'Esta notificación no tiene un servicio válido relacionado.',
      );
      return;
    }

    setState(() {
      _abriendoAviso = true;
      _idAbriendo = idNotificacion;
    });

    try {
      if (item['leida'] != true && idNotificacion.isNotEmpty) {
        final actualizada = await _repositorio.marcarLeida(idNotificacion);

        if (!mounted) return;

        setState(() {
          final indice = _notificaciones.indexWhere(
            (elemento) => elemento['id']?.toString() == idNotificacion,
          );
          if (indice != -1) {
            _notificaciones[indice] = {
              ..._notificaciones[indice],
              ...?actualizada,
              'leida': true,
              'fechaLectura':
                  actualizada?['fechaLectura'] ??
                  _notificaciones[indice]['fechaLectura'] ??
                  DateTime.now().toIso8601String(),
            };
          }
        });
      }

      if (!mounted) return;

      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PantallaDetalleServicio(id: solicitudId),
        ),
      );

      if (!mounted) return;

      // Actualiza la lista al regresar del detalle del servicio
      await _cargar();
    } catch (error) {
      if (!mounted) return;
      final mensaje = error.toString().replaceFirst('Exception: ', '');
      aviso(
        context,
        mensaje.isNotEmpty
            ? mensaje
            : 'No se pudo abrir la notificación. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _abriendoAviso = false;
          _idAbriendo = null;
        });
      }
    }
  }

  Widget _badgeLectura(bool leida) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: leida ? const Color(0xFFEDF2F7) : const Color(0xFFFCE8E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!leida) ...[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: ColoresApp.coral,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            leida ? 'Leída' : 'Sin leer',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: leida ? ColoresApp.grisOscuro : ColoresApp.coral,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaNotificacion(Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    final leida = item['leida'] == true;
    final tipo = item['tipo']?.toString();
    final titulo = _tituloFallback(item);
    final mensaje = (item['mensaje'] ?? '').toString().trim();
    final servicioTitulo = (item['servicioTitulo'] ?? '').toString().trim();
    final fechaCreacion = _formatearFechaLocal(item['creada']);
    final fechaLecturaRaw = item['fechaLectura'];
    final abriendoEsta = _abriendoAviso && _idAbriendo == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: leida ? ColoresApp.blanco : const Color(0xFFF8FCFB),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: leida ? const Color(0xFFE4EBF0) : ColoresApp.verdeAzulado,
            width: leida ? 1 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0B15324F),
              blurRadius: 16,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _abriendoAviso ? null : () => _abrirNotificacion(item),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: leida
                              ? const Color(0xFFEDF2F7)
                              : ColoresApp.verdeMenta,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _iconoPorTipo(tipo),
                          size: 22,
                          color: leida
                              ? ColoresApp.grisOscuro
                              : ColoresApp.verdeAzulado,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _badgeLectura(leida),
                                Text(
                                  fechaCreacion,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ColoresApp.grisOscuro,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              titulo,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: leida
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: ColoresApp.azulMarino,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (abriendoEsta)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(left: 8, top: 4),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: ColoresApp.verdeAzulado,
                          ),
                        ),
                    ],
                  ),
                  if (mensaje.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      mensaje,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: leida ? FontWeight.w400 : FontWeight.w500,
                        color: ColoresApp.grisOscuro,
                      ),
                    ),
                  ],
                  if (servicioTitulo.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.work_outline_rounded,
                          size: 15,
                          color: ColoresApp.verdeAzulado,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            servicioTitulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.verdeAzulado,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (leida && fechaLecturaRaw != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Leída el ${_formatearFechaLocal(fechaLecturaRaw)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ColoresApp.grisOscuro,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _estadoVacio() {
    return TarjetaHelpi(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
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
                Icons.notifications_none_rounded,
                size: 32,
                color: ColoresApp.verdeAzulado,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes notificaciones',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando acepten, inicien, soliciten finalizar, completen o cancelen un servicio en el que participas, verás el aviso aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresApp.grisOscuro),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSinLeer = _sinLeer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificaciones',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _notificaciones.isEmpty
                      ? 'Avisos internos de tus solicitudes y servicios.'
                      : (totalSinLeer == 0
                            ? 'Todas tus notificaciones están leídas.'
                            : '$totalSinLeer ${totalSinLeer == 1 ? 'notificación sin leer' : 'notificaciones sin leer'}'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: totalSinLeer > 0
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: totalSinLeer > 0
                        ? ColoresApp.verdeAzulado
                        : ColoresApp.grisOscuro,
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: (_cargandoInicial || _cargandoMas)
                  ? null
                  : () => _cargar(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualizar'),
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
        const SizedBox(height: 20),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TarjetaHelpi(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: ColoresApp.coral,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: ColoresApp.coral),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: (_cargandoInicial || _cargandoMas)
                          ? null
                          : () => _cargar(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_cargandoInicial && _notificaciones.isEmpty)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (!_cargandoInicial && _error == null && _notificaciones.isEmpty)
            _estadoVacio(),
          ..._notificaciones.map(_tarjetaNotificacion),
          if (_cargandoInicial && _notificaciones.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_cargandoMas)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_cargandoInicial &&
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
      ],
    );
  }
}
