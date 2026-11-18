import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../bienvenida/presentacion/pantalla_bienvenida.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../datos/repositorio_admin.dart';

class PantallaAdmin extends StatefulWidget {
  const PantallaAdmin({super.key});

  @override
  State<PantallaAdmin> createState() => _EstadoPantallaAdmin();
}

class _EstadoPantallaAdmin extends State<PantallaAdmin> {
  final _repo = RepositorioAdmin();

  late final Future<bool> _permiso = _repo.esAdministrador();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _permiso,
      builder: (context, instantanea) {
        if (instantanea.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (instantanea.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Administración')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No tienes permiso para ver este panel.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Panel de administración'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    final navegador = Navigator.of(context);
                    await FirebaseAuth.instance.signOut();
                    navegador.pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const PantallaBienvenida(),
                      ),
                      (_) => false,
                    );
                  },
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelColor: ColoresApp.verdeAzulado,
                indicatorColor: ColoresApp.verdeAzulado,
                tabs: [
                  Tab(icon: Icon(Icons.dashboard_outlined), text: 'Resumen'),
                  Tab(icon: Icon(Icons.people_outline), text: 'Usuarios'),
                  Tab(icon: Icon(Icons.work_outline), text: 'Solicitudes'),
                  Tab(icon: Icon(Icons.flag_outlined), text: 'Reportes'),
                  Tab(icon: Icon(Icons.history), text: 'Historial'),
                ],
              ),
            ),
            body: FondoHelpi(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: TabBarView(
                      children: [
                        _Resumen(repo: _repo),
                        _ListaUsuarios(repo: _repo),
                        _ListaSolicitudes(repo: _repo),
                        _ListaReportes(repo: _repo),
                        _Historial(repo: _repo),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Utilidades
// -----------------------------------------------------------------------------

DateTime? _leerFecha(Object? valor) {
  if (valor == null) return null;
  if (valor is Timestamp) return valor.toDate();
  return DateTime.tryParse(valor.toString());
}

String _formatoFecha(Object? valor) {
  final fecha = _leerFecha(valor)?.toLocal();
  if (fecha == null) return '';

  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}

String _mensajeError(Object error) {
  final texto = error.toString().replaceFirst('Exception: ', '').trim();
  return texto.isEmpty ? 'No se pudo completar la acción.' : texto;
}

String _nombre(Map<String, dynamic> usuario) {
  final nombre = '${usuario['nombre'] ?? ''}'.trim();
  return nombre.isEmpty ? 'Sin nombre' : nombre;
}

/// Texto del estado de suspensión, o null si la cuenta está activa.
String? _textoSuspension(Map<String, dynamic> usuario) {
  if (!RepositorioAdmin.estaSuspendido(usuario)) return null;

  final hasta = RepositorioAdmin.suspendidoHasta(usuario);
  return hasta == null
      ? 'SUSPENDIDO · indefinido'
      : 'SUSPENDIDO hasta ${_formatoFecha(hasta)}';
}

class _Insignia extends StatelessWidget {
  const _Insignia(this.texto, {this.color = ColoresApp.verdeAzulado});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MensajeConReintento extends StatelessWidget {
  const _MensajeConReintento({required this.mensaje, required this.alReintentar});

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: alReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String accion = 'Confirmar',
  bool peligrosa = false,
}) async {
  final respuesta = await showDialog<bool>(
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
          style: peligrosa
              ? FilledButton.styleFrom(backgroundColor: ColoresApp.coral)
              : null,
          onPressed: () => Navigator.pop(dialogo, true),
          child: Text(accion),
        ),
      ],
    ),
  );

  return respuesta == true;
}

