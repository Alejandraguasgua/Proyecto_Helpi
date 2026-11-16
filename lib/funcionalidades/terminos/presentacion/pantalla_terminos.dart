import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../nucleo/componentes/componentes_helpi.dart';
import '../../../nucleo/tema/colores_app.dart';
import '../../bienvenida/presentacion/pantalla_bienvenida.dart';
import '../../inicio/presentacion/pantalla_inicio.dart';
import '../../registro/datos/repositorio_perfil.dart';
import '../../registro/presentacion/pantalla_registro_completado.dart';
import '../datos/contenido_terminos.dart';

enum ModoTerminos {
  /// Durante el registro de nuevo usuario.
  registro,

  /// Para cuenta existente que requiere aceptar la versión vigente para continuar.
  obligatorio,

  /// Solo para lectura y consulta, sin requerir aceptación.
  consulta,
}

class PantallaTerminos extends StatefulWidget {
  const PantallaTerminos({
    super.key,
    required this.modo,
    this.perfil,
    this.pestanaInicial = 0,
    this.retornarAlAceptar = false,
  });

  final ModoTerminos modo;
  final Map<String, dynamic>? perfil;
  final int pestanaInicial;
  final bool retornarAlAceptar;

  @override
  State<PantallaTerminos> createState() => _EstadoPantallaTerminos();
}

class _EstadoPantallaTerminos extends State<PantallaTerminos> {
  final _repositorioPerfil = RepositorioPerfil();

