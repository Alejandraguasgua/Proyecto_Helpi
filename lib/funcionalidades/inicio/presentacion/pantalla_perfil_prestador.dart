import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../solicitudes/datos/repositorio_solicitudes.dart';

class PantallaPerfilPrestador extends StatefulWidget {
  const PantallaPerfilPrestador({
    super.key,
    required this.uidPrestador,
    this.perfilInicial,
  });

  final String uidPrestador;
  final Map<String, dynamic>? perfilInicial;

  @override
  State<PantallaPerfilPrestador> createState() =>
      _EstadoPantallaPerfilPrestador();
}

class _EstadoPantallaPerfilPrestador extends State<PantallaPerfilPrestador> {
  final _repositorio = RepositorioSolicitudes();
  final List<Map<String, dynamic>> _resenas = [];

  Map<String, dynamic>? _perfil;
  double? _promedio;
  int _totalCalificaciones = 0;
  String? _cursor;

  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _perfil = widget.perfilInicial != null
        ? Map<String, dynamic>.from(widget.perfilInicial!)
        : null;
    if (_perfil != null) {
      final prom = _perfil!['promedio'];
      if (prom is num) _promedio = prom.toDouble();
      final tot = _perfil!['totalCalificaciones'];
      if (tot is num) _totalCalificaciones = tot.toInt();
    }
    _cargar();
  }

  String _fecha(dynamic valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();
    if (fecha == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
  }

  Future<void> _cargar({bool mas = false}) async {
    if (mas && (_cargando || _cargandoMas || _cursor == null)) return;

    setState(() {
      _error = null;
      if (mas) {
        _cargandoMas = true;
      } else {
        _cargando = true;
        _resenas.clear();
        _cursor = null;
      }
    });

    try {
      if (!mas) {
        final perfilPublico = await _repositorio.obtenerPerfilPublico(
          widget.uidPrestador,
        );
        if (mounted && perfilPublico != null) {
          _perfil = perfilPublico;
        }
      }

      final pagina = await _repositorio.listarCalificacionesPerfil(
        widget.uidPrestador,
        cursor: mas ? _cursor : null,
      );

      if (!mounted) return;

      setState(() {
        final ids = _resenas.map((r) => r['id']).toSet();
        _resenas.addAll(pagina.datos.where((r) => ids.add(r['id'])));
        _promedio = pagina.promedio ?? _promedio;
        _totalCalificaciones = pagina.totalCalificaciones;
        _cursor = pagina.cursor;
        _cargando = false;
        _cargandoMas = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _cargando = false;
        _cargandoMas = false;
      });
    }
  }

  Widget _estrellas(int cantidad) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (indice) {
        final activa = indice < cantidad;
        return Icon(
          activa ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: activa ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
        );
      }),
    );
  }

  Widget _tarjetaResena(Map<String, dynamic> resena) {
    final autor = (resena['autorNombre'] ?? 'Solicitante').toString();
    final estrellas = (resena['estrellas'] as num?)?.toInt() ?? 5;
    final comentario = (resena['comentario'] ?? '').toString().trim();
    final tituloServicio = (resena['tituloSolicitud'] ?? '').toString().trim();
    final fecha = _fecha(resena['creada']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.grisClaro,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: ColoresApp.verdeMenta,
                child: Text(
                  autor.isNotEmpty ? autor[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.verdeAzulado,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      autor,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.azulMarino,
                      ),
                    ),
                    if (fecha.isNotEmpty)
                      Text(
                        fecha,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ColoresApp.grisOscuro,
                        ),
                      ),
                  ],
                ),
              ),
              _estrellas(estrellas),
            ],
          ),
          if (tituloServicio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Servicio: $tituloServicio',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColoresApp.verdeAzulado,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            comentario.isEmpty
                ? 'Calificación sin comentario escrito.'
                : comentario,
            style: TextStyle(
              fontSize: 13,
              fontStyle: comentario.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
              color: ColoresApp.grisOscuro,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = (_perfil?['nombre'] ?? 'Prestador de la comunidad')
        .toString();
    final ciudad = (_perfil?['ciudad'] ?? '').toString().trim();
    final sector = (_perfil?['sector'] ?? '').toString().trim();
    final presentacion = (_perfil?['presentacion'] ?? '').toString().trim();
    final habilidades = (_perfil?['habilidades'] ?? '').toString().trim();
    final disponibilidad = (_perfil?['disponibilidad'] ?? '').toString().trim();
    final categorias = _perfil?['categorias'];
    final listaCategorias = categorias is List
        ? categorias.map((c) => c.toString()).toList()
        : <String>[];

    final ubicacion = [
      if (sector.isNotEmpty) sector,
      if (ciudad.isNotEmpty) ciudad,
    ].join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del prestador'),
        actions: [
          IconButton(
            onPressed: (_cargando || _cargandoMas) ? null : () => _cargar(),
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FondoHelpi(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TarjetaHelpi(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor: ColoresApp.verdeMenta,
                              child: Text(
                                nombre.isNotEmpty
                                    ? nombre[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: ColoresApp.verdeAzulado,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            nombre,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (ubicacion.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: ColoresApp.verdeAzulado,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ubicacion,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: ColoresApp.grisOscuro,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: ColoresApp.verdeMenta,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Color(0xFFF59E0B),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _promedio != null
                                              ? _promedio!.toStringAsFixed(1)
                                              : '—',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: ColoresApp.azulMarino,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Promedio',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ColoresApp.grisOscuro,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 32,
                                  color: const Color(0xFFCBD5E1),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '$_totalCalificaciones',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: ColoresApp.azulMarino,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _totalCalificaciones == 1
                                          ? 'Calificación'
                                          : 'Calificaciones',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: ColoresApp.grisOscuro,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (presentacion.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Text(
                              'Sobre mí',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.verdeAzulado,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(presentacion),
                          ],
                          if (listaCategorias.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Categorías de ayuda',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.verdeAzulado,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: listaCategorias
                                  .map(
                                    (c) => Chip(
                                      label: Text(
                                        c,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: ColoresApp.grisClaro,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (habilidades.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Habilidades',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.verdeAzulado,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(habilidades),
                          ],
                          if (disponibilidad.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Disponibilidad',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.verdeAzulado,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(disponibilidad),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TarjetaHelpi(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Reseñas de la comunidad ($_totalCalificaciones)',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 14),
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: const TextStyle(color: ColoresApp.coral),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _cargar(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                          if (!_cargando && _error == null && _resenas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Aún no hay reseñas registradas para este prestador.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: ColoresApp.grisOscuro),
                              ),
                            ),
                          ..._resenas.map(_tarjetaResena),
                          if (_cargando || _cargandoMas)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          if (!_cargando &&
                              !_cargandoMas &&
                              _cursor != null &&
                              _error == null)
                            OutlinedButton.icon(
                              onPressed: () => _cargar(mas: true),
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text('Cargar más reseñas'),
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
}
