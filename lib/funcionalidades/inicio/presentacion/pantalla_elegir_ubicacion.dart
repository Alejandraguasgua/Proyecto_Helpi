import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';

class _CoordenadaMapa {
  const _CoordenadaMapa({required this.latitud, required this.longitud});

  final double latitud;
  final double longitud;

  // Mapbox y GeoJSON reciben primero la longitud y luego la latitud.
  Point toMapboxPoint() => Point(coordinates: Position(longitud, latitud));

  List<double> toGeoJsonPosition() => [longitud, latitud];
}

class _ResultadoGeocodificacion {
  const _ResultadoGeocodificacion({
    required this.titulo,
    required this.subtitulo,
    required this.ciudad,
    required this.sector,
    required this.coordenada,
  });

  final String titulo;
  final String subtitulo;
  final String ciudad;
  final String sector;
  final _CoordenadaMapa coordenada;
}

enum _EstadoTokenMapbox { valido, ausente, privadoNoPermitido }

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
      _PantallaElegirUbicacionState();
}

class _PantallaElegirUbicacionState extends State<PantallaElegirUbicacion> {
  static const Map<String, _CoordenadaMapa> _centrosCiudades = {
    'Riobamba': _CoordenadaMapa(latitud: -1.6636, longitud: -78.6546),
    'Quito': _CoordenadaMapa(latitud: -0.1807, longitud: -78.4678),
    'Cuenca': _CoordenadaMapa(latitud: -2.9001, longitud: -79.0059),
  };

  static const String _idFuenteMarcador = 'helpi_ubicacion_source';
  static const String _idCapaHaloMarcador = 'helpi_ubicacion_halo';
  static const String _idCapaCentroMarcador = 'helpi_ubicacion_centro';
  static const String _idInteraccionTap = 'helpi_ubicacion_tap';

  late final TextEditingController _ciudad;
  late final TextEditingController _sector;
  late final TextEditingController _busquedaDireccion;
  late final ViewportController _controladorViewport;

  final http.Client _clienteHttp = http.Client();

  late _CoordenadaMapa _punto;
  MapboxMap? _mapa;

  int _intentoMapa = 0;
  bool _cargandoMapa = true;
  bool _estiloCargado = false;
  String? _errorMapa;

  bool _ajustarAlCentro = false;
  bool _buscandoDirecciones = false;
  String? _errorBusqueda;
  List<_ResultadoGeocodificacion> _sugerencias = const [];

  bool _solicitandoUbicacionActual = false;
  bool _esperandoUbicacionActual = false;
  _CoordenadaMapa? _puntoAntesDeUbicacion;
  String? _avisoUbicacionActual;
  Timer? _temporizadorUbicacion;
  Timer? _temporizadorCargaMapa;

  String _tokenPublico = '';
  _EstadoTokenMapbox _estadoToken = _EstadoTokenMapbox.ausente;

  @override
  void initState() {
    super.initState();
    _ciudad = TextEditingController(text: widget.ciudad);
    _sector = TextEditingController(text: widget.sector);
    _busquedaDireccion = TextEditingController();
    _controladorViewport = ViewportController();

    final _CoordenadaMapa inicialCiudad =
        _centrosCiudades[widget.ciudad.trim()] ?? _centrosCiudades['Riobamba']!;
    _punto = _CoordenadaMapa(
      latitud: widget.latitud ?? inicialCiudad.latitud,
      longitud: widget.longitud ?? inicialCiudad.longitud,
    );

    _cargandoMapa = false;
    if (dotenv.isInitialized) {
      _aplicarToken(dotenv.maybeGet('MAPBOX_ACCESS_TOKEN') ?? '');
    } else {
      unawaited(_cargarEnvMapboxSiFalta());
    }
  }