/// Pide un texto (motivo, nota o mensaje). Devuelve null si se cancela.
Future<String?> _pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String? descripcion,
  String accion = 'Aceptar',
  bool obligatorio = false,
  int minimo = 0,
  bool peligrosa = false,
}) {
  final controlador = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogo) => StatefulBuilder(
      builder: (dialogo, actualizar) {
        final largo = controlador.text.trim().length;
        final valido = obligatorio ? largo >= minimo : (largo == 0 || largo >= 3);

        return AlertDialog(
          title: Text(titulo),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (descripcion != null) ...[
                  Text(descripcion),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controlador,
                  autofocus: true,
                  maxLength: obligatorio ? 500 : 300,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: etiqueta,
                    helperText: obligatorio
                        ? 'Mínimo $minimo caracteres.'
                        : 'Opcional (mínimo 3 caracteres si lo escribes).',
                  ),
                  onChanged: (_) => actualizar(() {}),
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
              style: peligrosa
                  ? FilledButton.styleFrom(backgroundColor: ColoresApp.coral)
                  : null,
              onPressed: valido
                  ? () => Navigator.pop(dialogo, controlador.text.trim())
                  : null,
              child: Text(accion),
            ),
          ],
        );
      },
    ),
  );
}

class _OpcionSuspension {
  const _OpcionSuspension(this.etiqueta, this.dias);

  final String etiqueta;
  final int? dias;
}

class _ResultadoSuspension {
  const _ResultadoSuspension(this.dias, this.motivo);

  final int? dias;
  final String motivo;
}

const _opcionesSuspension = [
  _OpcionSuspension('1 día', 1),
  _OpcionSuspension('3 días', 3),
  _OpcionSuspension('7 días', 7),
  _OpcionSuspension('15 días', 15),
  _OpcionSuspension('30 días', 30),
  _OpcionSuspension('Indefinida', null),
];

Future<_ResultadoSuspension?> _pedirSuspension(
  BuildContext context,
  String nombre,
) {
  final controlador = TextEditingController();
  var seleccion = 2; // 7 días por defecto

  return showDialog<_ResultadoSuspension>(
    context: context,
    builder: (dialogo) => StatefulBuilder(
      builder: (dialogo, actualizar) {
        final opcion = _opcionesSuspension[seleccion];
        final largoMotivo = controlador.text.trim().length;
        final motivoValido = largoMotivo == 0 || largoMotivo >= 3;

        return AlertDialog(
          title: Text('Suspender a $nombre'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Por cuánto tiempo?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _opcionesSuspension.length; i++)
                      ChoiceChip(
                        label: Text(_opcionesSuspension[i].etiqueta),
                        selected: seleccion == i,
                        selectedColor: ColoresApp.verdeMenta,
                        onSelected: (_) => actualizar(() => seleccion = i),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  opcion.dias == null
                      ? 'No podrá usar la app hasta que un administrador la reactive.'
                      : 'Podrá volver a usar la app el '
                            '${_formatoFecha(DateTime.now().add(Duration(days: opcion.dias!)))}.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controlador,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional)',
                    helperText: 'El usuario lo verá al intentar entrar.',
                  ),
                  onChanged: (_) => actualizar(() {}),
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
              onPressed: motivoValido
                  ? () => Navigator.pop(
                      dialogo,
                      _ResultadoSuspension(
                        opcion.dias,
                        controlador.text.trim(),
                      ),
                    )
                  : null,
              child: const Text('Suspender'),
            ),
          ],
        );
      },
    ),
  );
}

/// Acciones sobre un usuario. Devuelven true si se hizo el cambio.
class _AccionesUsuario {
  const _AccionesUsuario(this.repo);

  final RepositorioAdmin repo;

  Future<bool> suspender(BuildContext context, String uid, String nombre) async {
    final resultado = await _pedirSuspension(context, nombre);
    if (resultado == null || !context.mounted) return false;

    return _ejecutar(
      context,
      () => repo.suspenderUsuario(
        uid,
        dias: resultado.dias,
        motivo: resultado.motivo,
      ),
      resultado.dias == null
          ? '$nombre quedó suspendido indefinidamente.'
          : '$nombre quedó suspendido por ${resultado.dias} día(s).',
    );
  }

  Future<bool> reactivar(BuildContext context, String uid, String nombre) async {
    final ok = await _confirmar(
      context,
      titulo: 'Reactivar usuario',
      mensaje: '¿Quitar la suspensión de $nombre? Podrá volver a usar la app.',
      accion: 'Reactivar',
    );
    if (!ok || !context.mounted) return false;

    return _ejecutar(
      context,
      () => repo.reactivarUsuario(uid),
      '$nombre fue reactivado.',
    );
  }

