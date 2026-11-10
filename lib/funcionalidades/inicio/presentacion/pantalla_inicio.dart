import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../registro/datos/repositorio_perfil.dart';

import 'componentes/barra_superior_helpi.dart';
import 'componentes/selector_categorias.dart';
import 'pantalla_elegir_ubicacion.dart';
import 'vista_prestador.dart';
import '../../solicitudes/presentacion/pantalla_solicitud.dart';
import '../../solicitudes/presentacion/vista_mis_servicios.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../bienvenida/presentacion/pantalla_bienvenida.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key, required this.perfil});

  final Map<String, dynamic> perfil;

  @override
  State<PantallaInicio> createState() => _EstadoPantallaInicio();
}

class _EstadoPantallaInicio extends State<PantallaInicio> {
  final _preferencias = SharedPreferencesAsync();

  late Map<String, dynamic> _perfil;

  int _seccion = 0;

  bool _guardandoRol = false;
  bool _guardandoFoto = false;
  bool _abriendoUbicacion = false;
  bool _cerrandoSesion = false;

  String _ciudad = 'Riobamba';
  String _sector = '';
  String _categoria = 'Todas';

  double? _latitud;
  double? _longitud;

  Uint8List? _foto;

  bool get _esPrestador => _perfil['rol'] == 'prestador';

  String get _nombre {
    return (_perfil['nombre'] ?? '').toString().trim();
  }

  String get _claveAvatar {
    final identificador = (_perfil['telefono'] ?? _perfil['nombre'] ?? 'demo')
        .toString();

    final clave = base64Url.encode(utf8.encode(identificador));

    return 'helpi_avatar_demo_$clave';
  }

  @override
  void initState() {
    super.initState();

    _perfil = Map<String, dynamic>.from(widget.perfil);

    final ciudad = (_perfil['ciudad'] ?? '').toString().trim();

    if (ciudad.isNotEmpty) {
      _ciudad = ciudad;
    }

    final foto = _perfil['foto'];

    if (foto is Uint8List) {
      _foto = foto;
    }

    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    try {
      final ubicacionGuardada = await _preferencias.getString(
        'helpi_ubicacion_exploracion_demo',
      );

      final fotoGuardada = await _preferencias.getString(_claveAvatar);

      String? ciudad;
      String sector = '';

      double? latitud;
      double? longitud;

      Uint8List? foto;

      if (ubicacionGuardada != null) {
        final ubicacion = Map<String, dynamic>.from(
          jsonDecode(ubicacionGuardada),
        );

        ciudad = ubicacion['ciudad']?.toString();
        sector = (ubicacion['sector'] ?? '').toString();

        latitud = double.tryParse((ubicacion['latitud'] ?? '').toString());

        longitud = double.tryParse((ubicacion['longitud'] ?? '').toString());
      }

      if (_foto == null && fotoGuardada != null) {
        final bytes = base64Decode(fotoGuardada);

        final imagen = await decodeImageFromList(bytes);
        imagen.dispose();

        foto = bytes;
      }

      if (!mounted) return;

      setState(() {
        if (ciudad != null && ciudad.trim().isNotEmpty) {
          _ciudad = ciudad.trim();
        }

        _sector = sector;
        _latitud = latitud;
        _longitud = longitud;

        if (_foto == null && foto != null) {
          _foto = foto;
        }
      });
    } catch (_) {
      if (!mounted) return;

      aviso(context, 'No se pudieron recuperar algunas preferencias locales.');
    }
  }

  Future<void> _cambiarRol(String rol) async {
    if (_guardandoRol || rol == _perfil['rol']) return;

    setState(() => _guardandoRol = true);

    final actualizado = <String, dynamic>{..._perfil, 'rol': rol};

    try {
      await RepositorioPerfil().guardar(actualizado);

      if (!mounted) return;

      setState(() {
        _perfil = actualizado;
        _seccion = 0;
      });
    } catch (_) {
      if (mounted) {
        aviso(context, 'No pudimos guardar el cambio de rol.');
      }
    } finally {
      if (mounted) {
        setState(() => _guardandoRol = false);
      }
    }
  }

  Future<void> _cambiarUbicacion() async {
    if (_abriendoUbicacion) return;

    setState(() => _abriendoUbicacion = true);

    try {
      final ubicacion = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          builder: (_) => PantallaElegirUbicacion(
            ciudad: _ciudad,
            sector: _sector,
            latitud: _latitud,
            longitud: _longitud,
          ),
        ),
      );

      if (ubicacion == null || !mounted) return;

      await _preferencias.setString(
        'helpi_ubicacion_exploracion_demo',
        jsonEncode(ubicacion),
      );

