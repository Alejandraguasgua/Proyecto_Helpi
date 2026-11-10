import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../datos/repositorio_solicitudes.dart';

class PantallaDetalleServicio extends StatefulWidget {
  const PantallaDetalleServicio({super.key, required this.id});

  final String id;

  @override
  State<PantallaDetalleServicio> createState() =>
      _EstadoPantallaDetalleServicio();
}

class _EstadoPantallaDetalleServicio extends State<PantallaDetalleServicio> {
  final _repositorio = RepositorioSolicitudes();

  Map<String, dynamic>? _servicio;
  Map<String, dynamic>? _perfilSolicitante;
  Map<String, dynamic>? _perfilPrestador;

  String? _error;
  bool _cargando = true;
  bool _procesando = false;
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _mensaje(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _codigoCorto(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final servicio = await _repositorio.obtener(widget.id);

      if (!mounted) return;

      setState(() {
        _servicio = servicio;
      });

      // Carga información pública de los participantes si están disponibles
      final solicitanteUid = servicio['solicitanteUid']?.toString();
      final prestadorUid = servicio['prestadorUid']?.toString();

      if (solicitanteUid != null && solicitanteUid.isNotEmpty) {
        _repositorio.obtenerPerfilPublico(solicitanteUid).then((perfil) {
          if (mounted && perfil != null) {
            setState(() => _perfilSolicitante = perfil);
          }
        });
      }

      if (prestadorUid != null && prestadorUid.isNotEmpty) {
        _repositorio.obtenerPerfilPublico(prestadorUid).then((perfil) {
          if (mounted && perfil != null) {
            setState(() => _perfilPrestador = perfil);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _mensaje(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<bool> _confirmarAccion(String titulo, String mensaje) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    return resultado == true;
  }

  Future<String?> _pedirMotivoCancelacion() {
    final formulario = GlobalKey<FormState>();
    final controlador = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Cancelar servicio'),
        content: Form(
          key: formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Indica el motivo de cancelación para informar a tu contraparte:',
                style: TextStyle(fontSize: 13, color: ColoresApp.grisOscuro),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controlador,
                autofocus: true,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Escribe al menos 5 caracteres.',
                ),
                validator: (valor) {
                  final limpio = valor?.trim() ?? '';
                  if (limpio.length < 5) {
                    return 'Escribe al menos 5 caracteres.';
                  }
                  if (limpio.length > 300) {
                    return 'El motivo no puede superar 300 caracteres.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.coral),
            onPressed: () {
              if (formulario.currentState!.validate()) {
                Navigator.pop(dialogo, controlador.text.trim());
              }
            },
            child: const Text('Confirmar cancelación'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutar(
    String accion,
    String titulo,
    String explicacion,
  ) async {
    if (_procesando || _cargando || _servicio == null) return;

    Map<String, dynamic>? datos;

    if (accion == 'cancelar') {
      final motivo = await _pedirMotivoCancelacion();
      if (!mounted || motivo == null) return;
      datos = {'motivo': motivo};
    } else {
      final confirmado = await _confirmarAccion(titulo, explicacion);
      if (!mounted || !confirmado) return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      await _repositorio.accion(widget.id, accion, datos: datos);

      if (!mounted) return;

      _huboCambios = true;

      String mensajeExito;
      switch (accion) {
        case 'iniciar':
          mensajeExito = 'El servicio ha sido iniciado.';
          break;
        case 'finalizar':
          mensajeExito = 'Finalización solicitada al solicitante.';
          break;
        case 'confirmar':
          mensajeExito = '¡Servicio completado con éxito!';
          break;
        case 'cancelar':
          mensajeExito = 'El servicio ha sido cancelado.';
          break;
        default:
          mensajeExito = 'Operación realizada correctamente.';
      }

      aviso(context, mensajeExito);
      await _cargar();
    } catch (error) {
      if (!mounted) return;

      aviso(context, _mensaje(error));

      // Recupera el estado real por si otra persona lo modificó en paralelo
      await _cargar();
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
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

  Widget _tarjetaParticipante({
    required String rol,
    required String? uid,
    required Map<String, dynamic>? perfil,
    required bool esTuUsuario,
  }) {
    final nombre =
        perfil?['nombre']?.toString() ??
        (uid != null
            ? (rol == 'Solicitante' ? 'Solicitante' : 'Prestador')
            : 'Aún no asignado');
    final promedio = perfil?['promedio'];
    final totalCalificaciones = perfil?['totalCalificaciones'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.grisClaro,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ColoresApp.verdeMenta,
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ColoresApp.verdeAzulado,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rol.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: ColoresApp.verdeAzulado,
                      ),
                    ),
                    if (esTuUsuario) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresApp.verdeMenta,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TÚ',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: ColoresApp.verdeAzulado,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.azulMarino,
                  ),
                ),
                if (promedio != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '★ $promedio ($totalCalificaciones calificaciones)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: ColoresApp.grisOscuro,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(String estado) {
    const etapas = [
      {'titulo': 'Publicada', 'subtitulo': 'Solicitud disponible'},
      {'titulo': 'Aceptada', 'subtitulo': 'Prestador asignado'},
      {'titulo': 'En Proceso', 'subtitulo': 'Servicio en curso'},
      {'titulo': 'Completada', 'subtitulo': 'Confirmado por ambas partes'},
    ];

    final orden = ['Publicada', 'Aceptada', 'En Proceso', 'Completada'];
    final indiceActual = orden.indexOf(estado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Así va tu servicio',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 16),
        ...List.generate(etapas.length, (i) {
          final completada = indiceActual >= 0 && i <= indiceActual;
          final esActual = i == indiceActual;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completada
                          ? ColoresApp.verdeAzulado
                          : const Color(0xFFE2E8F0),
                    ),
                    child: Center(
                      child: completada
                          ? const Icon(
                              Icons.check,
                              size: 15,
                              color: Colors.white,
                            )
                          : Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.grisOscuro,
                              ),
                            ),
                    ),
                  ),
                  if (i < etapas.length - 1)
                    Container(
                      width: 2,
                      height: 28,
                      color: completada && i < indiceActual
                          ? ColoresApp.verdeAzulado
                          : const Color(0xFFE2E8F0),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etapas[i]['titulo']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: esActual
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: esActual
                              ? ColoresApp.azulMarino
                              : (completada
                                    ? ColoresApp.azulMarino
                                    : ColoresApp.grisOscuro),
                        ),
                      ),
                      Text(
                        etapas[i]['subtitulo']!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ColoresApp.grisOscuro,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _contenido(Map<String, dynamic> servicio) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final esSolicitante = uid != null && servicio['solicitanteUid'] == uid;
    final esPrestador = uid != null && servicio['prestadorUid'] == uid;
    final esParticipante = esSolicitante || esPrestador;

    final estado = '${servicio['estado'] ?? 'Publicada'}';
    final finalizacionSolicitada = servicio['finalizacionSolicitada'] == true;

    final centavos = (servicio['montoCentavos'] as num?) ?? 0;
    final monto = (centavos / 100).toStringAsFixed(2);
    final categoria = servicio['categoria']?.toString() ?? 'Servicio';

    final puedeCancelar =
        esParticipante &&
        ['Publicada', 'Aceptada', 'En Proceso'].contains(estado) &&
        servicio['pagoId'] == null;

    final bloqueado = _cargando || _procesando;

    return TarjetaHelpi(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera: Icono, Badge y Monto
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ColoresApp.verdeMenta,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconoCategoria(categoria),
                  size: 26,
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
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.azulMarino,
                    ),
                  ),
                  const Text(
                    'Sin cargos adicionales',
                    style: TextStyle(
                      fontSize: 10,
                      color: ColoresApp.grisOscuro,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Título y categoría
          Text(
            '${servicio['titulo'] ?? 'Servicio'}',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$categoria · Solicitud HP-${_codigoCorto(widget.id)}',
            style: const TextStyle(fontSize: 13, color: ColoresApp.grisOscuro),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 18),

          // Descripción
          Text(
            'Una mano con esto',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '${servicio['descripcion'] ?? ''}',
            style: const TextStyle(
              fontSize: 14,
              color: ColoresApp.grisOscuro,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          // Datos: Ubicación y Horario
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColoresApp.grisClaro,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 20,
                      color: ColoresApp.verdeAzulado,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${servicio['ciudad'] ?? ''} · ${servicio['sector'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ColoresApp.azulMarino,
                            ),
                          ),
                          const Text(
                            'Ubicación acordada del servicio',
                            style: TextStyle(
                              fontSize: 11,
                              color: ColoresApp.grisOscuro,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 20,
                      color: ColoresApp.verdeAzulado,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_fecha(servicio['fechaServicio'])} · ${servicio['horario'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ColoresApp.azulMarino,
                            ),
                          ),
                          const Text(
                            'Horario programado',
                            style: TextStyle(
                              fontSize: 11,
                              color: ColoresApp.grisOscuro,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Participantes
          Text(
            'Participantes',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 10),
          _tarjetaParticipante(
            rol: 'Solicitante',
            uid: servicio['solicitanteUid']?.toString(),
            perfil: _perfilSolicitante,
            esTuUsuario: esSolicitante,
          ),
          const SizedBox(height: 10),
          _tarjetaParticipante(
            rol: 'Prestador',
            uid: servicio['prestadorUid']?.toString(),
            perfil: _perfilPrestador,
            esTuUsuario: esPrestador,
          ),

          const SizedBox(height: 22),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 22),

          // Seguimiento del servicio
          if (estado == 'Cancelada') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE8E6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF87171)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: Color(0xFFC5221F),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Solicitud cancelada',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC5221F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Motivo: ${servicio['motivoCancelacion'] ?? 'No especificado.'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ColoresApp.grisOscuro,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _timeline(estado),
          ],

          const SizedBox(height: 24),

          // Indicador de procesamiento
          if (_procesando) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],

          // Acciones y mensajes contextuales según rol y estado
          if (esSolicitante && estado == 'Publicada')
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ColoresApp.verdeMenta,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: ColoresApp.verdeAzulado,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu solicitud está publicada y visible para prestadores de tu comunidad.',
                      style: TextStyle(
                        fontSize: 13,
                        color: ColoresApp.grisOscuro,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (esSolicitante && estado == 'Aceptada')
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF3F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    color: Color(0xFF315F7C),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Un prestador aceptó tu solicitud. El servicio está pendiente de inicio.',
                      style: TextStyle(
                        fontSize: 13,
                        color: ColoresApp.grisOscuro,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (esPrestador && estado == 'Aceptada')
            FilledButton.icon(
              onPressed: bloqueado
                  ? null
                  : () => _ejecutar(
                      'iniciar',
                      'Iniciar servicio',
                      '¿Confirmas que vas a comenzar a realizar este trabajo?',
                    ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar servicio'),
            ),

          if (esPrestador && estado == 'En Proceso' && !finalizacionSolicitada)
            FilledButton.icon(
              onPressed: bloqueado
                  ? null
                  : () => _ejecutar(
                      'finalizar',
                      'Solicitar finalización',
                      'Confirma que terminaste el trabajo. El solicitante revisará y confirmará la finalización.',
                    ),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Solicitar finalización'),
            ),

          if (esPrestador && estado == 'En Proceso' && finalizacionSolicitada)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFF92400E),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ya solicitaste la finalización. Esperando confirmación del solicitante.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (esSolicitante &&
              estado == 'En Proceso' &&
              !finalizacionSolicitada)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF3F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    color: Color(0xFF315F7C),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El prestador está realizando el servicio acordado.',
                      style: TextStyle(
                        fontSize: 13,
                        color: ColoresApp.grisOscuro,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (esSolicitante &&
              estado == 'En Proceso' &&
              finalizacionSolicitada) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.notification_important_rounded,
                    color: Color(0xFF92400E),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El prestador indicó que terminó el trabajo. Revisa el resultado antes de confirmar.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: bloqueado
                  ? null
                  : () => _ejecutar(
                      'confirmar',
                      'Confirmar finalización',
                      '¿Confirmas que el servicio fue realizado satisfactoriamente?',
                    ),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Confirmar finalización'),
            ),
          ],

          if (estado == 'Completada')
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF137333),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Este servicio fue completado satisfactoriamente.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF137333),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (puedeCancelar) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: bloqueado
                  ? null
                  : () => _ejecutar('cancelar', 'Cancelar servicio', ''),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancelar servicio'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.coral,
                side: const BorderSide(color: ColoresApp.coral),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_procesando,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _procesando
                ? null
                : () => Navigator.of(context).pop(_huboCambios),
          ),
          title: const Text('Detalle del servicio'),
          actions: [
            IconButton(
              onPressed: _cargando || _procesando ? null : () => _cargar(),
              tooltip: 'Actualizar servicio',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FondoHelpi(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_cargando && _servicio == null)
                      const Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_error != null) ...[
                      TarjetaHelpi(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: ColoresApp.coral),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _cargando || _procesando
                                  ? null
                                  : () => _cargar(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_servicio != null) _contenido(_servicio!),
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
