import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/servicios/cliente_api.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../solicitudes/datos/repositorio_solicitudes.dart';
import 'pantalla_elegir_ubicacion.dart';

class VistaPrestador extends StatefulWidget {
  const VistaPrestador({
    super.key,
    required this.nombre,
    this.ciudad = 'Riobamba',
    this.sector = '',
    this.latitud,
    this.longitud,
  });

  final String nombre;
  final String ciudad;
  final String sector;
  final double? latitud;
  final double? longitud;

  @override
  State<VistaPrestador> createState() => _EstadoVistaPrestador();
}

class _EstadoVistaPrestador extends State<VistaPrestador> {
  final _repositorio = RepositorioSolicitudes();
  final _api = ClienteApi();
  final _busqueda = TextEditingController();

  final List<Map<String, dynamic>> _solicitudes = [];

  static const _categorias = [
    'Todas',
    'Soporte técnico',
    'Tutorías',
    'Reparaciones',
    'Hogar',
    'Mascotas',
    'Mudanzas',
  ];

  String _categoria = 'Todas';
  String _orden = 'Recientes';
  int _radio = 5;

  late String _ciudad;
  late String _sector;
  double? _latitud;
  double? _longitud;

  String? _cursor;
  String? _error;

  bool _cargando = false;
  bool _ocupada = false;
  bool _mostrarMapa = false;
  int _versionConsulta = 0;

  bool get _bloqueada => _cargando || _ocupada;

  bool get _tienePunto => _latitud != null && _longitud != null;

  @override
  void initState() {
    super.initState();
    _copiarUbicacion();
    _cargar();
  }

  void _copiarUbicacion() {
    _ciudad = widget.ciudad;
    _sector = widget.sector;
    _latitud = widget.latitud;
    _longitud = widget.longitud;
  }

