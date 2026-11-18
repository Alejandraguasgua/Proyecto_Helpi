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
import 'pantalla_editar_perfil.dart';
import 'pantalla_elegir_ubicacion.dart';
import 'pantalla_perfil_prestador.dart';
import 'vista_prestador.dart';
import '../../notificaciones/presentacion/vista_notificaciones.dart';
import '../../solicitudes/presentacion/pantalla_solicitud.dart';
import '../../solicitudes/presentacion/vista_mis_servicios.dart';
import '../../terminos/presentacion/pantalla_terminos.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../bienvenida/presentacion/pantalla_bienvenida.dart';
import '../../administrador/datos/repositorio_admin.dart';
import '../../administrador/presentacion/pantalla_admin.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key, required this.perfil});

  final Map<String, dynamic> perfil;

  @override
  State<PantallaInicio> createState() => _EstadoPantallaInicio();
}

class _EstadoPantallaInicio extends State<PantallaInicio> {
  SharedPreferencesAsync get _preferencias => SharedPreferencesAsync();

  late Map<String, dynamic> _perfil;

  int _seccion = 0;

  bool _guardandoRol = false;
  bool _guardandoFoto = false;
  bool _abriendoUbicacion = false;
  bool _cerrandoSesion = false;
  bool _eliminandoCuenta = false;
  bool _cargandoPerfil = false;
  String? _errorPerfil;

