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

const VERSION_TERMINOS_VIGENTE = 'v1.0';
const VERSION_PRIVACIDAD_VIGENTE = 'v1.0';
const FECHA_VIGENCIA_DOCUMENTOS = '2026-11-11';

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

  return {
    titulo: texto(datos.titulo, 'Título', 5, 100),

    descripcion: texto(
      datos.descripcion,
      'Descripción',
      15,
      1000,
    ),

    categoria: datos.categoria,
    ciudad: texto(datos.ciudad, 'Ciudad', 2, 80),
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
      !perfil.suspendido,
      'Esta cuenta está suspendida.',
      403,
    );

    if (exigirTerminos) {
      exigir(
        perfil.terminosAceptados &&
          perfil.terminosAceptados.versionTerminos ===
            VERSION_TERMINOS_VIGENTE &&
          perfil.terminosAceptados.versionPrivacidad ===
            VERSION_PRIVACIDAD_VIGENTE,
        'Debes aceptar los Términos y condiciones vigentes para continuar.',
        403,
      );
    }

    return perfil;
  }

  terminosVigentes() {
    return {
      versionTerminos: VERSION_TERMINOS_VIGENTE,
      versionPrivacidad: VERSION_PRIVACIDAD_VIGENTE,
      fechaVigencia: FECHA_VIGENCIA_DOCUMENTOS,
      documentoId: 'terminos_y_privacidad_helpi',
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
      versionTerminos: datos.versionTerminos,
      versionPrivacidad: datos.versionPrivacidad,
      documentoId: 'terminos_y_privacidad_helpi',
      fechaAceptacion: fechaServidor,
    };

    // Registra en el historial inmutable de aceptaciones de Firestore
    await this.almacen.set(
      `aceptaciones_terminos/${idRegistro}`,
      aceptacion,
    );

    // Actualiza la aceptación vigente en el perfil del usuario
    const usuarioExistente =
      (await this.almacen.get(`usuarios/${uid}`)) || {};

    await this.almacen.set(`usuarios/${uid}`, {
      ...usuarioExistente,
      terminosAceptados: {
        versionTerminos: aceptacion.versionTerminos,
        versionPrivacidad: aceptacion.versionPrivacidad,
        documentoId: aceptacion.documentoId,
        fechaAceptacion: aceptacion.fechaAceptacion,
      },
      fechaActualizacion: fechaServidor,
    });

    return {
      correcto: true,
      datos: aceptacion,
    };
  }

  async crear(uid, datos) {
    await this.perfil(uid);

    const identificador = randomUUID();

    const solicitud = {
      ...validarSolicitud(datos, this.reloj()),
      id: identificador,
      solicitanteUid: uid,
      prestadorUid: null,
      estado: 'Publicada',
      creada: this.reloj().toISOString(),
      version: 1,
    };

    await this.almacen.set(
      `solicitudes/${identificador}`,
      solicitud,
    );

    return solicitud;
  }

  async obtener(uid, identificador) {
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

    const pagina = await this.almacen.list(
      'solicitudes',
      campo,
      valor,
      filtros.cursor,
    );

    const ocultas = await this.almacen.list(
      'ocultas',
      'uid',
      uid,
    );

    const identificadoresOcultos = new Set(
      ocultas.datos.map((elemento) => elemento.solicitudId),
    );

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

    const datos = pagina.datos
      .filter(
        (solicitud) =>
          !identificadoresOcultos.has(solicitud.id),
      )
      .filter(
        (solicitud) =>
          !filtros.estado ||
          solicitud.estado === filtros.estado,
      )
      .filter(
        (solicitud) =>
          !filtros.ciudad ||
          solicitud.ciudad.toLowerCase() ===
            String(filtros.ciudad).toLowerCase(),
      )
      .filter(
        (solicitud) =>
          !filtros.categoria ||
          solicitud.categoria === filtros.categoria,
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
      )
      .sort((primera, segunda) => {
        if (punto) {
          return primera.distanciaKm - segunda.distanciaKm;
        }

        return segunda.creada.localeCompare(primera.creada);
      });

    return {
      ...pagina,
      datos,
    };
  }

  async editar(uid, identificador, datos) {
    const campos = validarSolicitud(
      datos,
      this.reloj(),
    );

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
        'Solo puedes editar solicitudes publicadas.',
        409,
      );

      exigir(
        datos.version === solicitud.version,
        'La solicitud cambió. Actualiza antes de editar.',
        409,
      );

      const actualizada = {
        ...solicitud,
        ...campos,
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

      let estado;

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
          contraparte && !contraparte.suspendido,
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
      } else if (accion === 'iniciar') {
        exigir(
          esPrestador && solicitud.estado === 'Aceptada',
          'No puedes iniciar este servicio.',
          409,
        );

        estado = 'En Proceso';
      } else if (accion === 'finalizar') {
        exigir(
          esPrestador && solicitud.estado === 'En Proceso',
          'No puedes solicitar la finalización.',
          409,
        );

        const actualizada = {
          ...solicitud,
          finalizacionSolicitada: true,
          version: solicitud.version + 1,
        };

        transaccion.set(
          `solicitudes/${identificador}`,
          actualizada,
        );

        return actualizada;
      } else if (accion === 'confirmar') {
        exigir(
          esSolicitante &&
            solicitud.estado === 'En Proceso' &&
            solicitud.finalizacionSolicitada,
          'No se puede confirmar la finalización.',
          409,
        );

        estado = 'Completada';
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
        actualizada: this.reloj().toISOString(),
      };

      if (accion === 'aceptar') {
        actualizada.prestadorUid = uid;
      }

      if (motivo) {
        actualizada.motivoCancelacion = motivo;
      }

      transaccion.set(
        `solicitudes/${identificador}`,
        actualizada,
      );

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

      for (const destinatario of destinatarios) {
        const idAviso = randomUUID();

        transaccion.set(
          `notificaciones/${idAviso}`,
          {
            id: idAviso,
            uid: destinatario,
            solicitudId: identificador,
            mensaje: `Servicio ${estado}`,
            pushEstado: 'pendiente',
            leida: false,
            creada: this.reloj().toISOString(),
          },
        );
      }

      return actualizada;
    });
  }

  async duplicar(uid, identificador, datos) {
    const solicitud = await this.obtener(
      uid,
      identificador,
    );

    exigir(
      solicitud.solicitanteUid === uid,
      'Solo puedes duplicar tus propias solicitudes.',
      403,
    );

    return this.crear(uid, {
      ...solicitud,
      ...datos,
    });
  }

  async calificar(uid, identificador, datos) {
    exigir(
      Number.isInteger(datos.estrellas) &&
        datos.estrellas >= 1 &&
        datos.estrellas <= 5,
      'Selecciona entre 1 y 5 estrellas.',
    );

    const comentario = texto(
      datos.comentario ?? '',
      'Comentario',
      0,
      500,
    );

    return this.almacen.atomic(async (transaccion) => {
      const solicitud = await transaccion.get(
        `solicitudes/${identificador}`,
      );

      exigir(
        solicitud && solicitud.estado === 'Completada',
        'El servicio debe estar completado.',
        409,
      );

      exigir(
        [
          solicitud.solicitanteUid,
          solicitud.prestadorUid,
        ].includes(uid),
        'No participaste en este servicio.',
        403,
      );

      const destino =
        uid === solicitud.solicitanteUid
          ? solicitud.prestadorUid
          : solicitud.solicitanteUid;

      const clave =
        `calificaciones/${identificador}_${uid}`;

      const anterior = await transaccion.get(clave);

      const receptor = await transaccion.get(
        `usuarios/${destino}`,
      );

      exigir(
        !anterior,
        'Ya calificaste este servicio.',
        409,
      );

      exigir(
        receptor,
        'El perfil de la contraparte no existe.',
        404,
      );

      const calificacion = {
        id: `${identificador}_${uid}`,
        solicitudId: identificador,
        autorUid: uid,
        destinoUid: destino,
        estrellas: datos.estrellas,
        comentario,
      };

      const cantidad =
        (receptor.totalCalificaciones ?? 0) + 1;

      const suma =
        (receptor.sumaCalificaciones ?? 0) +
        datos.estrellas;

      transaccion.set(
        clave,
        calificacion,
      );

      transaccion.set(
        `usuarios/${destino}`,
        {
          ...receptor,
          totalCalificaciones: cantidad,
          sumaCalificaciones: suma,
          promedio: suma / cantidad,
        },
      );

      return calificacion;
    });
  }
}

module.exports = {
  ServicioHelpi,
  ErrorHelpi,
  exigir,
  texto,
  coordenadas,
  categorias,
  validarSolicitud,
  distanciaKm,
  VERSION_TERMINOS_VIGENTE,
  VERSION_PRIVACIDAD_VIGENTE,
  FECHA_VIGENCIA_DOCUMENTOS,
};