  @override
  void didUpdateWidget(covariant VistaPrestador oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.ciudad != widget.ciudad ||
        oldWidget.sector != widget.sector ||
        oldWidget.latitud != widget.latitud ||
        oldWidget.longitud != widget.longitud) {
      _copiarUbicacion();
      _cargar();
    }
  }

  Future<void> _cargar({bool mas = false}) async {
    final version = ++_versionConsulta;

    setState(() {
      _cargando = true;
      _error = null;

      if (!mas) {
        _solicitudes.clear();
        _cursor = null;
      }
    });

    try {
      final textoBusqueda = _busqueda.text.trim();
      final pagina = await _repositorio.listar({
        'ciudad': _ciudad,
        if (_categoria != 'Todas') 'categoria': _categoria,
        if (textoBusqueda.isNotEmpty) 'busqueda': textoBusqueda,
        if (_tienePunto) ...{
          'latitud': _latitud.toString(),
          'longitud': _longitud.toString(),
          'radio': _radio.toString(),
        },
        if (mas && _cursor != null) 'cursor': _cursor!,
      });

      if (!mounted || version != _versionConsulta) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;

      setState(() {
        final ids = _solicitudes.map((s) => s['id']).toSet();

        _solicitudes.addAll(
          pagina.datos.where(
            (s) => s['solicitanteUid'] != uid && ids.add(s['id']),
          ),
        );

        _cursor = pagina.cursor;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || version != _versionConsulta) return;

      setState(() {
        _error = _mensajeError(error);
        _cargando = false;
      });
    }
  }

  String _mensajeError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _elegirZona() async {
    final resultado = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => PantallaElegirUbicacion(
          ciudad: _ciudad,
          sector: _sector,
          latitud: _latitud,
          longitud: _longitud,
        ),
      ),
    );

    if (resultado == null || !mounted) return;

    final latitud = double.tryParse(resultado['latitud'] ?? '');
    final longitud = double.tryParse(resultado['longitud'] ?? '');
    final ciudad = resultado['ciudad']?.trim() ?? '';

    if (latitud == null || longitud == null || ciudad.isEmpty) {
      aviso(context, 'Selecciona un punto y una ciudad.');
      return;
    }

    setState(() {
      _ciudad = ciudad;
      _sector = resultado['sector']?.trim() ?? '';
      _latitud = latitud;
      _longitud = longitud;
    });

    await _cargar();
  }

  List<Map<String, dynamic>> get _resultados {
    final texto = _busqueda.text.trim().toLowerCase();

    final resultados = _solicitudes.where((s) {
      final contenido = [
        s['titulo'],
        s['descripcion'],
        s['categoria'],
        s['sector'],
      ].join(' ').toLowerCase();

      return contenido.contains(texto);
    }).toList();

    resultados.sort((a, b) {
      if (_orden == 'Cercanas') {
        final distanciaA = (a['distanciaKm'] as num?)?.toDouble();
        final distanciaB = (b['distanciaKm'] as num?)?.toDouble();

        return (distanciaA ?? double.infinity).compareTo(
          distanciaB ?? double.infinity,
        );
      }

      if (_orden == 'Mayor monto') {
        return ((b['montoCentavos'] as num?) ?? 0).compareTo(
          (a['montoCentavos'] as num?) ?? 0,
        );
      }

      return '${b['creada'] ?? ''}'.compareTo('${a['creada'] ?? ''}');
    });

    return resultados;
  }

  String _fecha(dynamic valor) {
    final fecha = DateTime.tryParse('$valor')?.toLocal();

    if (fecha == null) return 'Sin fecha';

    String dos(int numero) => numero.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  String _monto(Map<String, dynamic> solicitud) {
    final centavos = (solicitud['montoCentavos'] as num?) ?? 0;
    return 'USD ${(centavos / 100).toStringAsFixed(2)}';
  }

  LatLng? _puntoSolicitud(Map<String, dynamic> solicitud) {
    final ubicacion = solicitud['ubicacion'];

    if (ubicacion is! Map) return null;

    final latitud = ubicacion['latitud'];
    final longitud = ubicacion['longitud'];

    if (latitud is! num || longitud is! num) return null;

    return LatLng(latitud.toDouble(), longitud.toDouble());
  }

  Future<void> _verPerfil(Map<String, dynamic> solicitud) async {
    if (_ocupada) return;

    final uid = solicitud['solicitanteUid']?.toString();

    if (uid == null || uid.isEmpty) {
      aviso(context, 'No se encontró el solicitante.');
      return;
    }

    setState(() {
      _ocupada = true;
    });

    try {
      final respuesta = await _api.enviar(
        'GET',
        '/perfiles/${Uri.encodeComponent(uid)}',
      );

      final datos = respuesta['datos'];

      if (datos is! Map) {
        throw Exception('No se pudo interpretar el perfil.');
      }

      if (!mounted) return;

      final total = (datos['totalCalificaciones'] as num?) ?? 0;
      final promedio = datos['promedio'];

      await showDialog<void>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: Text('${datos['nombre'] ?? 'Solicitante'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${datos['presentacion'] ?? ''}'),
                const SizedBox(height: 16),
                Text(
                  total > 0 && promedio is num
                      ? 'Calificación: ${promedio.toStringAsFixed(1)}/5 '
                            '($total reseñas)'
                      : 'Todavía no tiene calificaciones.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogo),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) aviso(context, _mensajeError(error));
    } finally {
      if (mounted) {
        setState(() {
          _ocupada = false;
        });
      }
    }
  }

  Future<void> _aceptar(Map<String, dynamic> solicitud) async {
    if (_bloqueada) return;

    setState(() {
      _ocupada = true;
    });

    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('Aceptar solicitud'),
          content: Text(
            '${solicitud['titulo']}\n\n'
            'Fecha: ${_fecha(solicitud['fechaServicio'])}\n'
            'Monto ofrecido: ${_monto(solicitud)}\n\n'
            '¿Quieres aceptar este servicio?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogo, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogo, true),
              child: const Text('Aceptar servicio'),
            ),
          ],
        ),
      );

      if (confirmar != true || !mounted) return;

      // El servidor valida el rol y evita la doble aceptación.
      await _repositorio.accion(solicitud['id'].toString(), 'aceptar');

      if (!mounted) return;

      aviso(
        context,
        'Servicio aceptado. Puedes verlo en Mis servicios como prestador.',
      );

      await _cargar();
    } catch (error) {
      if (!mounted) return;

      aviso(context, _mensajeError(error));

      // Actualiza por si otra persona ya aceptó la solicitud.
      await _cargar();
    } finally {
      if (mounted) {
        setState(() {
          _ocupada = false;
        });
      }
    }
  }

  Future<void> _ocultar(Map<String, dynamic> solicitud) async {
    if (_bloqueada) return;

    setState(() {
      _ocupada = true;
    });

    try {
      await _repositorio.accion(solicitud['id'].toString(), 'ocultar');

      if (!mounted) return;

      setState(() {
        _solicitudes.removeWhere((s) => s['id'] == solicitud['id']);
      });

      aviso(context, 'Solicitud ocultada de tu búsqueda.');
    } catch (error) {
      if (mounted) aviso(context, _mensajeError(error));
    } finally {
      if (mounted) {
        setState(() {
          _ocupada = false;
        });
      }
    }
  }

  void _verDetalle(Map<String, dynamic> solicitud) {
    showDialog<void>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('${solicitud['titulo']}'),
        content: SingleChildScrollView(
          child: Text(
            '${solicitud['descripcion']}\n\n'
            'Categoría: ${solicitud['categoria']}\n'
            'Lugar: ${solicitud['ciudad']} · ${solicitud['sector']}\n'
            'Fecha: ${_fecha(solicitud['fechaServicio'])}\n'
            'Horario: ${solicitud['horario']}\n'
            'Monto: ${_monto(solicitud)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _banner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/imagenes/fondo_prestador.jpeg',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xF215324F),
                    Color(0xCC15324F),
                    Color(0x8015324F),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONECTA, AYUDA Y CRECE',
                  style: TextStyle(
                    color: ColoresApp.verdeMenta,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.nombre.trim().isEmpty
                      ? 'Tus habilidades pueden ayudar.'
                      : '¡Hola, ${widget.nombre.trim().split(' ').first}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Encuentra solicitudes en $_ciudad '
                  'y comparte lo que sabes hacer.',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> solicitud) {
    final distancia = solicitud['distanciaKm'];

    return TarjetaHelpi(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${solicitud['titulo']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('${solicitud['categoria']}'),
          const SizedBox(height: 12),
          Text(
            '${solicitud['descripcion']}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text('${solicitud['ciudad']} · ${solicitud['sector']}'),
          if (distancia is num)
            Text(
              '${distancia.toStringAsFixed(1)} km en línea recta '
              'desde tu punto de búsqueda',
            ),
          const SizedBox(height: 8),
          Text(_fecha(solicitud['fechaServicio'])),
          Text('${solicitud['horario']}'),
          const SizedBox(height: 12),
          Text(
            _monto(solicitud),
            style: const TextStyle(
              color: ColoresApp.verdeAzulado,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _bloqueada ? null : () => _verDetalle(solicitud),
                child: const Text('Ver detalle'),
              ),
              TextButton(
                onPressed: _bloqueada ? null : () => _verPerfil(solicitud),
                child: const Text('Ver solicitante'),
              ),
              TextButton(
                onPressed: _bloqueada ? null : () => _ocultar(solicitud),
                child: const Text('Ocultar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _bloqueada ? null : () => _aceptar(solicitud),
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Aceptar servicio'),
          ),
        ],
      ),
    );
  }

  Widget _mapa(List<Map<String, dynamic>> resultados) {
    final puntos = resultados
        .where((solicitud) => _puntoSolicitud(solicitud) != null)
        .toList();

    final centro = _tienePunto
        ? LatLng(_latitud!, _longitud!)
        : puntos.isNotEmpty
        ? _puntoSolicitud(puntos.first)!
        : null;

    if (centro == null) {
      return const Text(
        'Selecciona una zona de búsqueda para centrar el mapa.',
      );
    }

    return SizedBox(
      height: 320,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GoogleMap(
          key: ValueKey('${centro.latitude}:${centro.longitude}'),
          initialCameraPosition: CameraPosition(target: centro, zoom: 13),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          markers: {
            if (_tienePunto)
              Marker(
                markerId: const MarkerId('zona_busqueda'),
                position: LatLng(_latitud!, _longitud!),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
                infoWindow: const InfoWindow(title: 'Tu punto de búsqueda'),
              ),
            ...puntos.map(
              (solicitud) => Marker(
                markerId: MarkerId(solicitud['id'].toString()),
                position: _puntoSolicitud(solicitud)!,
                infoWindow: InfoWindow(
                  title: '${solicitud['titulo']}',
                  snippet: _monto(solicitud),
                  onTap: () => _verDetalle(solicitud),
                ),
              ),
            ),
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _versionConsulta++;
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _banner(),
        const SizedBox(height: 24),
        Text(
          'Solicitudes disponibles',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _bloqueada ? null : _elegirZona,
          icon: const Icon(Icons.location_on_outlined),
          label: Text(_sector.isEmpty ? _ciudad : '$_ciudad · $_sector'),
        ),
        if (!_tienePunto) ...[
          const SizedBox(height: 8),
          const Text(
            'Selecciona un punto para activar el filtro por distancia.',
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _busqueda,
          decoration: InputDecoration(
            labelText: 'Buscar por título',
            hintText: 'Ej. Reparación, Tutoría…',
            helperText: 'Búsqueda por prefijo del título (pulsa Enter o la lupa para buscar en el servidor).',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busqueda.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() => _busqueda.clear());
                      _cargar();
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _cargar(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: _categoria,
              items: _categorias.map((categoria) {
                return DropdownMenuItem(
                  value: categoria,
                  child: Text(categoria),
                );
              }).toList(),
              onChanged: _bloqueada
                  ? null
                  : (valor) {
                      if (valor == null) return;
                      setState(() => _categoria = valor);
                      _cargar();
                    },
            ),
            DropdownButton<int>(
              value: _radio,
              items: [2, 5, 10, 25, 50, 100].map((radio) {
                return DropdownMenuItem(
                  value: radio,
                  child: Text('Hasta $radio km'),
                );
              }).toList(),
              onChanged: _bloqueada || !_tienePunto
                  ? null
                  : (valor) {
                      if (valor == null) return;
                      setState(() => _radio = valor);
                      _cargar();
                    },
            ),
            DropdownButton<String>(
              value: _orden,
              items: ['Recientes', 'Cercanas', 'Mayor monto'].map((orden) {
                return DropdownMenuItem(
                  value: orden,
                  enabled: orden != 'Cercanas' || _tienePunto,
                  child: Text(orden),
                );
              }).toList(),
              onChanged: _bloqueada
                  ? null
                  : (valor) {
                      if (valor != null) setState(() => _orden = valor);
                    },
            ),
            OutlinedButton.icon(
              onPressed: _bloqueada ? null : () => _cargar(),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar mapa'),
          value: _mostrarMapa,
          onChanged: (valor) => setState(() => _mostrarMapa = valor),
        ),
        if (_mostrarMapa) ...[_mapa(resultados), const SizedBox(height: 20)],
        Text('${resultados.length} solicitudes cargadas coinciden'),
        const SizedBox(height: 16),
        if (_error != null) ...[
          TarjetaHelpi(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_error!),
                TextButton(
                  onPressed: _bloqueada
                      ? null
                      : () => _cargar(mas: _solicitudes.isNotEmpty),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_ocupada) const LinearProgressIndicator(),
        if (!_cargando && _error == null && resultados.isEmpty)
          const TarjetaHelpi(
            child: Text(
              'No hay solicitudes disponibles en los datos cargados '
              'para estos filtros. Prueba otra zona o categoría. '
              'Tus propias publicaciones no aparecen aquí.',
            ),
          ),
        ...resultados.map(
          (solicitud) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _tarjeta(solicitud),
          ),
        ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_cursor != null && _error == null)
          OutlinedButton(
            onPressed: _bloqueada ? null : () => _cargar(mas: true),
            child: const Text('Cargar más solicitudes'),
          ),
      ],
    );
  }
}
