'use strict';

const { randomUUID } = require('node:crypto');

class ErrorHelpi extends Error {
  constructor(estado, mensaje) {
    super(mensaje);
    this.estado = estado;
  }
}

function exigir(condicion, mensaje, estado = 400) {
  if (!condicion) {
    throw new ErrorHelpi(estado, mensaje);
  }
}

function texto(valor, nombre, minimo = 1, maximo = 500) {
  exigir(
    typeof valor === 'string',
    `${nombre} debe ser texto.`,
  );

  const limpio = valor.trim();

  exigir(
    limpio.length >= minimo && limpio.length <= maximo,
    `${nombre}: escribe entre ${minimo} y ${maximo} caracteres.`,
  );

  return limpio;
}

const categorias = [
  'Soporte técnico',
  'Tutorías',
  'Reparaciones',
  'Hogar',
  'Mascotas',
  'Mudanzas',
];

const estadosSolicitud = [
  'Publicada',
  'Aceptada',
  'En Proceso',
  'Completada',
  'Cancelada',
];

function normalizarTextoBusqueda(valor) {
  return String(valor || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

const VERSION_TERMINOS_VIGENTE = 'v1.0';
const VERSION_PRIVACIDAD_VIGENTE = 'v1.0';
const FECHA_VIGENCIA_DOCUMENTOS = '2026-11-11';
const DOCUMENTO_TERMINOS_ID = 'terminos_condiciones_helpi';
const DOCUMENTO_PRIVACIDAD_ID = 'aviso_privacidad_helpi';
const IDS_DOCUMENTO_TERMINOS_VALIDOS = new Set([
  DOCUMENTO_TERMINOS_ID,
  'terminos_y_privacidad_helpi',
]);

function tieneAceptacionVigente(perfil, uidEsperado = null) {
  if (!perfil || typeof perfil !== 'object') {
    return false;
  }

  const aceptacion = perfil.terminosAceptados;

  if (!aceptacion || typeof aceptacion !== 'object') {
    return false;
  }

  const uidObjetivo = uidEsperado || perfil.uid || null;

  if (
    uidObjetivo &&
    typeof aceptacion.uid === 'string' &&
    aceptacion.uid.trim() !== '' &&
    aceptacion.uid !== uidObjetivo
  ) {
    return false;
  }

  const documentoValido =
    aceptacion.documentoId == null ||
    IDS_DOCUMENTO_TERMINOS_VALIDOS.has(aceptacion.documentoId);

  const fechaValida =
    (typeof aceptacion.fechaAceptacion === 'string' &&
      aceptacion.fechaAceptacion.trim().length > 0) ||
    typeof aceptacion.fechaAceptacion?.toDate === 'function';

  return Boolean(
    documentoValido &&
      aceptacion.versionTerminos ===
        VERSION_TERMINOS_VIGENTE &&
      aceptacion.versionPrivacidad ===
        VERSION_PRIVACIDAD_VIGENTE &&
      fechaValida,
  );
}

/**
 * Indica si una cuenta está suspendida en este momento.
 * La suspensión puede ser indefinida (sin `suspendidoHasta`) o temporal
 * (con `suspendidoHasta` en formato ISO); al vencer la fecha deja de contar.
 */
function estaSuspendido(perfil, ahora = new Date()) {
  if (!perfil || perfil.suspendido !== true) return false;

  const hasta = perfil.suspendidoHasta;
  if (!hasta) return true;

  const fin = new Date(hasta);
  if (Number.isNaN(fin.getTime())) return true;

  return fin.getTime() > ahora.getTime();
}

const MILISEGUNDOS_POR_DIA = 24 * 60 * 60 * 1000;
const ESTADOS_REPORTE_ATENDIDO = new Set(['resuelto', 'descartado']);

function coordenadas(valor) {
  exigir(
    valor &&
      Number.isFinite(valor.latitud) &&
      Number.isFinite(valor.longitud),
    'Coordenadas inválidas.',
  );

  exigir(
    Math.abs(valor.latitud) <= 90 &&
      Math.abs(valor.longitud) <= 180,
    'Coordenadas fuera de rango.',
  );

  return {
    latitud: valor.latitud,
    longitud: valor.longitud,
  };
}

function validarSolicitud(datos, ahora = new Date()) {
  exigir(
    datos && typeof datos === 'object',
    'Faltan los datos de la solicitud.',
  );

  exigir(
    categorias.includes(datos.categoria),
    'Selecciona una categoría válida.',
  );

  exigir(
    Number.isSafeInteger(datos.montoCentavos) &&
      datos.montoCentavos >= 100 &&
      datos.montoCentavos <= 1000000,
    'El monto debe estar entre USD 1 y USD 10.000.',
  );

  const fecha = new Date(datos.fechaServicio);

  exigir(
    Number.isFinite(fecha.getTime()) && fecha > ahora,
    'Selecciona una fecha futura.',
  );

  const tituloLimpio = texto(datos.titulo, 'Título', 5, 100);
  const ciudadLimpia = texto(datos.ciudad, 'Ciudad', 2, 80);

  return {
    titulo: tituloLimpio,
    tituloNormalizado: normalizarTextoBusqueda(tituloLimpio),

    descripcion: texto(
      datos.descripcion,
      'Descripción',
      15,
      1000,
    ),

    categoria: datos.categoria,
    ciudad: ciudadLimpia,
    ciudadNormalizada: normalizarTextoBusqueda(ciudadLimpia),
    sector: texto(datos.sector, 'Sector', 2, 100),
    horario: texto(datos.horario, 'Horario', 3, 100),

    fechaServicio: fecha.toISOString(),
    montoCentavos: datos.montoCentavos,
    ubicacion: coordenadas(datos.ubicacion),
  };
}

function distanciaKm(origen, destino) {
  const radianes = (valor) => (valor * Math.PI) / 180;

  const diferenciaLatitud = radianes(
    destino.latitud - origen.latitud,
  );

  const diferenciaLongitud = radianes(
    destino.longitud - origen.longitud,
  );

  const valor =
    Math.sin(diferenciaLatitud / 2) ** 2 +
    Math.cos(radianes(origen.latitud)) *
      Math.cos(radianes(destino.latitud)) *
      Math.sin(diferenciaLongitud / 2) ** 2;

  return (
    6371 *
    2 *
    Math.asin(Math.sqrt(Math.min(1, valor)))
  );
}

class ServicioHelpi {
  constructor(almacen, reloj = () => new Date()) {
    this.almacen = almacen;
    this.reloj = reloj;
  }

  async perfil(uid, { exigirTerminos = true } = {}) {
    const perfil = await this.almacen.get(`usuarios/${uid}`);

    exigir(
      perfil && perfil.perfilCompleto,
      'Completa tu perfil antes de continuar.',
      409,
    );

    exigir(
      !estaSuspendido(perfil, this.reloj()),
      'Esta cuenta está suspendida.',
      403,
    );

    if (exigirTerminos) {
      exigir(
        tieneAceptacionVigente(perfil, uid),
        'Debes aceptar los Términos y condiciones vigentes para continuar.',
        403,
      );
    }

    return perfil;
  }

  async actualizarPerfil(uid, datos = {}) {
    exigir(
      datos && typeof datos === 'object',
      'Faltan los datos del perfil.',
      400,
    );

    const fechaServidor = this.reloj().toISOString();

    return this.almacen.atomic(async (transaccion) => {
      const usuarioExistente =
        (await transaccion.get(`usuarios/${uid}`)) || {};

      exigir(
        !estaSuspendido(usuarioExistente, this.reloj()),
        'Esta cuenta está suspendida.',
        403,
      );

      const camposPermitidos = {};

      if (datos.rol !== undefined) {
        exigir(
          ['solicitante', 'prestador'].includes(datos.rol),
          'Selecciona un rol válido.',
          400,
        );
        camposPermitidos.rol = datos.rol;
      }

      if (datos.nombre !== undefined) {
        camposPermitidos.nombre = texto(
          datos.nombre,
          'Nombre',
          3,
          80,
        );
      }

      if (datos.telefono !== undefined) {
        const telLimpio = texto(
          datos.telefono,
          'Teléfono',
          8,
          20,
        );
        exigir(
          /^\+5939[0-9]{8}$/.test(telLimpio),
          'El teléfono debe tener formato +593 seguido de 9 dígitos que inicien en 9.',
          400,
        );
        camposPermitidos.telefono = telLimpio;
      }

      if (datos.ciudad !== undefined) {
        camposPermitidos.ciudad = texto(
          datos.ciudad,
          'Ciudad',
          2,
          80,
        );
      }

      if (datos.sector !== undefined) {
        camposPermitidos.sector = texto(
          datos.sector,
          'Sector',
          3,
          100,
        );
      }

      if (datos.presentacion !== undefined) {
        camposPermitidos.presentacion = texto(
          String(datos.presentacion ?? ''),
          'Presentación',
          0,
          300,
        );
      }

      if (datos.disponibilidad !== undefined) {
        camposPermitidos.disponibilidad = texto(
          String(datos.disponibilidad ?? ''),
          'Disponibilidad',
          0,
          150,
        );
      }

      if (datos.habilidades !== undefined) {
        camposPermitidos.habilidades = texto(
          String(datos.habilidades ?? ''),
          'Habilidades',
          0,
          500,
        );
      }

      if (Array.isArray(datos.categorias)) {
        camposPermitidos.categorias = datos.categorias.filter(
          (cat) => categorias.includes(cat),
        );
      }

      const actualizado = {
        ...usuarioExistente,
        ...camposPermitidos,
        uid,
        correo: usuarioExistente.correo ?? '',
        perfilCompleto:
          usuarioExistente.perfilCompleto ?? true,
        fechaActualizacion: fechaServidor,
      };

      if (usuarioExistente.terminosAceptados) {
        actualizado.terminosAceptados =
          usuarioExistente.terminosAceptados;
      }

      if (usuarioExistente.historialAceptacionesTerminos) {
        actualizado.historialAceptacionesTerminos =
          usuarioExistente.historialAceptacionesTerminos;
      }

      if (usuarioExistente.promedio !== undefined) {
        actualizado.promedio = usuarioExistente.promedio;
      }

      if (usuarioExistente.totalCalificaciones !== undefined) {
        actualizado.totalCalificaciones =
          usuarioExistente.totalCalificaciones;
      }

      if (usuarioExistente.sumaCalificaciones !== undefined) {
        actualizado.sumaCalificaciones =
          usuarioExistente.sumaCalificaciones;
      }

      transaccion.set(`usuarios/${uid}`, actualizado);

      return actualizado;
    });
  }

  terminosVigentes() {
    return {
      documentoId: DOCUMENTO_TERMINOS_ID,
      versionTerminos: VERSION_TERMINOS_VIGENTE,
      avisoPrivacidadId: DOCUMENTO_PRIVACIDAD_ID,
      versionPrivacidad: VERSION_PRIVACIDAD_VIGENTE,
      fechaVigencia: FECHA_VIGENCIA_DOCUMENTOS,
    };
  }

  async aceptarTerminos(uid, datos) {
    exigir(
      datos && typeof datos === 'object',
      'Faltan los datos de aceptación.',
    );

    exigir(
      datos.versionTerminos === VERSION_TERMINOS_VIGENTE,
      `La versión de Términos debe ser la vigente (${VERSION_TERMINOS_VIGENTE}).`,
      400,
    );

    exigir(
      datos.versionPrivacidad === VERSION_PRIVACIDAD_VIGENTE,
      `La versión del Aviso de privacidad debe ser la vigente (${VERSION_PRIVACIDAD_VIGENTE}).`,
      400,
    );

    const fechaServidor = this.reloj().toISOString();
    const idRegistro = randomUUID();

    const aceptacion = {
      id: idRegistro,
      uid,
      documentoId: DOCUMENTO_TERMINOS_ID,
      versionTerminos: datos.versionTerminos,
      avisoPrivacidadId: DOCUMENTO_PRIVACIDAD_ID,
      versionPrivacidad: datos.versionPrivacidad,
      fechaAceptacion: fechaServidor,
    };

    return this.almacen.atomic(async (transaccion) => {
      const usuarioExistente =
        (await transaccion.get(`usuarios/${uid}`)) || {};

      exigir(
        !estaSuspendido(usuarioExistente, this.reloj()),
        'Esta cuenta está suspendida.',
        403,
      );

      const versionDoc = await transaccion.get(
        `documentos_legales/${DOCUMENTO_TERMINOS_ID}_${VERSION_TERMINOS_VIGENTE}`,
      );

      if (!versionDoc) {
        transaccion.set(
          `documentos_legales/${DOCUMENTO_TERMINOS_ID}_${VERSION_TERMINOS_VIGENTE}`,
          {
            documentoId: DOCUMENTO_TERMINOS_ID,
            versionTerminos: VERSION_TERMINOS_VIGENTE,
            avisoPrivacidadId: DOCUMENTO_PRIVACIDAD_ID,
            versionPrivacidad: VERSION_PRIVACIDAD_VIGENTE,
            fechaVigencia: FECHA_VIGENCIA_DOCUMENTOS,
          },
        );
      }

      // Registra en el historial inmutable de aceptaciones de Firestore
      transaccion.set(
        `aceptaciones_terminos/${idRegistro}`,
        aceptacion,
      );

      const resumenAceptacion = {
        id: aceptacion.id,
        uid,
        documentoId: aceptacion.documentoId,
        versionTerminos: aceptacion.versionTerminos,
        avisoPrivacidadId: aceptacion.avisoPrivacidadId,
        versionPrivacidad: aceptacion.versionPrivacidad,
        fechaAceptacion: aceptacion.fechaAceptacion,
      };

      const historialPrevio = Array.isArray(
        usuarioExistente.historialAceptacionesTerminos,
      )
        ? usuarioExistente.historialAceptacionesTerminos
        : [];

      // Actualiza la aceptación vigente y su historial en el perfil del usuario
      transaccion.set(`usuarios/${uid}`, {
        ...usuarioExistente,
        uid,
        terminosAceptados: resumenAceptacion,
        historialAceptacionesTerminos: [
          ...historialPrevio,
          resumenAceptacion,
        ],
        fechaActualizacion: fechaServidor,
      });

      return {
        correcto: true,
        datos: aceptacion,
      };
    });
  }

  async crear(uid, datos) {
    await this.perfil(uid);

    const campos = validarSolicitud(datos, this.reloj());
    let claveIdempotencia = null;

    if (
      datos.claveIdempotencia != null &&
      String(datos.claveIdempotencia).trim() !== ''
    ) {
      claveIdempotencia = String(datos.claveIdempotencia).trim();
      exigir(
        /^[A-Za-z0-9_-]{8,120}$/.test(claveIdempotencia),
        'La clave de idempotencia no es válida.',
        400,
      );
    }

    const ahoraIso = this.reloj().toISOString();

    if (claveIdempotencia) {
      const resultado = await this.almacen.atomic(async (transaccion) => {
        const rutaIdemp = `idempotencia_solicitudes/${uid}_crear_${claveIdempotencia}`;
        const previo = await transaccion.get(rutaIdemp);

        if (previo && previo.solicitudId) {
          const existente = await transaccion.get(
            `solicitudes/${previo.solicitudId}`,
          );
          if (existente) {
            return existente;
          }
        }

        const identificador = randomUUID();
        const solicitud = {
          ...campos,
          id: identificador,
          solicitanteUid: uid,
          prestadorUid: null,
          estado: 'Publicada',
          creada: ahoraIso,
          version: 1,
        };

        transaccion.set(`solicitudes/${identificador}`, solicitud);
        transaccion.set(rutaIdemp, {
          uid,
          operacion: 'crear',
          claveIdempotencia,
          solicitudId: identificador,
          creada: ahoraIso,
        });

        return solicitud;
      });
            if (resultado.creada === ahoraIso) {
              this.notificarPrestadoresZona(resultado).catch(() => {});
            }

            return resultado;
    }

    const identificador = randomUUID();

    const solicitud = {
      ...campos,
      id: identificador,
      solicitanteUid: uid,
      prestadorUid: null,
      estado: 'Publicada',
      creada: ahoraIso,
      version: 1,
    };

    await this.almacen.set(
      `solicitudes/${identificador}`,
      solicitud,
    );

    this.notificarPrestadoresZona(solicitud).catch(() => {});
    return solicitud;
  }

  async obtener(uid, identificador) {
    await this.perfil(uid);

    const solicitud = await this.almacen.get(
      `solicitudes/${identificador}`,
    );

    exigir(
      solicitud,
      'La solicitud no existe.',
      404,
    );

    exigir(
      solicitud.estado === 'Publicada' ||
        [
          solicitud.solicitanteUid,
          solicitud.prestadorUid,
        ].includes(uid),
      'No tienes acceso a esta solicitud.',
      403,
    );

    return solicitud;
  }

  async listar(uid, filtros = {}) {
    await this.perfil(uid);

    exigir(
      !(filtros.mias === 'true' && filtros.aceptadas === 'true'),
      'No puedes filtrar simultáneamente por solicitudes propias y aceptadas.',
      400,
    );

    let campo = 'estado';
    let valor = 'Publicada';

    if (filtros.mias === 'true') {
      campo = 'solicitanteUid';
      valor = uid;
    }

    if (filtros.aceptadas === 'true') {
      campo = 'prestadorUid';
      valor = uid;
    }

    let estadoFiltro = null;
    if (filtros.estado != null && String(filtros.estado).trim() !== '') {
      estadoFiltro = String(filtros.estado).trim();
      exigir(
        estadosSolicitud.includes(estadoFiltro),
        'Selecciona un estado válido.',
        400,
      );
    }

    let categoriaFiltro = null;
    if (filtros.categoria != null && String(filtros.categoria).trim() !== '') {
      categoriaFiltro = String(filtros.categoria).trim();
      exigir(
        categorias.includes(categoriaFiltro),
        'Selecciona una categoría válida.',
        400,
      );
    }

    let ciudadFiltro = null;
    if (filtros.ciudad != null && String(filtros.ciudad).trim() !== '') {
      ciudadFiltro = normalizarTextoBusqueda(
        texto(String(filtros.ciudad), 'Ciudad', 2, 80),
      );
    }

    let prefijoTitulo = '';
    if (filtros.busqueda != null && String(filtros.busqueda).trim() !== '') {
      const busquedaLimpia = texto(
        String(filtros.busqueda),
        'Búsqueda',
        1,
        100,
      );
      prefijoTitulo = normalizarTextoBusqueda(busquedaLimpia);
    }

    const orden =
      filtros.orden != null && String(filtros.orden).trim() !== ''
        ? String(filtros.orden).trim()
        : 'recientes';

    exigir(
      ['recientes', 'fecha_servicio'].includes(orden),
      'Selecciona un criterio de ordenamiento válido.',
      400,
    );

    const limite =
      filtros.limite != null ? Number(filtros.limite) : 20;

    exigir(
      Number.isInteger(limite) && limite >= 1 && limite <= 50,
      'El límite de paginación debe estar entre 1 y 50.',
      400,
    );

    let cursorOrden = null;
    let cursorId = null;

    if (filtros.cursor != null && String(filtros.cursor).trim() !== '') {
      const partes = String(filtros.cursor).split('|');
      exigir(
        partes.length === 2,
        'El cursor de paginación no es válido.',
        400,
      );

      [cursorOrden, cursorId] = partes;
      const fechaCursor = new Date(cursorOrden);

      exigir(
        Number.isFinite(fechaCursor.getTime()) &&
          /^[A-Za-z0-9_-]{1,150}$/.test(cursorId),
        'El cursor de paginación no es válido.',
        400,
      );
    }

    const punto =
      filtros.latitud != null
        ? coordenadas({
            latitud: Number(filtros.latitud),
            longitud: Number(filtros.longitud),
          })
        : null;

    const radio = Number(filtros.radio ?? 25);

    exigir(
      Number.isFinite(radio) && radio > 0 && radio <= 100,
      'El radio debe ser mayor de 0 y de hasta 100 km.',
    );

    const esMisServicios =
      campo === 'solicitanteUid' || campo === 'prestadorUid';

    if (
      esMisServicios &&
      !punto &&
      typeof this.almacen.listSolicitudes === 'function'
    ) {
      return this.almacen.listSolicitudes({
        campoPropietario: campo,
        uid,
        estado: estadoFiltro,
        categoria: categoriaFiltro,
        ciudadNormalizada: ciudadFiltro,
        prefijoTitulo,
        orden,
        cursorOrden,
        cursorId,
        limite,
      });
    }

    const pagina = await this.almacen.list(
      'solicitudes',
      campo,
      valor,
    );

    const ocultas =
      campo === 'estado'
        ? await this.almacen.list('ocultas', 'uid', uid)
        : { datos: [] };

    const identificadoresOcultos = new Set(
      ocultas.datos.map((elemento) => elemento.solicitudId),
    );

    // 1. Filtrar primero por todos los criterios combinados antes de ordenar y paginar
    const filtrados = pagina.datos
      .filter(
        (solicitud) =>
          campo !== 'estado' || solicitud.solicitanteUid !== uid,
      )
      .filter(
        (solicitud) =>
          !identificadoresOcultos.has(solicitud.id),
      )
      .filter(
        (solicitud) =>
          !estadoFiltro ||
          solicitud.estado === estadoFiltro,
      )
      .filter(
        (solicitud) =>
          !ciudadFiltro ||
          normalizarTextoBusqueda(
            solicitud.ciudadNormalizada || solicitud.ciudad,
          ) === ciudadFiltro,
      )
      .filter(
        (solicitud) =>
          !categoriaFiltro ||
          solicitud.categoria === categoriaFiltro,
      )
      .filter(
        (solicitud) =>
          !prefijoTitulo ||
          normalizarTextoBusqueda(
            solicitud.tituloNormalizado || solicitud.titulo,
          ).startsWith(prefijoTitulo),
      )
      .filter(
        (solicitud) =>
          campo !== 'estado' ||
          new Date(solicitud.fechaServicio) > this.reloj(),
      )
      .map((solicitud) => ({
        ...solicitud,
        distanciaKm: punto
          ? distanciaKm(punto, solicitud.ubicacion)
          : null,
      }))
      .filter(
        (solicitud) =>
          !punto || solicitud.distanciaKm <= radio,
      );

    // 2. Ordenar de forma determinística (fecha + id)
    filtrados.sort((primera, segunda) => {
      if (punto && !filtros.orden) {
        const difDistancia = primera.distanciaKm - segunda.distanciaKm;
        if (difDistancia !== 0) return difDistancia;
      }

      if (orden === 'fecha_servicio') {
        const cmpFecha = String(primera.fechaServicio || '').localeCompare(
          String(segunda.fechaServicio || ''),
        );
        if (cmpFecha !== 0) return cmpFecha;
        return String(primera.id || '').localeCompare(
          String(segunda.id || ''),
        );
      }

      const cmpCreada = String(segunda.creada || '').localeCompare(
        String(primera.creada || ''),
      );
      if (cmpCreada !== 0) return cmpCreada;
      return String(segunda.id || '').localeCompare(
        String(primera.id || ''),
      );
    });

    // 3. Aplicar cursor estable después de filtrar y ordenar
    const trasCursor = cursorOrden
      ? filtrados.filter((solicitud) => {
          if (orden === 'fecha_servicio') {
            return (
              solicitud.fechaServicio > cursorOrden ||
              (solicitud.fechaServicio === cursorOrden &&
                solicitud.id > cursorId)
            );
          }
          return (
            solicitud.creada < cursorOrden ||
            (solicitud.creada === cursorOrden &&
              solicitud.id < cursorId)
          );
        })
      : filtrados;

    const datos = trasCursor.slice(0, limite);
    const ultimo = datos.at(-1);
    const campoCursor =
      ultimo &&
      (orden === 'fecha_servicio'
        ? ultimo.fechaServicio
        : ultimo.creada);

    return {
      datos,
      siguienteCursor:
         datos.length === limite && ultimo
          ? `${campoCursor}|${ultimo.id}`
          : null,
    };
  }

  async editar(uid, identificador, datos) {
    await this.perfil(uid);

    exigir(
      datos && typeof datos === 'object',
      'Faltan los datos de la solicitud.',
      400,
    );

    exigir(
      Number.isInteger(datos.version) && datos.version >= 1,
      'Indica la versión actual de la solicitud.',
      400,
    );

    const campos = validarSolicitud(
      datos,
      this.reloj(),
    );

    const ahoraIso = this.reloj().toISOString();

    return this.almacen.atomic(async (transaccion) => {
      const solicitud = await transaccion.get(
        `solicitudes/${identificador}`,
      );

      exigir(
        solicitud,
        'La solicitud no existe.',
        404,
      );

      exigir(
        solicitud.solicitanteUid === uid,
        'Solo el solicitante puede editar.',
        403,
      );

      exigir(
        solicitud.estado === 'Publicada',
        'Solo puedes editar solicitudes publicadas. Es posible que ya haya sido aceptada.',
        409,
      );

      exigir(
        datos.version === solicitud.version,
        'La solicitud cambió. Actualiza antes de editar.',
        409,
      );

      // Conserva estrictamente los campos internos controlados por el servidor
      const actualizada = {
        id: solicitud.id,
        solicitanteUid: solicitud.solicitanteUid,
        prestadorUid: null,
        estado: 'Publicada',
        creada: solicitud.creada,
        ...campos,
        actualizada: ahoraIso,
        version: solicitud.version + 1,
      };

      transaccion.set(
        `solicitudes/${identificador}`,
        actualizada,
      );

      return actualizada;
    });
  }

  async cambiarEstado(
    uid,
    identificador,
    accion,
    motivo = '',
  ) {
    const perfil = await this.perfil(uid);

    return this.almacen.atomic(async (transaccion) => {
      const solicitud = await transaccion.get(
        `solicitudes/${identificador}`,
      );

      exigir(
        solicitud,
        'La solicitud no existe.',
        404,
      );

      const esSolicitante =
        solicitud.solicitanteUid === uid;

      const esPrestador =
        solicitud.prestadorUid === uid;

      const ahoraIso = this.reloj().toISOString();
      const nombreActor =
        (perfil.nombre || '').trim() ||
        (esPrestador ? 'El prestador' : 'El solicitante');
      const tituloServicio =
        (solicitud.titulo || '').trim() || 'Servicio';

      let estado;
      let tipoAviso;
      let tituloAviso;
      let mensajeAviso;

      if (accion === 'aceptar') {
        exigir(
          perfil.rol === 'prestador' && !esSolicitante,
          'Debes actuar como prestador de otra persona.',
          403,
        );

        exigir(
          solicitud.estado === 'Publicada' &&
            new Date(solicitud.fechaServicio) > this.reloj(),
          'La solicitud ya fue aceptada o expiró.',
          409,
        );

        const contraparte = await transaccion.get(
          `usuarios/${solicitud.solicitanteUid}`,
        );

        exigir(
          contraparte && !estaSuspendido(contraparte, this.reloj()),
          'El solicitante no está disponible.',
          409,
        );

        const primerBloqueo = await transaccion.get(
          `bloqueos/${uid}_${solicitud.solicitanteUid}`,
        );

        const segundoBloqueo = await transaccion.get(
          `bloqueos/${solicitud.solicitanteUid}_${uid}`,
        );

        exigir(
          !primerBloqueo && !segundoBloqueo,
          'No se puede aceptar esta solicitud.',
          403,
        );

        estado = 'Aceptada';
        tipoAviso = 'solicitud_aceptada';
        tituloAviso = 'Solicitud aceptada';
        mensajeAviso = `${nombreActor} aceptó tu solicitud "${tituloServicio}".`;
      } else if (accion === 'iniciar') {
        exigir(
          esPrestador && solicitud.estado === 'Aceptada',
          'No puedes iniciar este servicio.',
          409,
        );

        estado = 'En Proceso';
        tipoAviso = 'servicio_iniciado';
        tituloAviso = 'Servicio iniciado';
        mensajeAviso = `${nombreActor} inició el servicio "${tituloServicio}".`;
      } else if (accion === 'finalizar') {
        exigir(
          esPrestador && solicitud.estado === 'En Proceso',
          'No puedes solicitar la finalización.',
          409,
        );

        // Idempotencia: solicitar finalización nuevamente no incrementa versión ni genera otro aviso.
        if (solicitud.finalizacionSolicitada === true) {
          return solicitud;
        }

        estado = 'En Proceso';
        tipoAviso = 'finalizacion_solicitada';
        tituloAviso = 'Confirmación de finalización pendiente';
        mensajeAviso = `${nombreActor} solicitó confirmar la finalización de "${tituloServicio}".`;
      } else if (accion === 'confirmar') {
        exigir(
          esSolicitante &&
            solicitud.estado === 'En Proceso' &&
            solicitud.finalizacionSolicitada,
          'No se puede confirmar la finalización.',
          409,
        );

        estado = 'Completada';
        tipoAviso = 'servicio_completado';
        tituloAviso = 'Servicio completado';
        mensajeAviso = `${nombreActor} confirmó la finalización de "${tituloServicio}".`;
      } else if (accion === 'cancelar') {
        exigir(
          (esSolicitante || esPrestador) &&
            [
              'Publicada',
              'Aceptada',
              'En Proceso',
            ].includes(solicitud.estado),
          'No puedes cancelar este servicio.',
          409,
        );

        motivo = texto(
          motivo,
          'Motivo',
          5,
          300,
        );

        exigir(
          !solicitud.pagoId,
          'El servicio tiene un pago asociado. Debe resolverse mediante el flujo de pagos o reclamos.',
          409,
        );

        estado = 'Cancelada';
        tipoAviso = 'servicio_cancelado';
        tituloAviso = 'Servicio cancelado';
        mensajeAviso = `${nombreActor} canceló el servicio "${tituloServicio}". Motivo: ${motivo}`;
      } else {
        throw new ErrorHelpi(
          400,
          'La acción solicitada no es válida.',
        );
      }

      const actualizada = {
        ...solicitud,
        estado,
        version: solicitud.version + 1,
        actualizada: ahoraIso,
      };

      if (accion === 'aceptar') {
        actualizada.prestadorUid = uid;
      }

      if (accion === 'finalizar') {
        actualizada.finalizacionSolicitada = true;
      }

      if (motivo) {
        actualizada.motivoCancelacion = motivo;
      }

      const destinatarios = [
        ...new Set(
          [
            solicitud.solicitanteUid,
            actualizada.prestadorUid,
          ].filter(
            (destinatario) =>
              destinatario && destinatario !== uid,
          ),
        ),
      ];

           // Lectura previa en la transacción para evitar duplicados ante reintentos
           const avisosParaCrear = [];
           for (const destinatario of destinatarios) {
             const idAviso = `notif_${identificador}_${tipoAviso}_${destinatario}`;
             const existente = await transaccion.get(
               `notificaciones/${idAviso}`,
             );

             if (!existente) {
               avisosParaCrear.push({
                 id: idAviso,
                 uid: destinatario,
                 destinatarioUid: destinatario,
                 solicitudId: identificador,
                 servicioTitulo: tituloServicio,
                 tipo: tipoAviso,
                 titulo: tituloAviso,
                 mensaje: mensajeAviso,
                 leida: false,
                 fechaLectura: null,
                 creada: ahoraIso,
               });
             }
           }

           if (accion === 'confirmar') {
                          for (const destinatario of [solicitud.solicitanteUid]) {
               avisosParaCrear.push({
                 id: `notif_${identificador}_calificar_${destinatario}`,
                 uid: destinatario,
                 destinatarioUid: destinatario,
                 solicitudId: identificador,
                 servicioTitulo: tituloServicio,
                 tipo: 'calificar_servicio',
                 titulo: 'Califica tu experiencia',
                 mensaje: `¿Cómo te fue con "${tituloServicio}"? Deja tu calificación.`,
                 leida: false,
                 fechaLectura: null,
                 creada: ahoraIso,
               });
             }
           }

           transaccion.set(
             `solicitudes/${identificador}`,
             actualizada,
           );

           for (const aviso of avisosParaCrear) {
             transaccion.set(
               `notificaciones/${aviso.id}`,
               aviso,
             );
           }

           return actualizada;
    });
  }

  async listarNotificaciones(uid, cursor, limite = 20) {
    await this.perfil(uid);

    exigir(
      Number.isInteger(limite) && limite >= 1 && limite <= 50,
      'El límite de paginación no es válido.',
      400,
    );

    let cursorFecha = null;
    let cursorId = null;

    if (cursor != null && String(cursor).trim() !== '') {
      const partes = String(cursor).split('|');
      exigir(
        partes.length === 2,
        'El cursor de paginación no es válido.',
        400,
      );

      [cursorFecha, cursorId] = partes;
      const fechaParseada = new Date(cursorFecha);

      exigir(
        Number.isFinite(fechaParseada.getTime()) &&
          /^[A-Za-z0-9_-]{1,150}$/.test(cursorId),
        'El cursor de paginación no es válido.',
        400,
      );
    }

    if (typeof this.almacen.listNotificaciones === 'function') {
      return this.almacen.listNotificaciones(
        uid,
        cursorFecha ? `${cursorFecha}|${cursorId}` : undefined,
        limite,
      );
    }

    // Respaldo para almacenes que solo implementen list()
    const todos = await this.almacen.list(
      'notificaciones',
      'uid',
      uid,
    );

    const ordenados = [...todos.datos].sort((a, b) => {
      const cmpFecha = String(b.creada || '').localeCompare(
        String(a.creada || ''),
      );
      if (cmpFecha !== 0) return cmpFecha;
      return String(b.id || '').localeCompare(String(a.id || ''));
    });

    const filtradosCursor = cursorFecha
      ? ordenados.filter(
          (item) =>
            item.creada < cursorFecha ||
            (item.creada === cursorFecha && item.id < cursorId),
        )
      : ordenados;

    const datos = filtradosCursor.slice(0, limite);
    const ultimo = datos.at(-1);

    return {
      datos,
      siguienteCursor:
        datos.length === limite && ultimo
          ? `${ultimo.creada}|${ultimo.id}`
          : null,
    };
  }

  async marcarNotificacionLeida(uid, idNotificacion) {
    await this.perfil(uid);

    return this.almacen.atomic(async (transaccion) => {
      const notificacion = await transaccion.get(
        `notificaciones/${idNotificacion}`,
      );

      exigir(
        notificacion && notificacion.uid === uid,
        'La notificación no existe.',
        404,
      );

      if (notificacion.leida === true && notificacion.fechaLectura) {
        return {
          correcto: true,
          datos: notificacion,
        };
      }

      const actualizada = {
        ...notificacion,
        leida: true,
        fechaLectura:
          notificacion.fechaLectura ||
          this.reloj().toISOString(),
      };

      transaccion.set(
        `notificaciones/${idNotificacion}`,
        actualizada,
      );

      return {
        correcto: true,
        datos: actualizada,
      };
    });
  }

  async duplicar(uid, identificador, datos = {}) {
    await this.perfil(uid);

    exigir(
      datos && typeof datos === 'object',
      'Faltan los datos para duplicar la solicitud.',
      400,
    );

    exigir(
      typeof datos.fechaServicio === 'string' &&
        datos.fechaServicio.trim().length > 0,
      'Selecciona una fecha y hora futuras para la nueva solicitud.',
      400,
    );

    let claveIdempotencia = null;
    if (
      datos.claveIdempotencia != null &&
      String(datos.claveIdempotencia).trim() !== ''
    ) {
      claveIdempotencia = String(datos.claveIdempotencia).trim();
      exigir(
        /^[A-Za-z0-9_-]{8,120}$/.test(claveIdempotencia),
        'La clave de idempotencia no es válida.',
        400,
      );
    }

    const ahora = this.reloj();
    const ahoraIso = ahora.toISOString();

    return this.almacen.atomic(async (transaccion) => {
      const solicitud = await transaccion.get(
        `solicitudes/${identificador}`,
      );

      exigir(
        solicitud,
        'La solicitud no existe.',
        404,
      );

      exigir(
        solicitud.solicitanteUid === uid,
        'Solo puedes duplicar tus propias solicitudes.',
        403,
      );

      if (claveIdempotencia) {
        const rutaIdemp = `idempotencia_solicitudes/${uid}_duplicar_${identificador}_${claveIdempotencia}`;
        const previo = await transaccion.get(rutaIdemp);

        if (previo && previo.solicitudId) {
          const existente = await transaccion.get(
            `solicitudes/${previo.solicitudId}`,
          );
          if (existente) {
            return existente;
          }
        }
      }

      // Toma únicamente los campos descriptivos editables, nunca campos internos
      const borrador = {
        titulo: datos.titulo ?? solicitud.titulo,
        descripcion: datos.descripcion ?? solicitud.descripcion,
        categoria: datos.categoria ?? solicitud.categoria,
        ciudad: datos.ciudad ?? solicitud.ciudad,
        sector: datos.sector ?? solicitud.sector,
        horario: datos.horario ?? solicitud.horario,
        montoCentavos: datos.montoCentavos ?? solicitud.montoCentavos,
        ubicacion: datos.ubicacion ?? solicitud.ubicacion,
        fechaServicio: datos.fechaServicio,
      };

      const campos = validarSolicitud(borrador, ahora);
      const nuevoId = randomUUID();

      const nuevaSolicitud = {
        ...campos,
        id: nuevoId,
        solicitanteUid: uid,
        prestadorUid: null,
        estado: 'Publicada',
        creada: ahoraIso,
        version: 1,
      };

      transaccion.set(
        `solicitudes/${nuevoId}`,
        nuevaSolicitud,
      );

      if (claveIdempotencia) {
        transaccion.set(
          `idempotencia_solicitudes/${uid}_duplicar_${identificador}_${claveIdempotencia}`,
          {
            uid,
            operacion: 'duplicar',
            solicitudOrigenId: identificador,
            claveIdempotencia,
            solicitudId: nuevoId,
            creada: ahoraIso,
          },
        );
      }

      return nuevaSolicitud;
    });
  }

  async calificar(uid, identificador, datos = {}) {
    const perfilAutor = await this.perfil(uid);

    exigir(
      datos && typeof datos === 'object',
      'Faltan los datos de la calificación.',
      400,
    );

    exigir(
      Number.isInteger(datos.estrellas) &&
        datos.estrellas >= 1 &&
        datos.estrellas <= 5,
      'Selecciona entre 1 y 5 estrellas.',
      400,
    );

    const comentario = texto(
      String(datos.comentario ?? ''),
      'Comentario',
      0,
      500,
    );

    const ahoraIso = this.reloj().toISOString();

    return this.almacen.atomic(async (transaccion) => {
      const solicitud = await transaccion.get(
        `solicitudes/${identificador}`,
      );

      exigir(
        solicitud,
        'La solicitud no existe.',
        404,
      );

      exigir(
        solicitud.estado === 'Completada',
        'El servicio debe estar completado antes de poder calificarlo.',
        409,
      );

      exigir(
        solicitud.solicitanteUid === uid,
        'Solo la persona solicitante puede calificar al prestador del servicio.',
        403,
      );

      const destino = solicitud.prestadorUid;

      exigir(
        typeof destino === 'string' && destino.trim().length > 0,
        'Este servicio no tiene un prestador asignado.',
        409,
      );

      const clave = `calificaciones/${identificador}_${uid}`;
      const anterior = await transaccion.get(clave);

      exigir(
        !anterior && !solicitud.calificadaPorSolicitante,
        'Ya calificaste este servicio. Solo se permite una calificación por solicitud.',
        409,
      );

      const receptor = await transaccion.get(
        `usuarios/${destino}`,
      );

      exigir(
        receptor,
        'El perfil del prestador no existe.',
        404,
      );

      const nombreCompleto = String(
        perfilAutor?.nombre || 'Solicitante',
      ).trim();
      const autorNombre =
        nombreCompleto.split(/\s+/)[0] || 'Solicitante';

      const calificacion = {
        id: `${identificador}_${uid}`,
        solicitudId: identificador,
        autorUid: uid,
        autorNombre,
        destinoUid: destino,
        estrellas: datos.estrellas,
        comentario,
        tituloSolicitud: solicitud.titulo ?? '',
        categoria: solicitud.categoria ?? '',
        creada: ahoraIso,
      };

      const cantidad =
        (receptor.totalCalificaciones ?? 0) + 1;

      const suma =
        (receptor.sumaCalificaciones ?? 0) +
        datos.estrellas;

      const promedio = Number((suma / cantidad).toFixed(2));

      transaccion.set(clave, calificacion);

      transaccion.set(`solicitudes/${identificador}`, {
        ...solicitud,
        calificadaPorSolicitante: true,
        calificacionSolicitante: {
          id: calificacion.id,
          estrellas: calificacion.estrellas,
          comentario: calificacion.comentario,
          creada: calificacion.creada,
        },
      });

      transaccion.set(`usuarios/${destino}`, {
        ...receptor,
        totalCalificaciones: cantidad,
        sumaCalificaciones: suma,
        promedio,
      });

      transaccion.set(`notificaciones/notif_${calificacion.id}_calificacion`, {
        id: `notif_${calificacion.id}_calificacion`,
        uid: destino,
        destinatarioUid: destino,
        solicitudId: identificador,
        tipo: 'calificacion_recibida',
        titulo: 'Recibiste una calificación',
        mensaje: `${autorNombre} te calificó con ${datos.estrellas} estrellas.`,
        leida: false,
        fechaLectura: null,
        creada: ahoraIso,
      });
      return calificacion;
    });
  }

  async listarCalificacionesPerfil(
    uidConsulta,
    destinoUid,
    filtros = {},
  ) {
    await this.perfil(uidConsulta);

    const receptor = await this.almacen.get(
      `usuarios/${destinoUid}`,
    );

    exigir(
      receptor && !estaSuspendido(receptor, this.reloj()),
      'El perfil del prestador no está disponible.',
      404,
    );

    const limite =
      filtros.limite != null ? Number(filtros.limite) : 10;

    exigir(
      Number.isInteger(limite) && limite >= 1 && limite <= 50,
      'El límite de paginación debe estar entre 1 y 50.',
      400,
    );

    let cursor = null;
    if (
      filtros.cursor != null &&
      String(filtros.cursor).trim() !== ''
    ) {
      cursor = String(filtros.cursor).trim();
      const partes = cursor.split('|');
      exigir(
        partes.length === 2 && partes[1].length > 0,
        'El cursor de paginación no es válido.',
        400,
      );
    }

    let pagina;
    if (typeof this.almacen.listCalificaciones === 'function') {
      pagina = await this.almacen.listCalificaciones(
        destinoUid,
        cursor,
        limite,
      );
    } else {
      const lista = await this.almacen.list(
        'calificaciones',
        'destinoUid',
        destinoUid,
      );
      const ordenadas = [...lista.datos].sort((a, b) => {
        const cmpFecha = String(b.creada || '').localeCompare(
          String(a.creada || ''),
        );
        if (cmpFecha !== 0) return cmpFecha;
        return String(b.id || '').localeCompare(String(a.id || ''));
      });

      let filtradas = ordenadas;
      if (cursor) {
        const [cursorFecha, cursorId] = cursor.split('|');
        filtradas = ordenadas.filter(
          (item) =>
            String(item.creada || '') < cursorFecha ||
            (String(item.creada || '') === cursorFecha &&
              String(item.id || '') < cursorId),
        );
      }

      const recorte = filtradas.slice(0, limite);
      const ultimo = recorte.at(-1);
      pagina = {
        datos: recorte,
        siguienteCursor:
          filtradas.length > limite &&
          recorte.length === limite &&
          ultimo
            ? `${ultimo.creada || ''}|${ultimo.id}`
            : null,
      };
    }

    // Expone únicamente campos públicos; nunca expone teléfonos, correos ni UIDs privados
    const resenasPublicas = pagina.datos.map((item) => ({
      id: item.id,
      solicitudId: item.solicitudId,
      autorNombre: item.autorNombre || 'Solicitante',
      estrellas: item.estrellas,
      comentario: item.comentario ?? '',
      tituloSolicitud: item.tituloSolicitud ?? '',
      categoria: item.categoria ?? '',
      creada: item.creada ?? null,
    }));

    return {
      promedio: receptor.promedio ?? null,
      totalCalificaciones: receptor.totalCalificaciones ?? 0,
      datos: resenasPublicas,
      siguienteCursor: pagina.siguienteCursor ?? null,
    };
  }

  async eliminarCuenta(uid, { eliminarUsuarioAuth } = {}) {
    exigir(
      typeof uid === 'string' && uid.trim().length > 0,
      'Inicia sesión para continuar.',
      401,
    );

    const perfilExistente = await this.almacen.get(
      `usuarios/${uid}`,
    );

    exigir(
      perfilExistente,
      'La cuenta ya no tiene un perfil activo.',
      404,
    );

    const estadosActivos = new Set([
      'Publicada',
      'Aceptada',
      'En Proceso',
    ]);

    const [comoSolicitante, comoPrestador] = await Promise.all([
      typeof this.almacen.listSolicitudes === 'function'
        ? this.almacen.listSolicitudes({
            campoPropietario: 'solicitanteUid',
            uid,
            limite: 200,
          })
        : this.almacen.list('solicitudes', 'solicitanteUid', uid),
      typeof this.almacen.listSolicitudes === 'function'
        ? this.almacen.listSolicitudes({
            campoPropietario: 'prestadorUid',
            uid,
            limite: 200,
          })
        : this.almacen.list('solicitudes', 'prestadorUid', uid),
    ]);

    const activasSolicitante = comoSolicitante.datos.filter((s) =>
      estadosActivos.has(s.estado),
    );
    const activasPrestador = comoPrestador.datos.filter((s) =>
      estadosActivos.has(s.estado),
    );
    const totalActivas =
      activasSolicitante.length + activasPrestador.length;

    exigir(
      totalActivas === 0,
      `No puedes eliminar tu cuenta porque tienes ${totalActivas} servicio(s) activo(s) (en estado Publicada, Aceptada o En Proceso). Cancela tus solicitudes publicadas o finaliza los servicios en curso antes de eliminar tu cuenta.`,
      409,
    );

    // 1. Anonimiza el nombre del autor en las reseñas emitidas por esta cuenta para conservar la integridad histórica del prestador sin exponer datos personales
    const calificacionesEmitidas = await this.almacen.list(
      'calificaciones',
      'autorUid',
      uid,
    );

    for (const cal of calificacionesEmitidas.datos) {
      await this.almacen.set(`calificaciones/${cal.id}`, {
        ...cal,
        autorNombre: 'Usuario eliminado',
      });
    }

    // 2. Elimina las notificaciones y tokens de dispositivos asociados al UID
    const [notificacionesUsuario, dispositivosUsuario] =
      await Promise.all([
        this.almacen.list('notificaciones', 'uid', uid),
        this.almacen.list('dispositivos', 'uid', uid),
      ]);

    if (typeof this.almacen.delete === 'function') {
      for (const notif of notificacionesUsuario.datos) {
        await this.almacen.delete(`notificaciones/${notif.id}`);
      }
      for (const disp of dispositivosUsuario.datos) {
        if (disp.id) {
          await this.almacen.delete(`dispositivos/${disp.id}`);
        }
      }
      // 3. Elimina los datos personales del perfil en Firestore
      await this.almacen.delete(`usuarios/${uid}`);
    }

    // 4. Elimina la cuenta en Firebase Authentication usando el UID del token validado
    if (typeof eliminarUsuarioAuth === 'function') {
      await eliminarUsuarioAuth(uid);
    }

    return {
      correcto: true,
      mensaje: 'Tu cuenta y tus datos personales fueron eliminados.',
    };
  }

  // ---------------------------------------------------------------------------
  // Administración
  // ---------------------------------------------------------------------------

  /** Recorre todas las páginas de una consulta por igualdad. */
  async listarTodo(coleccion, campo, valor) {
    const resultados = [];
    let cursor;

    for (let pagina = 0; pagina < 100; pagina += 1) {
      const respuesta = await this.almacen.list(
        coleccion,
        campo,
        valor,
        cursor,
      );

      resultados.push(...(respuesta.datos || []));
      cursor = respuesta.siguienteCursor;

      if (!cursor) break;
    }

    return resultados;
  }

  /** Guarda en `acciones_admin` quién hizo qué, para el historial. */
  async registrarAccionAdmin(
    admin,
    accion,
    objetivoTipo,
    objetivoId,
    detalle = {},
  ) {
    const id = randomUUID();

    await this.almacen.set(`acciones_admin/${id}`, {
      id,
      adminUid: admin.uid,
      adminCorreo: admin.correo ?? null,
      accion,
      objetivoTipo,
      objetivoId,
      detalle,
      creada: this.reloj().toISOString(),
    });
  }

  /** Crea una notificación; el push sale solo (ver notificador_push.js). */
  async notificar(uid, tipo, titulo, mensaje, extra = {}) {
    const id = `notif_${randomUUID()}`;
    await this.almacen.set(`notificaciones/${id}`, {
      id,
      uid,
      destinatarioUid: uid,
      tipo,
      titulo,
      mensaje,
      leida: false,
      fechaLectura: null,
      creada: new Date().toISOString(),
      ...extra,
    });
  }

  /** Avisa a los prestadores de la misma ciudad y categoría. */
  async notificarPrestadoresZona(solicitud) {
    const usuarios = await this.listarTodo('usuarios', 'ciudad', solicitud.ciudad);
    const destinatarios = usuarios
      .filter(
        (u) =>
          u.id !== solicitud.solicitanteUid &&
          u.rol === 'prestador' &&
          u.suspendido !== true &&
          !Array.isArray(u.categorias) ||
  u.categorias.length === 0 ||
  u.categorias.includes(solicitud.categoria),
      )
      .slice(0, 200);

    for (const u of destinatarios) {
      await this.notificar(
        u.id,
        'nueva_solicitud_zona',
        'Nueva solicitud cerca de ti',
        `${solicitud.titulo} · ${solicitud.categoria}`,
        { solicitudId: solicitud.id },
      );
    }
  }
  /** Crea un aviso del equipo de Helpi en las notificaciones del usuario. */
  crearAvisoAdmin(uid, titulo, mensaje) {
    const id = `aviso_admin_${randomUUID()}`;

    return {
      ruta: `notificaciones/${id}`,
      datos: {
        id,
        uid,
        destinatarioUid: uid,
        solicitudId: null,
        servicioTitulo: null,
        tipo: 'aviso_admin',
        titulo,
        mensaje,
        leida: false,
        fechaLectura: null,
        creada: this.reloj().toISOString(),
      },
    };
  }

  /**
   * Suspende una cuenta. `dias` entre 1 y 365 = suspensión temporal;
   * `dias` nulo = suspensión indefinida hasta que un administrador la reactive.
   */
  async suspenderUsuarioAdmin(admin, uid, datos = {}) {
    exigir(
      uid !== admin.uid,
      'No puedes suspender tu propia cuenta.',
      409,
    );

    const dias = datos.dias ?? null;

    exigir(
      dias === null ||
        (Number.isInteger(dias) && dias >= 1 && dias <= 365),
      'La suspensión temporal debe durar entre 1 y 365 días.',
    );

    const motivo =
      datos.motivo == null || String(datos.motivo).trim() === ''
        ? null
        : texto(datos.motivo, 'Motivo', 3, 300);

    const ahora = this.reloj();
    const hasta = dias
      ? new Date(ahora.getTime() + dias * MILISEGUNDOS_POR_DIA).toISOString()
      : null;

    const perfil = await this.almacen.atomic(async (transaccion) => {
      const actual = await transaccion.get(`usuarios/${uid}`);

      exigir(actual, 'El usuario no existe.', 404);

      transaccion.set(`usuarios/${uid}`, {
        ...actual,
        suspendido: true,
        suspendidoHasta: hasta,
        motivoSuspension: motivo,
        suspendidoPor: admin.uid,
        suspendidoEn: ahora.toISOString(),
      });

      return actual;
    });

    await this.registrarAccionAdmin(
      admin,
      dias ? 'suspension_temporal' : 'suspension_indefinida',
      'usuario',
      uid,
      { nombre: perfil.nombre ?? null, dias, motivo, hasta },
    );

    await this.notificar(
      uid,
      'cuenta_suspendida',
      'Cuenta suspendida',
      motivo
        ? `Tu cuenta fue suspendida. Motivo: ${motivo}`
        : 'Tu cuenta fue suspendida.',
    );
    return {
      correcto: true,
      suspendido: true,
      suspendidoHasta: hasta,
      motivoSuspension: motivo,
    };
  }

  async reactivarUsuarioAdmin(admin, uid) {
    const ahoraIso = this.reloj().toISOString();

    const perfil = await this.almacen.atomic(async (transaccion) => {
      const actual = await transaccion.get(`usuarios/${uid}`);

      exigir(actual, 'El usuario no existe.', 404);

      transaccion.set(`usuarios/${uid}`, {
        ...actual,
        suspendido: false,
        suspendidoHasta: null,
        motivoSuspension: null,
        reactivadoPor: admin.uid,
        reactivadoEn: ahoraIso,
      });

      return actual;
    });

    await this.registrarAccionAdmin(admin, 'reactivacion', 'usuario', uid, {
      nombre: perfil.nombre ?? null,
    });

    await this.notificar(
      uid,
      'cuenta_reactivada',
      'Cuenta reactivada',
      'Ya puedes volver a usar Helpi.',
    );
    return { correcto: true, suspendido: false };
  }

  /**
   * Si la suspensión temporal ya venció, la quita del perfil.
   * Devuelve true cuando hubo que actualizar el documento.
   */
  async levantarSuspensionVencida(uid) {
    return this.almacen.atomic(async (transaccion) => {
      const actual = await transaccion.get(`usuarios/${uid}`);

      if (
        !actual ||
        actual.suspendido !== true ||
        estaSuspendido(actual, this.reloj())
      ) {
        return false;
      }

      transaccion.set(`usuarios/${uid}`, {
        ...actual,
        suspendido: false,
        suspendidoHasta: null,
        motivoSuspension: null,
      });

      return true;
    });
  }

  /**
   * Envía una alerta del administrador al usuario. `titulo` es opcional
   * (por ejemplo, el nombre de la alerta elegida en la lista del panel).
   */
  async enviarAvisoAdmin(admin, uid, datos = {}) {
    const mensaje = texto(datos.mensaje, 'Mensaje', 5, 500);
    const titulo =
      datos.titulo == null || String(datos.titulo).trim() === ''
        ? 'Aviso del equipo de Helpi'
        : texto(datos.titulo, 'Título', 3, 80);

    const perfil = await this.almacen.get(`usuarios/${uid}`);
    exigir(perfil, 'El usuario no existe.', 404);

    const aviso = this.crearAvisoAdmin(uid, titulo, mensaje);

    await this.almacen.set(aviso.ruta, aviso.datos);

    await this.registrarAccionAdmin(admin, 'aviso_enviado', 'usuario', uid, {
      nombre: perfil.nombre ?? null,
      titulo,
      mensaje,
    });

    return { correcto: true };
  }

  /** Cantidad de notificaciones sin leer (para el número de la campanita). */
  async contarNotificacionesSinLeer(uid) {
    const notificaciones = await this.listarTodo('notificaciones', 'uid', uid);

    return {
      total: notificaciones.filter((n) => n.leida !== true).length,
    };
  }

  /**
   * Alertas del administrador que el usuario todavía no ha leído,
   * de la más antigua a la más reciente. La app las muestra en una
   * ventana flotante al abrirse.
   */
  async avisosAdminPendientes(uid) {
    const notificaciones = await this.listarTodo('notificaciones', 'uid', uid);

    const datos = notificaciones
      .filter((n) => n.tipo === 'aviso_admin' && n.leida !== true)
      .sort((a, b) => String(a.creada || '').localeCompare(String(b.creada || '')))
      .slice(0, 20);

    return { datos };
  }

  /** Marca un reporte como resuelto o descartado y descuenta el reporte activo. */
  async atenderReporteAdmin(admin, idReporte, datos = {}) {
    const estado = datos.estado;

    exigir(
      ESTADOS_REPORTE_ATENDIDO.has(estado),
      'El estado del reporte debe ser "resuelto" o "descartado".',
    );

    const nota =
      datos.nota == null || String(datos.nota).trim() === ''
        ? null
        : texto(datos.nota, 'Nota', 3, 300);

    const ahoraIso = this.reloj().toISOString();

    const reporte = await this.almacen.atomic(async (transaccion) => {
      const actual = await transaccion.get(`reportes/${idReporte}`);

      exigir(actual, 'El reporte no existe.', 404);
      exigir(
        actual.estado === 'abierto',
        'Este reporte ya fue atendido.',
        409,
      );

      const destino = actual.destinoUid
        ? await transaccion.get(`usuarios/${actual.destinoUid}`)
        : null;

      transaccion.set(`reportes/${idReporte}`, {
        ...actual,
        estado,
        nota,
        atendidoPor: admin.uid,
        atendidoEn: ahoraIso,
      });

      if (destino) {
        transaccion.set(`usuarios/${actual.destinoUid}`, {
          ...destino,
          reportesActivos: Math.max(0, (destino.reportesActivos ?? 0) - 1),
        });
      }

      return actual;
    });

    await this.registrarAccionAdmin(
      admin,
      estado === 'resuelto' ? 'reporte_resuelto' : 'reporte_descartado',
      'reporte',
      idReporte,
      { destinoUid: reporte.destinoUid ?? null, motivo: reporte.motivo, nota },
    );

    if (reporte.autorUid) {
      await this.notificar(
        reporte.autorUid,
        'reporte_atendido',
        estado === 'resuelto' ? 'Tu reporte fue resuelto' : 'Tu reporte fue revisado',
        estado === 'resuelto'
          ? 'Gracias por avisarnos, tomamos acción sobre tu reporte.'
          : 'Revisamos tu reporte y no encontramos una infracción.',
      );
    }
    return { correcto: true, estado };
  }

  /**
   * Elimina una solicitud de la base de datos por completo, junto con sus
   * calificaciones (descontándolas del promedio del usuario calificado),
   * sus notificaciones y sus registros de idempotencia.
   */
  async eliminarSolicitudAdmin(admin, identificador, datos = {}) {
    const solicitud = await this.almacen.get(`solicitudes/${identificador}`);

    exigir(solicitud, 'La solicitud no existe.', 404);
    exigir(
      !solicitud.pagoId,
      'Resuelve el pago antes de eliminar la solicitud.',
      409,
    );

    const motivo =
      datos.motivo == null || String(datos.motivo).trim() === ''
        ? null
        : texto(datos.motivo, 'Motivo', 3, 300);

    // 1. Calificaciones: se descuentan del promedio del usuario calificado.
    const calificaciones = await this.listarTodo(
      'calificaciones',
      'solicitudId',
      identificador,
    );

    for (const calificacion of calificaciones) {
      const idCalificacion = calificacion.id;
      if (!idCalificacion) continue;

      await this.almacen.atomic(async (transaccion) => {
        const actual = await transaccion.get(
          `calificaciones/${idCalificacion}`,
        );
        if (!actual) return;

        const receptor = actual.destinoUid
          ? await transaccion.get(`usuarios/${actual.destinoUid}`)
          : null;

        if (receptor) {
          const total = Math.max(0, (receptor.totalCalificaciones ?? 0) - 1);
          const suma = Math.max(
            0,
            (receptor.sumaCalificaciones ?? 0) - (Number(actual.estrellas) || 0),
          );

          transaccion.set(`usuarios/${actual.destinoUid}`, {
            ...receptor,
            totalCalificaciones: total,
            sumaCalificaciones: suma,
            promedio: total > 0 ? Number((suma / total).toFixed(2)) : null,
          });
        }

        transaccion.delete(`calificaciones/${idCalificacion}`);
      });
    }

    // 2. Notificaciones y registros de idempotencia de la solicitud.
    for (const coleccion of ['notificaciones', 'idempotencia_solicitudes']) {
      const documentos = await this.listarTodo(
        coleccion,
        'solicitudId',
        identificador,
      );

      for (const documento of documentos) {
        if (documento.id) {
          await this.almacen.delete(`${coleccion}/${documento.id}`);
        }
      }
    }

    // 3. La solicitud.
    await this.almacen.delete(`solicitudes/${identificador}`);

    // 4. Avisa a los participantes que la solicitud ya no existe.
    const titulo = solicitud.titulo || 'una solicitud';
    const participantes = [
      ...new Set(
        [solicitud.solicitanteUid, solicitud.prestadorUid].filter(Boolean),
      ),
    ];

    for (const uid of participantes) {
      const aviso = this.crearAvisoAdmin(
        uid,
        'Solicitud eliminada',
        `Un administrador eliminó "${titulo}".` +
          (motivo ? ` Motivo: ${motivo}` : ''),
      );
      await this.almacen.set(aviso.ruta, aviso.datos);
    }

    await this.registrarAccionAdmin(
      admin,
      'solicitud_eliminada',
      'solicitud',
      identificador,
      {
        titulo: solicitud.titulo ?? null,
        estado: solicitud.estado ?? null,
        motivo,
        calificacionesEliminadas: calificaciones.length,
      },
    );

    return { correcto: true };
  }
}

module.exports = {
  ServicioHelpi,
  estaSuspendido,
  ErrorHelpi,
  exigir,
  texto,
  coordenadas,
  categorias,
  estadosSolicitud,
  normalizarTextoBusqueda,
  validarSolicitud,
  distanciaKm,
  VERSION_TERMINOS_VIGENTE,
  VERSION_PRIVACIDAD_VIGENTE,
  FECHA_VIGENCIA_DOCUMENTOS,
  DOCUMENTO_TERMINOS_ID,
  DOCUMENTO_PRIVACIDAD_ID,
  tieneAceptacionVigente,
};