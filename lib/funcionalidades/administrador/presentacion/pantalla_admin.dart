import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
          length: 4,
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
                labelColor: ColoresApp.verdeAzulado,
                indicatorColor: ColoresApp.verdeAzulado,
                tabs: [
                  Tab(icon: Icon(Icons.dashboard_outlined), text: 'Resumen'),
                  Tab(icon: Icon(Icons.people_outline), text: 'Usuarios'),
                  Tab(icon: Icon(Icons.work_outline), text: 'Solicitudes'),
                  Tab(icon: Icon(Icons.flag_outlined), text: 'Reportes'),
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

class _ListaUsuarios extends StatefulWidget {
  const _ListaUsuarios({required this.repo});

  final RepositorioAdmin repo;

  @override
  State<_ListaUsuarios> createState() => _EstadoListaUsuarios();
}

class _EstadoListaUsuarios extends State<_ListaUsuarios> {
  String _texto = '';

  Future<void> _alternar(Map<String, dynamic> usuario) async {
    final suspendido = usuario['suspendido'] == true;
    final nombre = '${usuario['nombre'] ?? 'este usuario'}';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(suspendido ? 'Reactivar usuario' : 'Suspender usuario'),
        content: Text(
          suspendido
              ? '¿Reactivar a $nombre?'
              : '¿Suspender a $nombre? No podrá operar en la plataforma.',
        ),
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

    if (confirmar != true) return;

    try {
      await widget.repo.suspenderUsuario(usuario['uid'] as String, !suspendido);
    } catch (_) {
      if (mounted) aviso(context, 'No se pudo actualizar el usuario.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, correo o ciudad',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (valor) =>
                setState(() => _texto = valor.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.repo.usuarios(),
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
                final contenido = '${u['nombre']} ${u['correo']} ${u['ciudad']}'
                    .toLowerCase();
                return contenido.contains(_texto);
              }).toList();

              if (lista.isEmpty) {
                return const Center(child: Text('Sin resultados.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final u = lista[i];
                  final suspendido = u['suspendido'] == true;

                  return TarjetaHelpi(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: ColoresApp.verdeMenta,
                          child: Icon(
                            u['rol'] == 'prestador'
                                ? Icons.volunteer_activism_outlined
                                : Icons.person_outline,
                            color: ColoresApp.verdeAzulado,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${u['nombre'] ?? 'Sin nombre'}',
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
                              if (suspendido)
                                const Text(
                                  'SUSPENDIDO',
                                  style: TextStyle(
                                    color: ColoresApp.coral,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _alternar(u),
                          child: Text(suspendido ? 'Reactivar' : 'Suspender'),
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

  String _estado = 'Todas';

  Future<void> _retirar(Map<String, dynamic> solicitud) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Retirar solicitud'),
        content: Text(
          '¿Retirar "${solicitud['titulo'] ?? 'esta solicitud'}"? '
          'Quedará como Cancelada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await widget.repo.retirarSolicitud(solicitud['id'] as String);
    } catch (error) {
      if (!mounted) return;
      aviso(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: _estados.map((estado) {
              return ChoiceChip(
                label: Text(estado),
                selected: _estado == estado,
                selectedColor: ColoresApp.verdeMenta,
                onSelected: (_) => setState(() => _estado = estado),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.repo.solicitudes(),
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

              final lista = instantanea.data!
                  .where((s) => _estado == 'Todas' || s['estado'] == _estado)
                  .toList();

              if (lista.isEmpty) {
                return const Center(child: Text('Sin solicitudes.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = lista[i];
                  final centavos = (s['montoCentavos'] as num?) ?? 0;

                  return TarjetaHelpi(
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
                        Text(
                          'Estado: ${s['estado'] ?? 'Publicada'} · '
                          'USD ${(centavos / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: ColoresApp.verdeAzulado,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (s['estado'] != 'Cancelada' &&
                            s['estado'] != 'Completada')
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _retirar(s),
                              icon: const Icon(Icons.block, size: 18),
                              label: const Text('Retirar'),
                            ),
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

class _ListaReportes extends StatefulWidget {
  const _ListaReportes({required this.repo});

  final RepositorioAdmin repo;

  @override
  State<_ListaReportes> createState() => _EstadoListaReportes();
}

class _EstadoListaReportes extends State<_ListaReportes> {
  late Future<List<Map<String, dynamic>>> _futuro = widget.repo.reportes();

  void _recargar() {
    setState(() => _futuro = widget.repo.reportes());
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${instantanea.error}'.replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _recargar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final lista = instantanea.data ?? [];

        if (lista.isEmpty) {
          return const Center(child: Text('No hay reportes abiertos.'));
        }

        return RefreshIndicator(
          onRefresh: () async => _recargar(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = lista[i];

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
                    const SizedBox(height: 4),
                    Text('Reportado: ${r['destinoUid'] ?? ''}'),
                    Text('Por: ${r['autorUid'] ?? ''}'),
                    Text(
                      '${r['creada'] ?? ''}',
                      style: const TextStyle(fontSize: 12),
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
