import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import 'pantalla_personalizar.dart';
import '../datos/repositorio_perfil.dart';
import 'pantalla_registro_completado.dart';

class PantallaDatos extends StatefulWidget {
  const PantallaDatos({super.key, required this.rol});

  final String rol;

  @override
  State<PantallaDatos> createState() => _EstadoPantallaDatos();
}

class _EstadoPantallaDatos extends State<PantallaDatos> {
  Map<String, dynamic>? _perfilPendiente;
  bool _procesando = false;

  final _formulario = GlobalKey<FormState>();

  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _ciudad = TextEditingController();
  final _sector = TextEditingController();
  final _habilidades = TextEditingController();

  final Set<String> _categoriasSeleccionadas = {};

  final _categorias = const [
    'Soporte técnico',
    'Tutorías',
    'Reparaciones',
    'Hogar',
    'Mascotas',
    'Mudanzas',
  ];

  bool get _esPrestador => widget.rol == 'prestador';

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _ciudad.dispose();
    _sector.dispose();
    _habilidades.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    if (_procesando) return;

    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) {
      return;
    }

    if (_esPrestador && _categoriasSeleccionadas.isEmpty) {
      aviso(context, 'Selecciona al menos una categoría de ayuda.');
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      final datos = <String, dynamic>{
        'rol': widget.rol,
        'nombre': _nombre.text.trim(),
        'telefono': '+593${_telefono.text.trim()}',
        'ciudad': _ciudad.text.trim(),
        'sector': _sector.text.trim(),
        'categorias': _categoriasSeleccionadas.toList(),
        'habilidades': _habilidades.text.trim(),

        // Solo se valida el formato; no se verifica por SMS.
        'telefonoVerificado': false,
      };

      Map<String, dynamic>? perfil;

      if (_perfilPendiente != null) {
        // Reutiliza la personalización si falló el guardado.
        perfil = {..._perfilPendiente!, ...datos};
      } else {
        perfil = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute<Map<String, dynamic>>(
            builder: (_) => PantallaPersonalizar(datos: datos),
          ),
        );
      }

      if (!mounted || perfil == null) return;

      final perfilFinal = perfil;
      _perfilPendiente = perfilFinal;

      await RepositorioPerfil().guardar(perfilFinal);

      if (!mounted) return;

      _perfilPendiente = null;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => PantallaRegistroCompletado(perfil: perfilFinal),
        ),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        aviso(
          context,
          'No pudimos guardar el perfil. '
          'Pulsa Continuar para intentar nuevamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Widget _campo({
    required String etiqueta,
    required String pista,
    required TextEditingController controlador,
    required IconData icono,
    int minimo = 2,
    int maximo = 80,
    int lineas = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: controlador,
            maxLength: maximo,
            maxLines: lineas,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: pista,
              prefixIcon: Icon(icono),
              counterText: '',
            ),
            validator: (valor) {
              if ((valor?.trim().length ?? 0) < minimo) {
                return 'Escribe al menos $minimo caracteres.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crea tu perfil')),
      body: FondoHelpi(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Chip(label: Text('Paso 1 de 2')),
                      ),
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(
                        value: 0.5,
                        minHeight: 5,
                        backgroundColor: Color(0xFFDCE8EB),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '¡Empecemos!',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _esPrestador
                            ? 'Cuéntanos quién eres y qué ayuda '
                                'puedes ofrecer.'
                            : 'Completa tus datos básicos para '
                                'participar en la comunidad.',
                      ),
                      const SizedBox(height: 26),
                      _campo(
                        etiqueta: 'Nombre completo',
                        pista: 'Ej. Camila Morales',
                        controlador: _nombre,
                        icono: Icons.person_outline,
                        minimo: 3,
                      ),
                      Text(
                        'Número de teléfono',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _telefono,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        maxLength: 9,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(9),
                        ],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          hintText: '991234567',
                          counterText: '',
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(left: 12, right: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_outlined),
                                SizedBox(width: 10),
                                Text(
                                  '+593',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: ColoresApp.azulMarino,
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                        validator: (valor) {
                          final telefono = valor?.trim() ?? '';

                          if (telefono.isEmpty) {
                            return 'Escribe tu número de celular.';
                          }

                          if (!RegExp(r'^9[0-9]{8}$').hasMatch(telefono)) {
                            return 'Ingresa 9 dígitos empezando por 9, sin el 0.';
                          }

                          return null;
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 20),
                        child: Text(
                          'Escribe tu celular sin el 0 inicial. '
                          'El +593 se agrega automáticamente.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      _campo(
                        etiqueta: 'Ciudad',
                        pista: 'Ej. Riobamba',
                        controlador: _ciudad,
                        icono: Icons.location_city_outlined,
                      ),
                      _campo(
                        etiqueta: 'Sector aproximado',
                        pista: 'Ej. Sector ESPOCH',
                        controlador: _sector,
                        icono: Icons.location_on_outlined,
                        minimo: 3,
                        maximo: 100,
                      ),
                      if (_esPrestador) ...[
                        Text(
                          '¿En qué puedes ayudar?',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('Selecciona una o varias categorías.'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categorias.map((categoria) {
                            return FilterChip(
                              label: Text(categoria),
                              selected: _categoriasSeleccionadas.contains(
                                categoria,
                              ),
                              selectedColor: ColoresApp.verdeMenta,
                              onSelected: (seleccionada) {
                                setState(() {
                                  if (seleccionada) {
                                    _categoriasSeleccionadas.add(categoria);
                                  } else {
                                    _categoriasSeleccionadas.remove(categoria);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        _campo(
                          etiqueta: 'Describe tus habilidades',
                          pista: 'Ej. Instalo programas y configuro '
                              'computadoras.',
                          controlador: _habilidades,
                          icono: Icons.handyman_outlined,
                          minimo: 15,
                          maximo: 500,
                          lineas: 4,
                        ),
                      ],
                      TarjetaHelpi(
                        color: ColoresApp.verdeMenta,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              color: ColoresApp.verdeAzulado,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _esPrestador
                                    ? 'Rol seleccionado: Quiero ayudar'
                                    : 'Rol seleccionado: Necesito ayuda',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _procesando ? null : _continuar,
                        child: Text(
                          _procesando ? 'Procesando…' : 'Continuar',
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Usa datos ficticios durante esta demostración.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const EtiquetaDemo(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