      if (!mounted) return;

      setState(() {
        _ciudad = ubicacion['ciudad'] ?? _ciudad;
        _sector = ubicacion['sector'] ?? '';

        _latitud = double.tryParse(ubicacion['latitud'] ?? '');

        _longitud = double.tryParse(ubicacion['longitud'] ?? '');

        _seccion = 0;
      });
    } catch (_) {
      if (mounted) {
        aviso(context, 'No pudimos abrir o guardar la ubicación.');
      }
    } finally {
      if (mounted) {
        setState(() => _abriendoUbicacion = false);
      }
    }
  }

  Future<void> _elegirFoto() async {
    if (_guardandoFoto) return;

    setState(() => _guardandoFoto = true);

    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 75,
        requestFullMetadata: false,
      );

      if (archivo == null) return;

      final bytes = await archivo.readAsBytes();

      if (bytes.length > 512 * 1024) {
        if (mounted) {
          aviso(context, 'Selecciona una imagen menor de 512 KB.');
        }

        return;
      }

      final imagen = await decodeImageFromList(bytes);
      imagen.dispose();

      await _preferencias.setString(_claveAvatar, base64Encode(bytes));

      if (!mounted) return;

      setState(() {
        _foto = bytes;
        _perfil['foto'] = bytes;
      });
    } catch (_) {
      if (mounted) {
        aviso(context, 'No pudimos guardar la foto. Prueba con JPG o PNG.');
      }
    } finally {
      if (mounted) {
        setState(() => _guardandoFoto = false);
      }
    }
  }

  Future<void> _quitarFoto() async {
    if (_guardandoFoto) return;

    setState(() => _guardandoFoto = true);

    try {
      await _preferencias.remove(_claveAvatar);

      if (!mounted) return;

      setState(() {
        _foto = null;
        _perfil.remove('foto');
      });
    } catch (_) {
      if (mounted) {
        aviso(context, 'No pudimos quitar la foto.');
      }
    } finally {
      if (mounted) {
        setState(() => _guardandoFoto = false);
      }
    }
  }

  Widget _inicioSolicitante() {
    final primerNombre = _nombre.isEmpty
        ? ''
        : _nombre.split(RegExp(r'\s+')).first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿En qué podemos ayudarte?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),

        const SizedBox(height: 16),

        Center(
          child: SelectorCategorias(
            seleccionada: _categoria,
            alSeleccionar: (categoria) {
              setState(() => _categoria = categoria);
            },
          ),
        ),

        const SizedBox(height: 28),

        const Text(
          'TU COMUNIDAD, MÁS CERCA',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: ColoresApp.verdeAzulado,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          primerNombre.isEmpty ? '¡Hola!' : '¡Hola, $primerNombre!',
          style: Theme.of(context).textTheme.headlineLarge,
        ),

        const SizedBox(height: 10),

        Text('Encuentra ayuda cerca de ti en $_ciudad.'),

        const SizedBox(height: 24),

        _bannerSolicitante(),
      ],
    );
  }

  Widget _bannerSolicitante() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/imagenes/fondo_prestador.jpeg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              excludeFromSemantics: true,
            ),
          ),

          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ENCUENTRA AYUDA EN TU COMUNIDAD',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.bold,
                        color: ColoresApp.verdeMenta,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Eso que necesitas, alguien sabe hacerlo.',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Encuentra apoyo para las tareas cotidianas '
                      'de tu hogar, estudios y tecnología.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ColoresApp.verdeAzulado,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      onPressed: () async {
                        final publicada = await Navigator.of(context)
                            .push<bool>(
                              MaterialPageRoute(
                                builder: (_) => const PantallaSolicitud(),
                              ),
                            );

                        if (!mounted) return;

                        if (publicada == true) {
                          aviso(
                            context,
                            'Tu solicitud se publicó correctamente.',
                          );
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(
                        _categoria == 'Todas'
                            ? 'Solicitar ayuda'
                            : 'Solicitar ayuda: $_categoria',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _misServicios() {
    return VistaMisServicios(esPrestador: _esPrestador);
  }

  Widget _notificaciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Notificaciones',
          style: Theme.of(context).textTheme.headlineLarge,
        ),

        const SizedBox(height: 22),

        const TarjetaHelpi(
          child: Column(
            children: [
              Icon(
                Icons.notifications_none,
                size: 48,
                color: ColoresApp.verdeAzulado,
              ),

              SizedBox(height: 16),

              Text('No tienes notificaciones.', textAlign: TextAlign.center),

              SizedBox(height: 10),

              Text(
                'Aquí aparecerán tus avisos cuando estén disponibles.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _datoPerfil(String etiqueta, String valor) {
    if (valor.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              color: ColoresApp.verdeAzulado,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          Text(valor),
        ],
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    if (_cerrandoSesion) return;

    setState(() {
      _cerrandoSesion = true;
    });

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Elimina las pantallas anteriores del historial de navegación.
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const PantallaBienvenida()),
        (ruta) => false,
      );
    } catch (_) {
      if (!mounted) return;

      aviso(context, 'No se pudo cerrar la sesión. Inténtalo otra vez.');
    } finally {
      if (mounted) {
        setState(() {
          _cerrandoSesion = false;
        });
      }
    }
  }

  Widget _perfilUsuario() {
    final categorias = _perfil['categorias'];
    final textoCategorias = categorias is List
        ? categorias.join(', ')
        : (categorias ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Mi perfil', style: Theme.of(context).textTheme.headlineLarge),

        const SizedBox(height: 22),

        TarjetaHelpi(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: ColoresApp.verdeMenta,
                  backgroundImage: _foto == null ? null : MemoryImage(_foto!),
                  child: _foto == null
                      ? const Icon(
                          Icons.person_outline,
                          size: 44,
                          color: ColoresApp.verdeAzulado,
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                _nombre,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 8),

              TextButton.icon(
                onPressed: _guardandoFoto ? null : _elegirFoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _guardandoFoto ? 'Procesando…' : 'Cambiar foto de perfil',
                ),
              ),

              if (_foto != null)
                TextButton(
                  onPressed: _guardandoFoto ? null : _quitarFoto,
                  child: const Text('Quitar foto'),
                ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              _datoPerfil(
                'Rol activo',
                _esPrestador ? 'Prestador' : 'Solicitante',
              ),

              _datoPerfil('Teléfono', '${_perfil['telefono'] ?? ''}'),

              _datoPerfil(
                'Ciudad del perfil',
                (_perfil['ciudad'] ?? '').toString(),
              ),

              _datoPerfil(
                'Sector del perfil',
                (_perfil['sector'] ?? '').toString(),
              ),

              _datoPerfil('Categorías', textoCategorias),

              _datoPerfil(
                'Habilidades',
                (_perfil['habilidades'] ?? '').toString(),
              ),

              _datoPerfil(
                'Sobre mí',
                (_perfil['presentacion'] ?? '').toString(),
              ),

              _datoPerfil(
                'Disponibilidad',
                (_perfil['disponibilidad'] ?? '').toString(),
              ),

              const SizedBox(height: 8),

              const Text(
                'Sin calificaciones todavía.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 24),

              const Divider(),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _cerrandoSesion ? null : _cerrarSesion,
                icon: const Icon(Icons.logout),
                label: Text(
                  _cerrandoSesion ? 'Cerrando sesión…' : 'Cerrar sesión',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contenidoSeccion() {
    switch (_seccion) {
      case 1:
        return _misServicios();

      case 2:
        return _notificaciones();

      case 3:
        return _perfilUsuario();

      default:
        if (_esPrestador) {
          return VistaPrestador(
            key: ValueKey('$_ciudad:$_sector:$_latitud:$_longitud'),
            nombre: _nombre,
            ciudad: _ciudad,
            sector: _sector,
            latitud: _latitud,
            longitud: _longitud,
          );
        }

        return _inicioSolicitante();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.grisClaro,

      bottomNavigationBar: NavigationBar(
        selectedIndex: _seccion,
        backgroundColor: Colors.white,
        indicatorColor: ColoresApp.verdeMenta,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (indice) {
          setState(() => _seccion = indice);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: ColoresApp.verdeAzulado),
            label: 'Inicio',
          ),

          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work, color: ColoresApp.verdeAzulado),
            label: 'Mis servicios',
          ),

          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(
              Icons.notifications,
              color: ColoresApp.verdeAzulado,
            ),
            label: 'Notificaciones',
          ),

          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: ColoresApp.verdeAzulado),
            label: 'Mi perfil',
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            BarraSuperiorHelpi(
              seccion: _seccion,
              rol: _esPrestador ? 'prestador' : 'solicitante',
              ciudad: _ciudad,
              sector: _sector,
              nombre: _nombre,
              foto: _foto,
              guardandoRol: _guardandoRol,
              alCambiarSeccion: (indice) {
                setState(() => _seccion = indice);
              },
              alCambiarRol: _cambiarRol,
              alCambiarUbicacion: _cambiarUbicacion,
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, espacio) {
                  final margen = espacio.maxWidth < 600 ? 16.0 : 28.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(margen),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _contenidoSeccion(),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