  Future<bool> advertir(BuildContext context, String uid, String nombre) async {
    final mensaje = await _pedirTexto(
      context,
      titulo: 'Enviar advertencia a $nombre',
      descripcion: 'Le llegará en Notificaciones como "Aviso del equipo de Helpi".',
      etiqueta: 'Mensaje',
      accion: 'Enviar',
      obligatorio: true,
      minimo: 5,
    );
    if (mensaje == null || !context.mounted) return false;

    return _ejecutar(
      context,
      () => repo.enviarAviso(uid, mensaje),
      'Aviso enviado a $nombre.',
    );
  }

  Future<bool> cambiarAdmin(
    BuildContext context,
    String uid,
    String nombre, {
    required bool darPermiso,
  }) async {
    final ok = await _confirmar(
      context,
      titulo: darPermiso ? 'Dar permiso de administrador' : 'Quitar permiso de administrador',
      mensaje: darPermiso
          ? '$nombre podrá entrar a este panel y suspender usuarios o eliminar solicitudes. '
                'Debe cerrar sesión y volver a entrar para verlo.'
          : '$nombre ya no podrá entrar al panel de administración.',
      accion: darPermiso ? 'Dar permiso' : 'Quitar permiso',
      peligrosa: !darPermiso,
    );
    if (!ok || !context.mounted) return false;

    return _ejecutar(
      context,
      () => repo.cambiarAdministrador(uid, darPermiso),
      darPermiso
          ? '$nombre ahora es administrador.'
          : '$nombre ya no es administrador.',
    );
  }

  Future<bool> _ejecutar(
    BuildContext context,
    Future<void> Function() accion,
    String mensajeExito,
  ) async {
    try {
      await accion();
      if (context.mounted) aviso(context, mensajeExito);
      return true;
    } catch (error) {
      if (context.mounted) aviso(context, _mensajeError(error));
      return false;
    }
  }
}

// -----------------------------------------------------------------------------
// Resumen
// -----------------------------------------------------------------------------

class _Resumen extends StatelessWidget {
  const _Resumen({required this.repo});

  final RepositorioAdmin repo;