  void _aplicarToken(String valor) {
    final String token = valor.trim();
    if (token.startsWith('sk.')) {
      _tokenPublico = '';
      _estadoToken = _EstadoTokenMapbox.privadoNoPermitido;
      _cargandoMapa = false;
      return;
    }

    if (token.isEmpty ||
        token == 'PEGA_AQUI_MI_TOKEN_PUBLICO_PK' ||
        !token.startsWith('pk.') ||
        token.length <= 10) {
      _tokenPublico = '';
      _estadoToken = _EstadoTokenMapbox.ausente;
      _cargandoMapa = false;
      return;
    }

    _tokenPublico = token;
    _estadoToken = _EstadoTokenMapbox.valido;
    _cargandoMapa = true;
    MapboxOptions.setAccessToken(_tokenPublico);
    _iniciarTemporizadorCargaMapa();
  }

  Future<void> _cargarEnvMapboxSiFalta() async {
    try {
      await dotenv.load(fileName: '.env.mapbox', isOptional: true);
    } catch (_) {
      return;
    }
    if (!mounted || !dotenv.isInitialized) return;
    setState(() {
      _aplicarToken(dotenv.maybeGet('MAPBOX_ACCESS_TOKEN') ?? '');
    });
  }

  @override
  void dispose() {
    _temporizadorUbicacion?.cancel();
    _temporizadorCargaMapa?.cancel();
    _clienteHttp.close();
    _controladorViewport.dispose();
    _ciudad.dispose();
    _sector.dispose();
    _busquedaDireccion.dispose();
    super.dispose();
  }

  void _iniciarTemporizadorCargaMapa() {
    _temporizadorCargaMapa?.cancel();
    _temporizadorCargaMapa = Timer(const Duration(seconds: 15), () {
      if (!mounted || _estiloCargado) return;
      setState(() {
        _cargandoMapa = false;
        _errorMapa = 'El mapa tardó demasiado en responder. Verifica tu conexión o el token de Mapbox.';
      });
    });
  }

  void _reintentarCargaMapa() {
    if (_estadoToken != _EstadoTokenMapbox.valido) return;
    setState(() {
      _intentoMapa += 1;
      _mapa = null;
      _estiloCargado = false;
      _cargandoMapa = true;
      _errorMapa = null;
    });
    _iniciarTemporizadorCargaMapa();
  }