  late int _pestanaActiva;
  bool _acepto = false;
  bool _procesando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pestanaActiva = widget.pestanaInicial;
  }

  bool get _esConsulta => widget.modo == ModoTerminos.consulta;

  Future<void> _cerrarSesionYSair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Salir de HELPI'),
        content: const Text(
          'Puedes cerrar sesión en este momento sin perder tu cuenta ni tus datos. '
          'Para acceder a las funciones principales deberás aceptar los Términos y condiciones vigentes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const PantallaBienvenida()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        aviso(context, 'No pudimos cerrar sesión. Inténtalo nuevamente.');
      }
    }
  }

  Future<void> _aceptarYContinuar() async {
    if (_procesando || !_acepto) return;

    setState(() {
      _procesando = true;
      _error = null;
    });

    try {
      if (widget.modo == ModoTerminos.registro) {
        final perfilBase = widget.perfil ?? {};
        final perfilFinal = Map<String, dynamic>.from(perfilBase);

        // 1. Guarda el perfil completo en Firestore
        await _repositorioPerfil.guardar(perfilFinal);

        // 2. Registra la aceptación oficial en el backend y en usuarios/{uid}
        final aceptacion = await _repositorioPerfil.registrarAceptacionTerminos(
          versionTerminos: versionTerminosVigente,
          versionPrivacidad: versionPrivacidadVigente,
        );

        // 3. Relee el perfil desde Firestore para conservar el estado real
        final perfilLeido = await _repositorioPerfil.leer();
        final perfilCombinado = <String, dynamic>{
          ...perfilFinal,
          ...?perfilLeido,
          'terminosAceptados': perfilLeido?['terminosAceptados'] ?? aceptacion,
        };

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => PantallaRegistroCompletado(perfil: perfilCombinado),
          ),
          (_) => false,
        );
      } else if (widget.modo == ModoTerminos.obligatorio) {
        // Registra aceptación para usuario existente asociada a su UID autenticado
        final aceptacion = await _repositorioPerfil.registrarAceptacionTerminos(
          versionTerminos: versionTerminosVigente,
          versionPrivacidad: versionPrivacidadVigente,
        );

        final perfilLeido = await _repositorioPerfil.leer();
        final perfilActualizado = <String, dynamic>{
          ...(widget.perfil ?? {}),
          ...?perfilLeido,
          'terminosAceptados': perfilLeido?['terminosAceptados'] ?? aceptacion,
        };

        if (!mounted) return;

        aviso(context, 'Términos y condiciones aceptados correctamente.');

        if (widget.retornarAlAceptar && Navigator.of(context).canPop()) {
          Navigator.of(context).pop<Map<String, dynamic>>(perfilActualizado);
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => PantallaInicio(perfil: perfilActualizado),
          ),
          (_) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;

      final mensaje = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = mensaje.isNotEmpty ? mensaje : 'No pudimos registrar tu aceptación. Revisa tu conexión e intenta de nuevo.';
      });

      aviso(context, _error!);
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Widget _selectorDocumento() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _botonPestana(
              titulo: 'Términos y condiciones',
              icono: Icons.description_outlined,
              activo: _pestanaActiva == 0,
              alPresionar: () => setState(() => _pestanaActiva = 0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _botonPestana(
              titulo: 'Política de privacidad',
              icono: Icons.privacy_tip_outlined,
              activo: _pestanaActiva == 1,
              alPresionar: () => setState(() => _pestanaActiva = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonPestana({
    required String titulo,
    required IconData icono,
    required bool activo,
    required VoidCallback alPresionar,
  }) {
    return Material(
      color: activo ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: activo ? 1 : 0,
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icono,
                size: 16,
                color: activo ? ColoresApp.verdeAzulado : ColoresApp.grisOscuro,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  titulo,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    color: activo
                        ? ColoresApp.verdeAzulado
                        : ColoresApp.grisOscuro,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaSeccion(SeccionLegal seccion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0615324F),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: ColoresApp.verdeMenta,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    seccion.numero,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.verdeAzulado,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  seccion.titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.azulMarino,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            seccion.contenido,
            style: const TextStyle(
              fontSize: 13,
              color: ColoresApp.grisOscuro,
              height: 1.5,
            ),
          ),
          if (seccion.puntos != null && seccion.puntos!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...seccion.puntos!.map(
              (punto) => Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: ColoresApp.verdeAzulado,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        punto,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColoresApp.grisOscuro,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (seccion.datosPendientes != null &&
              seccion.datosPendientes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...seccion.datosPendientes!.map(
              (dato) => Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions_outlined,
                      size: 14,
                      color: Color(0xFF92400E),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dato,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panelAceptacion() {
    return TarjetaHelpi(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acepto,
                activeColor: ColoresApp.verdeAzulado,
                onChanged: _procesando
                    ? null
                    : (valor) => setState(() => _acepto = valor ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _procesando
                      ? null
                      : () => setState(() => _acepto = !_acepto),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'He leído y acepto los Términos y condiciones',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.azulMarino,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ColoresApp.grisClaro,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.privacy_tip_outlined,
                      size: 16,
                      color: ColoresApp.verdeAzulado,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Información sobre el tratamiento de datos personales (Aviso de privacidad v1.0).',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.azulMarino,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _pestanaActiva = 1),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Consultar aviso',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Los permisos del dispositivo (como ubicación GPS) son opcionales e independientes de esta aceptación.',
                  style: TextStyle(fontSize: 11, color: ColoresApp.grisOscuro),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE8E6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: ColoresApp.coral),
              ),
            ),
          ],
          FilledButton.icon(
            onPressed: (_acepto && !_procesando) ? _aceptarYContinuar : null,
            icon: _procesando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _procesando ? 'Guardando aceptación…' : 'Aceptar y continuar',
            ),
          ),
          const SizedBox(height: 8),
          if (widget.modo == ModoTerminos.registro)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _procesando ? null : () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _procesando ? null : _cerrarSesionYSair,
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Salir'),
                ),
              ],
            )
          else if (widget.modo == ModoTerminos.obligatorio)
            TextButton.icon(
              onPressed: _procesando ? null : _cerrarSesionYSair,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Salir y cerrar sesión'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secciones = _pestanaActiva == 0
        ? seccionesTerminos
        : seccionesPrivacidad;
    final tituloDocumento = _pestanaActiva == 0
        ? 'Términos y condiciones'
        : 'Aviso de privacidad';
    final version = _pestanaActiva == 0
        ? versionTerminosVigente
        : versionPrivacidadVigente;

    return PopScope(
      canPop: !_procesando && _esConsulta,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _procesando
                ? null
                : () {
                    if (widget.modo == ModoTerminos.obligatorio) {
                      _cerrarSesionYSair();
                    } else {
                      Navigator.pop(context);
                    }
                  },
          ),
          title: Text(tituloDocumento),
          actions: [
            if (widget.modo == ModoTerminos.obligatorio)
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Cerrar sesión',
                onPressed: _procesando ? null : _cerrarSesionYSair,
              ),
          ],
        ),
        body: FondoHelpi(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_esConsulta) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ColoresApp.verdeMenta,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: ColoresApp.verdeAzulado,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Modo de consulta · No requiere confirmación adicional.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ColoresApp.verdeAzulado,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (widget.modo == ModoTerminos.obligatorio) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ColoresApp.verdeMenta,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.gavel_rounded,
                                color: ColoresApp.verdeAzulado,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hay una versión vigente pendiente de aceptación. '
                                  'Revisa y acepta los Términos y condiciones y la Política de privacidad para continuar.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ColoresApp.azulMarino,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          notaBorradorLegal,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF92400E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      _selectorDocumento(),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const LogoHelpi(tamano: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tituloDocumento,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Versión $version · Vigente desde $fechaVigenciaDocumentos',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ColoresApp.grisOscuro,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...secciones.map(_tarjetaSeccion),
                      const SizedBox(height: 16),
                      if (!_esConsulta) ...[
                        _panelAceptacion(),
                        const SizedBox(height: 24),
                      ],
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