  Widget _dato(String titulo, Future<int> futuro, IconData icono) {
    return SizedBox(
      width: 200,
      child: TarjetaHelpi(
        child: FutureBuilder<int>(
          future: futuro,
          builder: (context, instantanea) {
            final texto = instantanea.hasError
                ? '—'
                : instantanea.hasData
                ? '${instantanea.data}'
                : '…';

            return Column(
              children: [
                Icon(icono, color: ColoresApp.verdeAzulado, size: 30),
                const SizedBox(height: 8),
                Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.azulMarino,
                  ),
                ),
                Text(titulo, textAlign: TextAlign.center),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _dato('Usuarios', repo.contar('usuarios'), Icons.people_outline),
          _dato(
            'Prestadores',
            repo.contar('usuarios', campo: 'rol', valor: 'prestador'),
            Icons.volunteer_activism_outlined,
          ),
          _dato(
            'Suspendidos',
            repo.contar('usuarios', campo: 'suspendido', valor: true),
            Icons.block,
          ),
          _dato(
            'Administradores',
            repo.contar('usuarios', campo: 'esAdmin', valor: true),
            Icons.admin_panel_settings_outlined,
          ),
          _dato('Solicitudes', repo.contar('solicitudes'), Icons.list_alt),
          _dato(
            'Publicadas',
            repo.contar('solicitudes', campo: 'estado', valor: 'Publicada'),
            Icons.campaign_outlined,
          ),
          _dato(
            'En proceso',
            repo.contar('solicitudes', campo: 'estado', valor: 'En Proceso'),
            Icons.engineering_outlined,
          ),
          _dato(
            'Completadas',
            repo.contar('solicitudes', campo: 'estado', valor: 'Completada'),
            Icons.verified_outlined,
          ),
          _dato(
            'Canceladas',
            repo.contar('solicitudes', campo: 'estado', valor: 'Cancelada'),
            Icons.cancel_outlined,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Usuarios
// -----------------------------------------------------------------------------

class _ListaUsuarios extends StatefulWidget {
  const _ListaUsuarios({required this.repo});

  final RepositorioAdmin repo;

  @override
  State<_ListaUsuarios> createState() => _EstadoListaUsuarios();
}

class _EstadoListaUsuarios extends State<_ListaUsuarios> {
  static const _filtros = [
    'Todos',
    'Solicitantes',
    'Prestadores',
    'Suspendidos',
    'Con reportes',
    'Administradores',
  ];

  late final Stream<List<Map<String, dynamic>>> _flujo = widget.repo.usuarios();

  String _texto = '';
  String _filtro = 'Todos';

  bool _pasaFiltro(Map<String, dynamic> u) {
    switch (_filtro) {
      case 'Solicitantes':
        return u['rol'] == 'solicitante';
      case 'Prestadores':
        return u['rol'] == 'prestador';
      case 'Suspendidos':
        return RepositorioAdmin.estaSuspendido(u);
      case 'Con reportes':
        return ((u['reportesActivos'] as num?) ?? 0) > 0;
      case 'Administradores':
        return u['esAdmin'] == true;
      default:
        return true;
    }
  }

  void _abrirDetalle(Map<String, dynamic> usuario) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleUsuario(repo: widget.repo, usuario: usuario),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, correo, teléfono o ciudad',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (valor) =>
                setState(() => _texto = valor.trim().toLowerCase()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              for (final filtro in _filtros)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filtro),
                    selected: _filtro == filtro,
                    selectedColor: ColoresApp.verdeMenta,
                    onSelected: (_) => setState(() => _filtro = filtro),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _flujo,
            builder: (context, instantanea) {
              if (instantanea.hasError) {
                return const Center(
                  child: Text('No se pudieron cargar los usuarios.'),
                );
              }
              if (!instantanea.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final lista = instantanea.data!.where((u) {
                final contenido =
                    '${u['nombre']} ${u['correo']} ${u['telefono']} ${u['ciudad']}'
                        .toLowerCase();
                return contenido.contains(_texto) && _pasaFiltro(u);
              }).toList()
                ..sort(
                  (a, b) => _nombre(a).toLowerCase().compareTo(
                    _nombre(b).toLowerCase(),
                  ),
                );

              if (lista.isEmpty) {
                return const Center(child: Text('Sin resultados.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final u = lista[i];
                  final suspension = _textoSuspension(u);
                  final reportes = (u['reportesActivos'] as num?)?.toInt() ?? 0;

                  return InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _abrirDetalle(u),
                    child: TarjetaHelpi(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: suspension != null
                                ? ColoresApp.coral.withValues(alpha: 0.15)
                                : ColoresApp.verdeMenta,
                            child: Icon(
                              suspension != null
                                  ? Icons.block
                                  : u['rol'] == 'prestador'
                                  ? Icons.volunteer_activism_outlined
                                  : Icons.person_outline,
                              color: suspension != null
                                  ? ColoresApp.coral
                                  : ColoresApp.verdeAzulado,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nombre(u),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: ColoresApp.azulMarino,
                                  ),
                                ),
                                Text('${u['correo'] ?? ''}'),
                                Text(
                                  '${u['rol'] ?? ''} · ${u['ciudad'] ?? ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (suspension != null ||
                                    reportes > 0 ||
                                    u['esAdmin'] == true) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (suspension != null)
                                        _Insignia(
                                          suspension,
                                          color: ColoresApp.coral,
                                        ),
                                      if (reportes > 0)
                                        _Insignia(
                                          '$reportes reporte(s)',
                                          color: Colors.orange.shade800,
                                        ),
                                      if (u['esAdmin'] == true)
                                        const _Insignia('ADMIN'),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DetalleUsuario extends StatelessWidget {
  const _DetalleUsuario({required this.repo, required this.usuario});

  final RepositorioAdmin repo;
  final Map<String, dynamic> usuario;

  Widget _fila(String etiqueta, String valor) {
    if (valor.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: ColoresApp.grisOscuro,
              ),
            ),
          ),
          Expanded(child: SelectableText(valor)),
        ],
      ),
    );
  }

  Future<void> _hacer(
    BuildContext context,
    Future<bool> Function(BuildContext) accion,
  ) async {
    final navegador = Navigator.of(context);
    final hecho = await accion(context);
    if (hecho) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final uid = '${usuario['uid'] ?? ''}';
    final nombre = _nombre(usuario);
    final suspendido = RepositorioAdmin.estaSuspendido(usuario);
    final hasta = RepositorioAdmin.suspendidoHasta(usuario);
    final esAdmin = usuario['esAdmin'] == true;
    final esYo = uid == repo.uidActual;
    final acciones = _AccionesUsuario(repo);

    final categorias = usuario['categorias'];
    final promedio = usuario['promedio'];
    final total = (usuario['totalCalificaciones'] as num?)?.toInt() ?? 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              nombre,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ColoresApp.azulMarino,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                if (suspendido)
                  _Insignia(_textoSuspension(usuario)!, color: ColoresApp.coral)
                else
                  const _Insignia('ACTIVO'),
                if (esAdmin) const _Insignia('ADMIN'),
                if (esYo) const _Insignia('TÚ', color: ColoresApp.azulMarino),
              ],
            ),
            const SizedBox(height: 16),
            _fila('Correo', '${usuario['correo'] ?? ''}'),
            _fila('Teléfono', '${usuario['telefono'] ?? ''}'),
            _fila('Rol', '${usuario['rol'] ?? ''}'),
            _fila(
              'Ubicación',
              [usuario['ciudad'], usuario['sector']]
                  .where((v) => v != null && '$v'.trim().isNotEmpty)
                  .join(' · '),
            ),
            _fila(
              'Categorías',
              categorias is List ? categorias.join(', ') : '${categorias ?? ''}',
            ),
            _fila(
              'Calificación',
              promedio is num
                  ? '${promedio.toStringAsFixed(1)} ★ ($total reseña(s))'
                  : 'Sin calificaciones',
            ),
            _fila('Reportes activos', '${usuario['reportesActivos'] ?? 0}'),
            _fila('Términos aceptados', _formatoFecha(
              (usuario['terminosAceptados'] is Map)
                  ? (usuario['terminosAceptados'] as Map)['fechaAceptacion']
                  : null,
            )),
            if (suspendido) ...[
              _fila(
                'Suspendido hasta',
                hasta == null ? 'Indefinido' : _formatoFecha(hasta),
              ),
              _fila('Motivo', '${usuario['motivoSuspension'] ?? ''}'),
              _fila('Suspendido el', _formatoFecha(usuario['suspendidoEn'])),
            ],
            _fila('UID', uid),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            if (esYo)
              const Text(
                'Esta es tu cuenta: no puedes suspenderte ni quitarte el permiso.',
                style: TextStyle(fontSize: 13),
              )
            else ...[
              if (suspendido)
                FilledButton.icon(
                  onPressed: () => _hacer(
                    context,
                    (c) => acciones.reactivar(c, uid, nombre),
                  ),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Reactivar cuenta'),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresApp.coral,
                  ),
                  onPressed: () => _hacer(
                    context,
                    (c) => acciones.suspender(c, uid, nombre),
                  ),
                  icon: const Icon(Icons.block),
                  label: const Text('Suspender (temporal o indefinida)'),
                ),
              const SizedBox(height: 10),
              if (suspendido)
                OutlinedButton.icon(
                  onPressed: () => _hacer(
                    context,
                    (c) => acciones.suspender(c, uid, nombre),
                  ),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Cambiar duración de la suspensión'),
                ),
              if (suspendido) const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _hacer(
                  context,
                  (c) => acciones.advertir(c, uid, nombre),
                ),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Enviar advertencia'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _hacer(
                  context,
                  (c) => acciones.cambiarAdmin(
                    c,
                    uid,
                    nombre,
                    darPermiso: !esAdmin,
                  ),
                ),
                icon: Icon(
                  esAdmin
                      ? Icons.remove_moderator_outlined
                      : Icons.admin_panel_settings_outlined,
                ),
                label: Text(
                  esAdmin
                      ? 'Quitar permiso de administrador'
                      : 'Dar permiso de administrador',
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: uid));
                aviso(context, 'UID copiado.');
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar UID'),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Solicitudes
// -----------------------------------------------------------------------------

class _ListaSolicitudes extends StatefulWidget {
  const _ListaSolicitudes({required this.repo});

  final RepositorioAdmin repo;

  @override
  State<_ListaSolicitudes> createState() => _EstadoListaSolicitudes();
}

class _EstadoListaSolicitudes extends State<_ListaSolicitudes> {
  static const _estados = [
    'Todas',
    'Publicada',
    'Aceptada',
    'En Proceso',
    'Completada',
    'Cancelada',
  ];

  late final Stream<List<Map<String, dynamic>>> _flujo =
      widget.repo.solicitudes();

  String _estado = 'Todas';
  String _texto = '';

  Future<void> _retirar(Map<String, dynamic> solicitud) async {
    final ok = await _confirmar(
      context,
      titulo: 'Retirar solicitud',
      mensaje:
          '¿Retirar "${solicitud['titulo'] ?? 'esta solicitud'}"? '
          'Quedará como Cancelada y seguirá guardada.',
      accion: 'Retirar',
    );
    if (!ok) return;

    try {
      await widget.repo.retirarSolicitud(solicitud['id'] as String);
      if (mounted) aviso(context, 'Solicitud retirada (Cancelada).');
    } catch (error) {
      if (mounted) aviso(context, _mensajeError(error));
    }
  }

  Future<void> _eliminar(Map<String, dynamic> solicitud) async {
    final titulo = '${solicitud['titulo'] ?? 'esta solicitud'}';

    final motivo = await _pedirTexto(
      context,
      titulo: 'Eliminar definitivamente',
      descripcion:
          'Se borrará "$titulo" de la base de datos junto con sus '
          'calificaciones y notificaciones. Esta acción NO se puede deshacer.\n\n'
          'Los participantes recibirán un aviso.',
      etiqueta: 'Motivo (opcional)',
      accion: 'Eliminar',
      peligrosa: true,
    );
    if (motivo == null) return;

    try {
      await widget.repo.eliminarSolicitud(
        solicitud['id'] as String,
        motivo: motivo,
      );
      if (mounted) aviso(context, 'Solicitud eliminada de la base de datos.');
    } catch (error) {
      if (mounted) aviso(context, _mensajeError(error));
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Completada':
        return Colors.green.shade700;
      case 'Cancelada':
        return ColoresApp.coral;
      case 'En Proceso':
      case 'Aceptada':
        return Colors.orange.shade800;
      default:
        return ColoresApp.verdeAzulado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por título, categoría o ciudad',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (valor) =>
                setState(() => _texto = valor.trim().toLowerCase()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              for (final estado in _estados)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(estado),
                    selected: _estado == estado,
                    selectedColor: ColoresApp.verdeMenta,
                    onSelected: (_) => setState(() => _estado = estado),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _flujo,
            builder: (context, instantanea) {
              if (instantanea.hasError) {
                return const Center(
                  child: Text(
                    'No se pudieron cargar las solicitudes.\n'
                    'Revisa que existan en Firestore y las reglas.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (!instantanea.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final lista = instantanea.data!.where((s) {
                final estado = s['estado'] ?? 'Publicada';
                final contenido =
                    '${s['titulo']} ${s['categoria']} ${s['ciudad']} ${s['sector']}'
                        .toLowerCase();
                return (_estado == 'Todas' || estado == _estado) &&
                    contenido.contains(_texto);
              }).toList()
                ..sort(
                  (a, b) => '${b['creada'] ?? ''}'.compareTo('${a['creada'] ?? ''}'),
                );

              if (lista.isEmpty) {
                return const Center(child: Text('Sin solicitudes.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = lista[i];
                  final estado = '${s['estado'] ?? 'Publicada'}';
                  final centavos = (s['montoCentavos'] as num?) ?? 0;
                  final sePuedeRetirar =
                      estado != 'Cancelada' && estado != 'Completada';

                  return TarjetaHelpi(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s['titulo'] ?? 'Solicitud'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ColoresApp.azulMarino,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s['categoria'] ?? ''} · '
                                '${s['ciudad'] ?? ''} · ${s['sector'] ?? ''}',
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _Insignia(
                                    estado.toUpperCase(),
                                    color: _colorEstado(estado),
                                  ),
                                  Text(
                                    'USD ${(centavos / 100).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: ColoresApp.verdeAzulado,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (s['retiradaPorAdmin'] == true)
                                    const _Insignia(
                                      'RETIRADA POR ADMIN',
                                      color: ColoresApp.grisOscuro,
                                    ),
                                ],
                              ),
                              if (_formatoFecha(s['creada']).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Creada: ${_formatoFecha(s['creada'])}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Acciones',
                          onSelected: (opcion) {
                            if (opcion == 'retirar') _retirar(s);
                            if (opcion == 'eliminar') _eliminar(s);
                          },
                          itemBuilder: (_) => [
                            if (sePuedeRetirar)
                              const PopupMenuItem(
                                value: 'retirar',
                                child: ListTile(
                                  leading: Icon(Icons.block),
                                  title: Text('Retirar'),
                                  subtitle: Text('Queda como Cancelada'),
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'eliminar',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_forever,
                                  color: ColoresApp.coral,
                                ),
                                title: Text(
                                  'Eliminar definitivamente',
                                  style: TextStyle(color: ColoresApp.coral),
                                ),
                                subtitle: Text('Se borra de la base de datos'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Reportes
// -----------------------------------------------------------------------------

class _ListaReportes extends StatefulWidget {
  const _ListaReportes({required this.repo});

  final RepositorioAdmin repo;

  @override
  State<_ListaReportes> createState() => _EstadoListaReportes();
}

class _EstadoListaReportes extends State<_ListaReportes> {
  static const _estados = {
    'abierto': 'Abiertos',
    'resuelto': 'Resueltos',
    'descartado': 'Descartados',
  };

  String _estado = 'abierto';
  late Future<List<Map<String, dynamic>>> _futuro = widget.repo.reportes(
    estado: _estado,
  );

  void _recargar() {
    setState(() => _futuro = widget.repo.reportes(estado: _estado));
  }

  Future<void> _atender(Map<String, dynamic> reporte, String estado) async {
    final nota = await _pedirTexto(
      context,
      titulo: estado == 'resuelto' ? 'Marcar como resuelto' : 'Descartar reporte',
      descripcion: estado == 'resuelto'
          ? 'El reporte se cierra y se descuenta de los reportes activos del usuario.'
          : 'El reporte se considera sin fundamento y se descuenta de los reportes activos.',
      etiqueta: 'Nota interna (opcional)',
      accion: estado == 'resuelto' ? 'Resolver' : 'Descartar',
    );
    if (nota == null) return;

    try {
      await widget.repo.atenderReporte(
        '${reporte['id']}',
        estado,
        nota: nota,
      );
      if (!mounted) return;
      aviso(
        context,
        estado == 'resuelto' ? 'Reporte resuelto.' : 'Reporte descartado.',
      );
      _recargar();
    } catch (error) {
      if (mounted) aviso(context, _mensajeError(error));
    }
  }

  Future<void> _suspenderReportado(Map<String, dynamic> reporte) async {
    final uid = '${reporte['destinoUid'] ?? ''}';
    if (uid.isEmpty) return;

    await _AccionesUsuario(widget.repo).suspender(
      context,
      uid,
      '${reporte['destinoNombre'] ?? 'el usuario reportado'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final entrada in _estados.entries)
                      ChoiceChip(
                        label: Text(entrada.value),
                        selected: _estado == entrada.key,
                        selectedColor: ColoresApp.verdeMenta,
                        onSelected: (_) {
                          _estado = entrada.key;
                          _recargar();
                        },
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _recargar,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _futuro,
            builder: (context, instantanea) {
              if (instantanea.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (instantanea.hasError) {
                return _MensajeConReintento(
                  mensaje: _mensajeError(instantanea.error!),
                  alReintentar: _recargar,
                );
              }

              final lista = instantanea.data ?? [];

              if (lista.isEmpty) {
                return Center(
                  child: Text(
                    'No hay reportes ${_estados[_estado]!.toLowerCase()}.',
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _recargar(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: lista.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = lista[i];
                    final abierto = r['estado'] == 'abierto';

                    return TarjetaHelpi(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r['motivo'] ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.azulMarino,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reportado: ${r['destinoNombre'] ?? r['destinoUid'] ?? ''}',
                          ),
                          Text('Por: ${r['autorNombre'] ?? r['autorUid'] ?? ''}'),
                          Text(
                            _formatoFecha(r['creada']),
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (!abierto) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Atendido el ${_formatoFecha(r['atendidoEn'])}'
                              '${(r['nota'] ?? '').toString().isNotEmpty ? ' · ${r['nota']}' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (abierto) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _suspenderReportado(r),
                                  icon: const Icon(Icons.block, size: 18),
                                  label: const Text('Suspender reportado'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _atender(r, 'descartado'),
                                  child: const Text('Descartar'),
                                ),
                                FilledButton(
                                  onPressed: () => _atender(r, 'resuelto'),
                                  child: const Text('Resolver'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Historial de acciones de administradores
// -----------------------------------------------------------------------------

class _Historial extends StatefulWidget {
  const _Historial({required this.repo});

  final RepositorioAdmin repo;

  @override
  State<_Historial> createState() => _EstadoHistorial();
}

class _EstadoHistorial extends State<_Historial> {
  late Future<List<Map<String, dynamic>>> _futuro = widget.repo.historial();

  void _recargar() {
    setState(() => _futuro = widget.repo.historial());
  }

  static IconData _icono(String? accion) {
    switch (accion) {
      case 'suspension_temporal':
        return Icons.timer_outlined;
      case 'suspension_indefinida':
        return Icons.block;
      case 'reactivacion':
        return Icons.lock_open;
      case 'aviso_enviado':
        return Icons.campaign_outlined;
      case 'admin_otorgado':
        return Icons.admin_panel_settings_outlined;
      case 'admin_retirado':
        return Icons.remove_moderator_outlined;
      case 'solicitud_retirada':
        return Icons.cancel_outlined;
      case 'solicitud_eliminada':
        return Icons.delete_forever;
      case 'reporte_resuelto':
        return Icons.task_alt;
      case 'reporte_descartado':
        return Icons.flag_outlined;
      default:
        return Icons.history;
    }
  }

  static String _describir(Map<String, dynamic> a) {
    final detalle = a['detalle'] is Map
        ? Map<String, dynamic>.from(a['detalle'] as Map)
        : <String, dynamic>{};
    final nombre = detalle['nombre'] ?? a['objetivoId'] ?? '';
    final titulo = detalle['titulo'] ?? a['objetivoId'] ?? '';
    final motivo = (detalle['motivo'] ?? '').toString();
    final conMotivo = motivo.isNotEmpty ? ' · Motivo: $motivo' : '';

    switch (a['accion']) {
      case 'suspension_temporal':
        return 'Suspendió a $nombre por ${detalle['dias']} día(s)$conMotivo';
      case 'suspension_indefinida':
        return 'Suspendió a $nombre indefinidamente$conMotivo';
      case 'reactivacion':
        return 'Reactivó a $nombre';
      case 'aviso_enviado':
        return 'Envió un aviso a $nombre: "${detalle['mensaje'] ?? ''}"';
      case 'admin_otorgado':
        return 'Dio permiso de administrador a $nombre';
      case 'admin_retirado':
        return 'Quitó el permiso de administrador a $nombre';
      case 'solicitud_retirada':
        return 'Retiró la solicitud "$titulo"';
      case 'solicitud_eliminada':
        return 'Eliminó la solicitud "$titulo"$conMotivo';
      case 'reporte_resuelto':
        return 'Resolvió un reporte$conMotivo';
      case 'reporte_descartado':
        return 'Descartó un reporte$conMotivo';
      default:
        return '${a['accion'] ?? 'Acción'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futuro,
      builder: (context, instantanea) {
        if (instantanea.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (instantanea.hasError) {
          return _MensajeConReintento(
            mensaje: _mensajeError(instantanea.error!),
            alReintentar: _recargar,
          );
        }

        final lista = instantanea.data ?? [];

        return RefreshIndicator(
          onRefresh: () async => _recargar(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lista.isEmpty ? 1 : lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'Todavía no hay acciones registradas.\n'
                    'Aquí aparecerá cada suspensión, aviso o eliminación.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final a = lista[i];

              return TarjetaHelpi(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icono(a['accion']?.toString()),
                        color: ColoresApp.verdeAzulado),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _describir(a),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ColoresApp.azulMarino,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${a['adminCorreo'] ?? a['adminUid'] ?? ''} · '
                            '${_formatoFecha(a['creada'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