  String _construirGeoJsonMarcador(_CoordenadaMapa coordenada) {
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': coordenada.toGeoJsonPosition(),
          },
          'properties': <String, dynamic>{},
        },
      ],
    });
  }

  void _alCrearMapa(MapboxMap mapa) {
    _mapa = mapa;
    try {
      mapa.removeInteraction(_idInteraccionTap);
    } catch (_) {}

    try {
      mapa.addInteraction(
        TapInteraction.onMap((MapContentGestureContext contexto) {
          if (!mounted) return;
          final num lat = contexto.point.coordinates.lat;
          final num lng = contexto.point.coordinates.lng;
          _alSeleccionarPuntoManual(
            _CoordenadaMapa(latitud: lat.toDouble(), longitud: lng.toDouble()),
            moverCamara: false,
          );
        }),
        interactionID: _idInteraccionTap,
      );
    } catch (_) {}
  }

  Future<void> _alCargarEstilo(StyleLoadedEventData _) async {
    _temporizadorCargaMapa?.cancel();
    if (!mounted) return;

    final MapboxMap? mapa = _mapa;
    if (mapa == null) return;

    try {
      final String geoJson = _construirGeoJsonMarcador(_punto);
      final bool existeFuente = await mapa.styleSourceExists(_idFuenteMarcador);
      if (!existeFuente) {
        await mapa.addSource(
          GeoJsonSource(id: _idFuenteMarcador, data: geoJson),
        );
      } else {
        await mapa.setStyleSourceProperty(_idFuenteMarcador, 'data', geoJson);
      }

      if (!await mapa.styleLayerExists(_idCapaHaloMarcador)) {
        await mapa.addLayer(
          CircleLayer(
            id: _idCapaHaloMarcador,
            sourceId: _idFuenteMarcador,
            circleRadius: 15.0,
            circleColor: ColoresApp.verdeAzulado.toARGB32(),
            circleOpacity: 0.22,
            circleStrokeWidth: 2.0,
            circleStrokeColor: ColoresApp.blanco.toARGB32(),
          ),
        );
      }

      if (!await mapa.styleLayerExists(_idCapaCentroMarcador)) {
        await mapa.addLayer(
          CircleLayer(
            id: _idCapaCentroMarcador,
            sourceId: _idFuenteMarcador,
            circleRadius: 7.5,
            circleColor: ColoresApp.azulMarino.toARGB32(),
            circleStrokeWidth: 2.5,
            circleStrokeColor: ColoresApp.blanco.toARGB32(),
          ),
        );
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _estiloCargado = true;
      _cargandoMapa = false;
      _errorMapa = null;
    });
  }

  void _alCargarMapa(MapLoadedEventData _) {
    _temporizadorCargaMapa?.cancel();
    if (!mounted) return;
    if (_cargandoMapa) {
      setState(() {
        _cargandoMapa = false;
      });
    }
  }

  void _alFallarCargaMapa(MapLoadingErrorEventData datosError) {
    if (!mounted) return;
    if (datosError.type == MapLoadErrorType.STYLE && !_estiloCargado) {
      _temporizadorCargaMapa?.cancel();
      setState(() {
        _cargandoMapa = false;
        _errorMapa = 'No se pudo cargar el estilo de Mapbox. Verifica que el token público sea válido y tenga conexión.';
      });
    }
  }

  Future<void> _actualizarMarcador(_CoordenadaMapa coordenada) async {
    final MapboxMap? mapa = _mapa;
    if (mapa == null || !_estiloCargado) return;
    try {
      final bool existe = await mapa.styleSourceExists(_idFuenteMarcador);
      if (!existe) return;
      await mapa.setStyleSourceProperty(
        _idFuenteMarcador,
        'data',
        _construirGeoJsonMarcador(coordenada),
      );
    } catch (_) {}
  }

  void _moverCamaraA(
    _CoordenadaMapa coordenada, {
    double zoom = 14.5,
    int duracionMs = 550,
  }) {
    if (_estadoToken != _EstadoTokenMapbox.valido) return;
    _controladorViewport.moveTo(
      CameraViewportState(center: coordenada.toMapboxPoint(), zoom: zoom),
      transition: FlyViewportTransition(
        duration: Duration(milliseconds: duracionMs),
      ),
    );
  }

  Future<void> _alDetenerMapa(MapIdleEventData _) async {
    final MapboxMap? mapa = _mapa;
    if (mapa == null || !mounted) return;

    if (_esperandoUbicacionActual) {
      try {
        final CameraState estado = await mapa.getCameraState();
        if (!mounted) return;
        final double lat = estado.center.coordinates.lat.toDouble();
        final double lng = estado.center.coordinates.lng.toDouble();
        final _CoordenadaMapa? previo = _puntoAntesDeUbicacion;
        final bool seMovio =
            previo == null ||
            (lat - previo.latitud).abs() > 0.0001 ||
            (lng - previo.longitud).abs() > 0.0001;
        if (seMovio) {
          final _CoordenadaMapa nueva = _CoordenadaMapa(
            latitud: lat,
            longitud: lng,
          );
          _finalizarEsperaUbicacionActual(nueva);
        }
      } catch (_) {}
      return;
    }

    if (!_ajustarAlCentro) return;
    try {
      final CameraState estado = await mapa.getCameraState();
      if (!mounted) return;
      final _CoordenadaMapa centro = _CoordenadaMapa(
        latitud: estado.center.coordinates.lat.toDouble(),
        longitud: estado.center.coordinates.lng.toDouble(),
      );
      if ((centro.latitud - _punto.latitud).abs() < 0.00001 &&
          (centro.longitud - _punto.longitud).abs() < 0.00001) {
        return;
      }
      await _alSeleccionarPuntoManual(centro, moverCamara: false);
    } catch (_) {}
  }

  void _finalizarEsperaUbicacionActual(_CoordenadaMapa coordenada) {
    _temporizadorUbicacion?.cancel();
    if (!mounted) return;
    setState(() {
      _esperandoUbicacionActual = false;
      _solicitandoUbicacionActual = false;
      _avisoUbicacionActual = null;
      _punto = coordenada;
    });
    _actualizarMarcador(coordenada);
    _geocodificarInversa(coordenada);
  }

  Future<void> _alSeleccionarPuntoManual(
    _CoordenadaMapa coordenada, {
    bool moverCamara = false,
  }) async {
    setState(() {
      _punto = coordenada;
      _esperandoUbicacionActual = false;
      _solicitandoUbicacionActual = false;
      _avisoUbicacionActual = null;
      _sugerencias = const [];
    });
    await _actualizarMarcador(coordenada);
    if (moverCamara) {
      _moverCamaraA(coordenada, zoom: 15.0);
    }
    unawaited(_geocodificarInversa(coordenada));
  }

  void _seleccionarCiudadPredefinida(String nombreCiudad) {
    final _CoordenadaMapa? centro = _centrosCiudades[nombreCiudad];
    if (centro == null) return;
    setState(() {
      _ciudad.text = nombreCiudad;
      _punto = centro;
      _sugerencias = const [];
      _errorBusqueda = null;
      _avisoUbicacionActual = null;
    });
    _actualizarMarcador(centro);
    _moverCamaraA(centro, zoom: 14.0);
  }

  Future<void> _buscarDirecciones() async {
    final String consulta = _busquedaDireccion.text.trim();
    if (consulta.isEmpty) {
      setState(() {
        _errorBusqueda =
            'Escribe una dirección, barrio o referencia para buscar.';
        _sugerencias = const [];
      });
      return;
    }

    if (_estadoToken != _EstadoTokenMapbox.valido) {
      setState(() {
        _errorBusqueda = 'Configura un token público (pk.) en .env.mapbox para usar la búsqueda de direcciones.';
        _sugerencias = const [];
      });
      return;
    }

    setState(() {
      _buscandoDirecciones = true;
      _errorBusqueda = null;
    });

    try {
      final Uri url = Uri.https(
        'api.mapbox.com',
        '/search/geocode/v6/forward',
        {
          'q': consulta,
          'country': 'ec',
          'language': 'es',
          'limit': '5',
          'proximity': '${_punto.longitud},${_punto.latitud}',
          'access_token': _tokenPublico,
        },
      );

      final http.Response respuesta = await _clienteHttp
          .get(url)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
        setState(() {
          _buscandoDirecciones = false;
          _sugerencias = const [];
          _errorBusqueda = 'El token de Mapbox configurado no tiene permisos válidos para geocodificación.';
        });
        return;
      }

      if (respuesta.statusCode != 200) {
        setState(() {
          _buscandoDirecciones = false;
          _sugerencias = const [];
          _errorBusqueda = 'No se pudo buscar esa dirección en este momento. Intenta de nuevo.';
        });
        return;
      }

      final Object? decoded = jsonDecode(respuesta.body);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _buscandoDirecciones = false;
          _sugerencias = const [];
          _errorBusqueda = 'Respuesta inesperada al consultar direcciones.';
        });
        return;
      }

      final List<dynamic> features =
          (decoded['features'] as List<dynamic>?) ?? const [];
      final List<_ResultadoGeocodificacion> resultados = [];
      for (final dynamic item in features) {
        if (item is! Map<String, dynamic>) continue;
        final _ResultadoGeocodificacion? parsed =
            _parsearFeatureGeocodificacion(item);
        if (parsed != null) {
          resultados.add(parsed);
        }
      }

      setState(() {
        _buscandoDirecciones = false;
        _sugerencias = resultados;
        _errorBusqueda = resultados.isEmpty
            ? 'No encontramos coincidencias para "$consulta".'
            : null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _buscandoDirecciones = false;
        _errorBusqueda = 'La búsqueda tardó demasiado. Verifica tu conexión e inténtalo de nuevo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _buscandoDirecciones = false;
        _errorBusqueda = 'No pudimos conectar con el servicio de búsqueda. Puedes elegir el punto directamente en el mapa.';
      });
    }
  }

  Future<void> _geocodificarInversa(_CoordenadaMapa coordenada) async {
    if (_estadoToken != _EstadoTokenMapbox.valido) return;
    try {
      final Uri url = Uri.https(
        'api.mapbox.com',
        '/search/geocode/v6/reverse',
        {
          'longitude': coordenada.longitud.toStringAsFixed(6),
          'latitude': coordenada.latitud.toStringAsFixed(6),
          'country': 'ec',
          'language': 'es',
          'limit': '1',
          'access_token': _tokenPublico,
        },
      );

      final http.Response respuesta = await _clienteHttp
          .get(url)
          .timeout(const Duration(seconds: 8));
      if (!mounted || respuesta.statusCode != 200) return;

      final Object? decoded = jsonDecode(respuesta.body);
      if (decoded is! Map<String, dynamic>) return;
      final List<dynamic> features =
          (decoded['features'] as List<dynamic>?) ?? const [];
      if (features.isEmpty || features.first is! Map<String, dynamic>) return;

      final _ResultadoGeocodificacion? resultado =
          _parsearFeatureGeocodificacion(
            features.first as Map<String, dynamic>,
          );
      if (resultado == null) return;

      setState(() {
        if (resultado.ciudad.isNotEmpty) {
          _ciudad.text = resultado.ciudad;
        }
        if (resultado.sector.isNotEmpty) {
          _sector.text = resultado.sector;
        }
      });
    } catch (_) {}
  }

  _ResultadoGeocodificacion? _parsearFeatureGeocodificacion(
    Map<String, dynamic> feature,
  ) {
    final Map<String, dynamic>? geometria =
        feature['geometry'] as Map<String, dynamic>?;
    final List<dynamic>? coords = geometria?['coordinates'] as List<dynamic>?;
    if (coords == null || coords.length < 2) return null;
    final num? lng = coords[0] as num?;
    final num? lat = coords[1] as num?;
    if (lat == null || lng == null) return null;

    final Map<String, dynamic> props =
        (feature['properties'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic>? contexto =
        props['context'] as Map<String, dynamic>?;

    String leerNombreContexto(String clave) {
      final Object? entrada = contexto?[clave];
      if (entrada is Map<String, dynamic>) {
        final Object? nombre = entrada['name'];
        if (nombre is String && nombre.trim().isNotEmpty) {
          return nombre.trim();
        }
      }
      return '';
    }

    final String titulo = ((props['name'] as String?) ?? '').trim();
    final String fullAddress =
        ((props['full_address'] as String?) ??
                (props['place_formatted'] as String?) ??
                '')
            .trim();

    String ciudadExtraida = leerNombreContexto('place');
    if (ciudadExtraida.isEmpty) {
      ciudadExtraida = leerNombreContexto('locality');
    }
    if (ciudadExtraida.isEmpty) {
      ciudadExtraida = leerNombreContexto('district');
    }
    if (ciudadExtraida.isEmpty) {
      ciudadExtraida = leerNombreContexto('region');
    }

    final String barrio = leerNombreContexto('neighborhood');
    final String localidad = leerNombreContexto('locality');
    String sectorExtraido = titulo;
    if (sectorExtraido.isEmpty || sectorExtraido == ciudadExtraida) {
      sectorExtraido = barrio.isNotEmpty ? barrio : localidad;
    }
    if (sectorExtraido.isEmpty && fullAddress.isNotEmpty) {
      sectorExtraido = fullAddress;
    }

    return _ResultadoGeocodificacion(
      titulo: titulo.isNotEmpty ? titulo : fullAddress,
      subtitulo: fullAddress,
      ciudad: ciudadExtraida,
      sector: sectorExtraido,
      coordenada: _CoordenadaMapa(
        latitud: lat.toDouble(),
        longitud: lng.toDouble(),
      ),
    );
  }

  void _aplicarResultadoBusqueda(_ResultadoGeocodificacion resultado) {
    FocusScope.of(context).unfocus();
    setState(() {
      _punto = resultado.coordenada;
      if (resultado.ciudad.isNotEmpty) {
        _ciudad.text = resultado.ciudad;
      }
      if (resultado.sector.isNotEmpty) {
        _sector.text = resultado.sector;
      }
      _busquedaDireccion.text = resultado.titulo;
      _sugerencias = const [];
      _errorBusqueda = null;
      _avisoUbicacionActual = null;
    });
    _actualizarMarcador(resultado.coordenada);
    _moverCamaraA(resultado.coordenada, zoom: 15.5);
  }

  Future<void> _usarUbicacionActual() async {
    if (_estadoToken != _EstadoTokenMapbox.valido) {
      aviso(
        context,
        'Necesitas un token público de Mapbox para activar la ubicación en el mapa.',
      );
      return;
    }

    final MapboxMap? mapa = _mapa;
    if (mapa == null || !_estiloCargado) {
      aviso(context, 'Espera un momento mientras termina de cargar el mapa.');
      return;
    }

    _temporizadorUbicacion?.cancel();
    setState(() {
      _solicitandoUbicacionActual = true;
      _esperandoUbicacionActual = true;
      _puntoAntesDeUbicacion = _punto;
      _avisoUbicacionActual = null;
    });

    try {
      await mapa.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _solicitandoUbicacionActual = false;
        _esperandoUbicacionActual = false;
        _avisoUbicacionActual = 'No pudimos acceder al permiso de ubicación. Puedes seleccionar un punto manualmente tocando el mapa.';
      });
      return;
    }

    _temporizadorUbicacion = Timer(const Duration(seconds: 10), () {
      if (!mounted || !_esperandoUbicacionActual) return;
      setState(() {
        _solicitandoUbicacionActual = false;
        _esperandoUbicacionActual = false;
        _avisoUbicacionActual = 'No se obtuvo tu ubicación a tiempo. Verifica los permisos del navegador o toca el mapa para elegir un punto.';
      });
    });

    _controladorViewport.moveTo(
      FollowPuckViewportState(
        zoom: 15.5,
        bearing: const FollowPuckViewportStateBearingConstant(0),
        pitch: 0,
      ),
      transition: FlyViewportTransition(
        duration: const Duration(milliseconds: 600),
      ),
      completion: (bool completado) async {
        if (!mounted || !_esperandoUbicacionActual) return;
        if (!completado) {
          _temporizadorUbicacion?.cancel();
          setState(() {
            _solicitandoUbicacionActual = false;
            _esperandoUbicacionActual = false;
            _avisoUbicacionActual = 'No se pudo centrar en tu ubicación actual. Permite el acceso a ubicación o elige el punto manualmente.';
          });
          return;
        }
        try {
          final CameraState estado = await mapa.getCameraState();
          if (!mounted || !_esperandoUbicacionActual) return;
          _finalizarEsperaUbicacionActual(
            _CoordenadaMapa(
              latitud: estado.center.coordinates.lat.toDouble(),
              longitud: estado.center.coordinates.lng.toDouble(),
            ),
          );
        } catch (_) {}
      },
    );
  }

  void _confirmarUbicacion() {
    if (_ciudad.text.trim().isEmpty || _sector.text.trim().isEmpty) {
      aviso(context, 'Ingresa ciudad y sector antes de confirmar.');
      return;
    }

    Navigator.pop<Map<String, String>>(context, {
      'ciudad': _ciudad.text.trim(),
      'sector': _sector.text.trim(),
      'latitud': _punto.latitud.toString(),
      'longitud': _punto.longitud.toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool anchoAmplio = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      backgroundColor: ColoresApp.grisClaro,
      appBar: AppBar(
        backgroundColor: ColoresApp.blanco,
        surfaceTintColor: ColoresApp.blanco,
        elevation: 0,
        title: const Text(
          'Cambiar ubicación',
          style: TextStyle(
            color: ColoresApp.azulMarino,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: LogoHelpi(tamano: 24)),
          ),
        ],
      ),
      body: FondoHelpi(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(anchoAmplio ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TarjetaSeccion(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ciudades principales y búsqueda',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.azulMarino,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Elige una ciudad, busca una dirección o toca el mapa para fijar el punto exacto.',
                            style: TextStyle(
                              fontSize: 13,
                              color: ColoresApp.grisOscuro,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _centrosCiudades.keys.map((
                              String nombre,
                            ) {
                              final bool seleccionada =
                                  _ciudad.text.trim().toLowerCase() ==
                                  nombre.toLowerCase();
                              return ChoiceChip(
                                label: Text(nombre),
                                selected: seleccionada,
                                selectedColor: ColoresApp.verdeMenta,
                                backgroundColor: ColoresApp.grisClaro,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: seleccionada
                                      ? ColoresApp.verdeAzulado
                                      : ColoresApp.azulMarino,
                                ),
                                side: BorderSide(
                                  color: seleccionada
                                      ? ColoresApp.verdeAzulado
                                      : const Color(0xFFD5E1E8),
                                ),
                                onSelected: (_) =>
                                    _seleccionarCiudadPredefinida(nombre),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _busquedaDireccion,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _buscarDirecciones(),
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar dirección o sector',
                                    hintText:
                                        'Ej. Av. Daniel León Borja, Riobamba',
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: ColoresApp.verdeAzulado,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 54,
                                child: FilledButton(
                                  onPressed: _buscandoDirecciones
                                      ? null
                                      : _buscarDirecciones,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                  ),
                                  child: _buscandoDirecciones
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: ColoresApp.blanco,
                                          ),
                                        )
                                      : const Text('Buscar'),
                                ),
                              ),
                            ],
                          ),
                          if (_errorBusqueda != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _errorBusqueda!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: ColoresApp.coral,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (_sugerencias.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: ColoresApp.grisClaro,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFD5E1E8),
                                ),
                              ),
                              child: Column(
                                children: _sugerencias.map((resultado) {
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.place_rounded,
                                      color: ColoresApp.verdeAzulado,
                                    ),
                                    title: Text(
                                      resultado.titulo,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: ColoresApp.azulMarino,
                                      ),
                                    ),
                                    subtitle: resultado.subtitulo.isNotEmpty
                                        ? Text(
                                            resultado.subtitulo,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    onTap: () =>
                                        _aplicarResultadoBusqueda(resultado),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TarjetaSeccion(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _solicitandoUbicacionActual
                                    ? null
                                    : _usarUbicacionActual,
                                icon: _solicitandoUbicacionActual
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: ColoresApp.verdeAzulado,
                                        ),
                                      )
                                    : const Icon(Icons.my_location_rounded),
                                label: Text(
                                  _solicitandoUbicacionActual
                                      ? 'Ubicando...'
                                      : 'Usar mi ubicación actual',
                                ),
                              ),
                              FilterChip(
                                selected: _ajustarAlCentro,
                                selectedColor: ColoresApp.verdeMenta,
                                checkmarkColor: ColoresApp.verdeAzulado,
                                avatar: Icon(
                                  Icons.center_focus_strong_rounded,
                                  size: 18,
                                  color: _ajustarAlCentro
                                      ? ColoresApp.verdeAzulado
                                      : ColoresApp.grisOscuro,
                                ),
                                label: const Text(
                                  'Mover mapa para ajustar pin',
                                ),
                                onSelected: (bool activo) {
                                  setState(() {
                                    _ajustarAlCentro = activo;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_avisoUbicacionActual != null) ...[
                            const SizedBox(height: 10),
                            _BannerAviso(
                              texto: _avisoUbicacionActual!,
                              esError: true,
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            height: anchoAmplio ? 380 : 310,
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: _construirAreaMapa(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ColoresApp.verdeMenta,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.gps_fixed_rounded,
                                  size: 18,
                                  color: ColoresApp.verdeAzulado,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Latitud: ${_punto.latitud.toStringAsFixed(5)} · Longitud: ${_punto.longitud.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ColoresApp.azulMarino,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TarjetaSeccion(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (anchoAmplio)
                            Row(
                              children: [
                                Expanded(child: _campoCiudad()),
                                const SizedBox(width: 12),
                                Expanded(child: _campoSector()),
                              ],
                            )
                          else ...[
                            _campoCiudad(),
                            const SizedBox(height: 12),
                            _campoSector(),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(64, 52),
                                  ),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  onPressed: _confirmarUbicacion,
                                  child: const Text('Usar esta ubicación'),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _campoCiudad() {
    return TextField(
      controller: _ciudad,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Ciudad',
        prefixIcon: Icon(
          Icons.location_city_rounded,
          color: ColoresApp.verdeAzulado,
        ),
      ),
    );
  }

  Widget _campoSector() {
    return TextField(
      controller: _sector,
      decoration: const InputDecoration(
        labelText: 'Sector o referencia',
        prefixIcon: Icon(
          Icons.signpost_rounded,
          color: ColoresApp.verdeAzulado,
        ),
      ),
    );
  }

  Widget _construirAreaMapa() {
    if (_estadoToken == _EstadoTokenMapbox.ausente) {
      return const _EstadoMapaRespaldo(
        icono: Icons.map_outlined,
        titulo: 'Mapa interactivo pendiente de token público',
        mensaje: 'Configura tu token público (pk.) en el archivo .env.mapbox con la variable MAPBOX_ACCESS_TOKEN para habilitar el mapa de Mapbox. Mientras tanto, puedes elegir Riobamba, Quito o Cuenca y confirmar tu ubicación.',
      );
    }

    if (_estadoToken == _EstadoTokenMapbox.privadoNoPermitido) {
      return const _EstadoMapaRespaldo(
        icono: Icons.lock_outline_rounded,
        titulo: 'Token de Mapbox no válido para cliente',
        mensaje: 'Por seguridad, no se permite usar tokens privados (sk.) en Flutter. Configura únicamente un token público (pk.) en MAPBOX_ACCESS_TOKEN dentro de .env.mapbox.',
        esError: true,
      );
    }

    if (_errorMapa != null) {
      return _EstadoMapaRespaldo(
        icono: Icons.wifi_off_rounded,
        titulo: 'No se pudo cargar el mapa',
        mensaje: _errorMapa!,
        esError: true,
        accion: OutlinedButton.icon(
          onPressed: _reintentarCargaMapa,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
    }

    return Stack(
      children: [
        MapWidget(
          key: ValueKey(_intentoMapa),
          styleUri: MapboxStyles.MAPBOX_STREETS,
          viewport: CameraViewportState(
            center: _punto.toMapboxPoint(),
            zoom: 14.0,
          ),
          viewportController: _controladorViewport,
          onMapCreated: _alCrearMapa,
          onStyleLoadedListener: _alCargarEstilo,
          onMapLoadedListener: _alCargarMapa,
          onMapLoadErrorListener: _alFallarCargaMapa,
          onMapIdleListener: _alDetenerMapa,
        ),
        if (_ajustarAlCentro && _estiloCargado)
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.add_location_alt_rounded,
                size: 38,
                color: ColoresApp.coral,
              ),
            ),
          ),
        if (_cargandoMapa)
          Positioned.fill(
            child: Container(
              color: ColoresApp.grisClaro.withValues(alpha: 0.85),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: ColoresApp.verdeAzulado),
                    SizedBox(height: 12),
                    Text(
                      'Cargando mapa interactivo...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ColoresApp.azulMarino,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_estiloCargado)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ColoresApp.blanco.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _ajustarAlCentro
                        ? 'Mueve el mapa para ajustar el punto'
                        : 'Toca cualquier punto del mapa para mover el pin',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.azulMarino,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TarjetaSeccion extends StatelessWidget {
  const _TarjetaSeccion({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EBF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B15324F),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BannerAviso extends StatelessWidget {
  const _BannerAviso({required this.texto, this.esError = false});

  final String texto;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    final Color borde = esError
        ? ColoresApp.coral.withValues(alpha: 0.45)
        : ColoresApp.verdeAzulado.withValues(alpha: 0.35);
    final Color fondo = esError
        ? ColoresApp.coral.withValues(alpha: 0.1)
        : ColoresApp.verdeMenta;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13,
          color: esError ? ColoresApp.azulMarino : ColoresApp.verdeAzulado,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EstadoMapaRespaldo extends StatelessWidget {
  const _EstadoMapaRespaldo({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.esError = false,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final bool esError;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ColoresApp.grisClaro,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: esError
              ? ColoresApp.coral.withValues(alpha: 0.45)
              : const Color(0xFFD5E1E8),
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                size: 40,
                color: esError ? ColoresApp.coral : ColoresApp.verdeAzulado,
              ),
              const SizedBox(height: 10),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.azulMarino,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: ColoresApp.grisOscuro,
                ),
              ),
              if (accion != null) ...[const SizedBox(height: 14), accion!],
            ],
          ),
        ),
      ),
    );
  }
}