  /// Solo quien tiene la claim `admin: true` ve la opción "Administrador".
  bool _esAdmin = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargarPreferencias();
        _verificarAdmin();
      }
    });
  }

  /// Consulta si el usuario tiene permiso de administrador para mostrar
  /// (u ocultar) la opción "Administrador" en Mi perfil.
  Future<void> _verificarAdmin() async {
    if (Firebase.apps.isEmpty) return;

    final esAdmin = await RepositorioAdmin().esAdministrador();

    if (mounted && esAdmin != _esAdmin) {
      setState(() => _esAdmin = esAdmin);
    }
  }

  void _abrirAdministrador() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PantallaAdmin()),
    );
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

    try {
      Map<String, dynamic> actualizado;
      try {
        actualizado = await RepositorioPerfil().actualizarCampos({'rol': rol});
      } catch (_) {
        actualizado = <String, dynamic>{..._perfil, 'rol': rol};
        await RepositorioPerfil().guardar(actualizado);
      }

      if (!mounted) return;

      setState(() {
        _perfil = <String, dynamic>{
          ..._perfil,
          ...actualizado,
          'rol': rol,
          if (_foto != null) 'foto': _foto,
        };
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

  Future<void> _editarPerfil() async {
    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => PantallaEditarPerfil(perfil: _perfil),
      ),
    );

    if (!mounted || resultado == null) return;

    final nuevaCiudad = (resultado['ciudad'] ?? '').toString().trim();
    final nuevoSector = (resultado['sector'] ?? '').toString().trim();

    setState(() {
      _perfil = <String, dynamic>{
        ..._perfil,
        ...resultado,
        if (_foto != null) 'foto': _foto,
      };
      if (nuevaCiudad.isNotEmpty) {
        _ciudad = nuevaCiudad;
      }
      if (nuevoSector.isNotEmpty) {
        _sector = nuevoSector;
      }
    });

    aviso(context, 'Tu perfil se actualizó correctamente.');
  }

  Future<void> _eliminarCuenta() async {
    if (_eliminandoCuenta || _cerrandoSesion) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ColoresApp.coral),
            SizedBox(width: 8),
            Expanded(child: Text('Eliminar cuenta de Helpi')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta acción es permanente e irreversible:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.azulMarino,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '• Se eliminarán tu cuenta de autenticación y los datos personales de tu perfil (nombre, teléfono, correo, ubicación y presentación).\n'
                '• Si tienes servicios activos (publicados, aceptados o en proceso), deberás cancelarlos o finalizarlos antes de poder eliminar tu cuenta.\n'
                '• Las calificaciones emitidas en servicios completados se conservarán de forma anónima ("Usuario eliminado") para mantener la integridad del historial de la comunidad sin exponer tus datos personales.\n'
                '• Se te pedirá verificar nuevamente tu identidad con Google para confirmar la operación.',
                style: TextStyle(
                  fontSize: 13,
                  color: ColoresApp.grisOscuro,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.coral),
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Verificar identidad y eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    setState(() {
      _eliminandoCuenta = true;
    });

    try {
      await RepositorioPerfil().eliminarCuenta();

      if (!mounted) return;

      aviso(context, 'Tu cuenta y tus datos personales fueron eliminados.');

      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const PantallaBienvenida()),
        (ruta) => false,
      );
    } catch (error) {
      if (!mounted) return;

      final mensaje = error.toString().replaceFirst('Exception: ', '');
      aviso(
        context,
        mensaje.isNotEmpty
            ? mensaje
            : 'No se pudo completar la eliminación de la cuenta.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _eliminandoCuenta = false;
        });
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
                                builder: (_) => PantallaSolicitud(
                                  categoriaInicial: _categoria == 'Todas'
                                      ? null
                                      : _categoria,
                                ),
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
    return VistaMisServicios(
      esPrestador: _esPrestador,
      alActualizarPerfil: (perfilActualizado) {
        if (!mounted) return;
        setState(() {
          _perfil = <String, dynamic>{
            ..._perfil,
            ...perfilActualizado,
            if (_foto != null) 'foto': _foto,
          };
        });
      },
    );
  }

  Widget _notificaciones() {
    return const VistaNotificaciones();
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

  Future<void> _cargarPerfil({bool mostrarAvisoExito = false}) async {
    if (_cargandoPerfil) return;

    setState(() {
      _cargandoPerfil = true;
      _errorPerfil = null;
    });

    try {
      final perfilRemoto = await RepositorioPerfil().leer();

      if (!mounted) return;

      if (perfilRemoto != null) {
        final nuevaCiudad = (perfilRemoto['ciudad'] ?? '').toString().trim();
        final nuevoSector = (perfilRemoto['sector'] ?? '').toString().trim();

        setState(() {
          _perfil = <String, dynamic>{
            ..._perfil,
            ...perfilRemoto,
            if (_foto != null) 'foto': _foto,
          };
          if (nuevaCiudad.isNotEmpty) {
            _ciudad = nuevaCiudad;
          }
          if (nuevoSector.isNotEmpty) {
            _sector = nuevoSector;
          }
          _cargandoPerfil = false;
        });

        if (mostrarAvisoExito) {
          aviso(context, 'Perfil actualizado.');
        }
      } else {
        setState(() {
          _cargandoPerfil = false;
          if (_perfil.isEmpty) {
            _errorPerfil = 'No encontramos los datos de tu perfil.';
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoPerfil = false;
        _errorPerfil =
            'No pudimos sincronizar tu perfil desde el servidor. '
            'Revisa tu conexión e inténtalo nuevamente.';
      });
    }
  }

  void _seleccionarSeccion(int indice) {
    setState(() => _seccion = indice);
    if (indice == 3) {
      _cargarPerfil();
      _verificarAdmin();
    }
  }

  Widget _perfilUsuario() {
    final categorias = _perfil['categorias'];
    final textoCategorias = categorias is List
        ? categorias.join(', ')
        : (categorias ?? '').toString();

    final promedioRaw = _perfil['promedio'];
    final promedio = promedioRaw is num ? promedioRaw.toDouble() : null;
    final totalCalificaciones =
        (_perfil['totalCalificaciones'] as num?)?.toInt() ?? 0;
    final uidActual =
        (_perfil['uid'] ??
                (Firebase.apps.isNotEmpty
                    ? FirebaseAuth.instance.currentUser?.uid
                    : null) ??
                '')
            .toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mi perfil',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            IconButton(
              onPressed:
                  (_cargandoPerfil || _cerrandoSesion || _eliminandoCuenta)
                  ? null
                  : () => _cargarPerfil(mostrarAvisoExito: true),
              tooltip: 'Actualizar perfil',
              icon: const Icon(Icons.refresh, color: ColoresApp.verdeAzulado),
            ),
            const SizedBox(width: 4),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: (_cerrandoSesion || _eliminandoCuenta)
                  ? null
                  : _editarPerfil,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar perfil'),
            ),
          ],
        ),

        if (_cargandoPerfil) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],

        if (_errorPerfil != null) ...[
          const SizedBox(height: 16),
          TarjetaHelpi(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _errorPerfil!,
                  style: const TextStyle(color: ColoresApp.coral),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _cargandoPerfil ? null : () => _cargarPerfil(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],

        if (_cargandoPerfil && _perfil.isEmpty) ...[
          const SizedBox(height: 48),
          const Center(child: CircularProgressIndicator()),
        ] else ...[
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
                  _nombre.isEmpty ? 'Usuario de Helpi' : _nombre,
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

                const SizedBox(height: 16),

                // Resumen de calificaciones y acceso a reseñas
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: ColoresApp.verdeMenta,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          promedio != null
                              ? '${promedio.toStringAsFixed(1)} ★ · $totalCalificaciones ${totalCalificaciones == 1 ? 'calificación' : 'calificaciones'}'
                              : 'Sin calificaciones todavía.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ColoresApp.azulMarino,
                          ),
                        ),
                      ),
                      if (uidActual.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PantallaPerfilPrestador(
                                  uidPrestador: uidActual,
                                  perfilInicial: _perfil,
                                ),
                              ),
                            );
                          },
                          child: const Text('Ver reseñas'),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                const Text(
                  'Rol activo',
                  style: TextStyle(
                    color: ColoresApp.verdeAzulado,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Solicitante'),
                      selected: !_esPrestador,
                      selectedColor: ColoresApp.verdeMenta,
                      onSelected: _guardandoRol
                          ? null
                          : (_) => _cambiarRol('solicitante'),
                    ),
                    ChoiceChip(
                      label: const Text('Prestador'),
                      selected: _esPrestador,
                      selectedColor: ColoresApp.verdeMenta,
                      onSelected: _guardandoRol
                          ? null
                          : (_) => _cambiarRol('prestador'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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
                const Divider(),
                const SizedBox(height: 8),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.description_outlined,
                    color: ColoresApp.verdeAzulado,
                  ),
                  title: const Text(
                    'Términos y condiciones',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Versión 1.0 · Consulta',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PantallaTerminos(
                          modo: ModoTerminos.consulta,
                          pestanaInicial: 0,
                        ),
                      ),
                    );
                  },
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: ColoresApp.verdeAzulado,
                  ),
                  title: const Text(
                    'Política de privacidad',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Tratamiento de datos personales',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PantallaTerminos(
                          modo: ModoTerminos.consulta,
                          pestanaInicial: 1,
                        ),
                      ),
                    );
                  },
                ),

                if (_esAdmin)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: ColoresApp.verdeAzulado,
                    ),
                    title: const Text(
                      'Administrador',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Panel de administración de Helpi',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _abrirAdministrador,
                  ),

                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: (_cerrandoSesion || _eliminandoCuenta)
                      ? null
                      : _cerrarSesion,
                  icon: const Icon(Icons.logout),
                  label: Text(
                    _cerrandoSesion ? 'Cerrando sesión…' : 'Cerrar sesión',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Zona claramente identificada como acción irreversible
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: ColoresApp.coral,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Zona de cuenta · Acción irreversible',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.azulMarino,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Eliminar tu cuenta borrará de forma permanente tu acceso y los datos personales de tu perfil. No debes tener servicios activos pendientes.',
                  style: TextStyle(
                    fontSize: 13,
                    color: ColoresApp.grisOscuro,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresApp.coral,
                    side: const BorderSide(color: ColoresApp.coral),
                  ),
                  onPressed: (_eliminandoCuenta || _cerrandoSesion)
                      ? null
                      : _eliminarCuenta,
                  icon: _eliminandoCuenta
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ColoresApp.coral,
                          ),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: Text(
                    _eliminandoCuenta
                        ? 'Eliminando cuenta…'
                        : 'Eliminar cuenta',
                  ),
                ),
              ],
            ),
          ),
        ],
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
        onDestinationSelected: _seleccionarSeccion,
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
              alCambiarSeccion: _seleccionarSeccion,
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
