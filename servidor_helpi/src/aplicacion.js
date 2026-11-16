'use strict';

const express = require('express');
const { createHash } = require('node:crypto');

const {
  ServicioHelpi,
  ErrorHelpi,
  exigir,
  texto,
  categorias,
  tieneAceptacionVigente,
} = require('./dominio');

const integraciones = require('./integraciones');

function crearAplicacion({ almacen, auth, db }) {
  const aplicacion = express();
  const servicio = new ServicioHelpi(almacen);

  aplicacion.disable('x-powered-by');

  const origenes = (
    process.env.CORS_ORIGINS || 'http://localhost:5000'
  )
    .split(',')
    .map((origen) => origen.trim());

  // Permite conexiones desde los orígenes configurados.
  aplicacion.use((solicitud, respuesta, siguiente) => {
    const origen = solicitud.get('origin');

    if (origen && !origenes.includes(origen)) {
      return respuesta.status(403).json({
        mensaje: 'Origen no autorizado.',
      });
    }

    if (origen) {
      respuesta.set('Access-Control-Allow-Origin', origen);
    }

    respuesta.vary('Origin');

    respuesta.set(
      'Access-Control-Allow-Headers',
      'Authorization,Content-Type',
    );

    respuesta.set(
      'Access-Control-Allow-Methods',
      'GET,POST,PATCH,DELETE,OPTIONS',
    );

    if (solicitud.method === 'OPTIONS') {
      return respuesta.sendStatus(204);
    }

    siguiente();
  });

  aplicacion.use(express.json({ limit: '750kb' }));

  aplicacion.use((solicitud, respuesta, siguiente) => {
    solicitud.body ??= {};
    siguiente();
  });

  // Estas rutas no necesitan iniciar sesión.
  aplicacion.get('/api/estado', (solicitud, respuesta) => {
    respuesta.json({
      correcto: true,
      servicio: 'API de Helpi',
      baseDeDatos:
        'Firestore configurado; conectividad no comprobada',
    });
  });

  aplicacion.get(
    '/api/terminos/vigentes',
    (solicitud, respuesta) => {
      respuesta.json({
        datos: servicio.terminosVigentes(),
      });
    },
  );

  // Valida la sesión de Firebase antes de acceder a las rutas.
  aplicacion.use(
    '/api',
    async (solicitud, respuesta, siguiente) => {
      try {
        const token = solicitud
          .get('authorization')
          ?.match(/^Bearer (.+)$/)?.[1];

        exigir(
          token,
          'Inicia sesión para continuar.',
          401,
        );

        try {
          solicitud.usuario = await auth.verifyIdToken(
            token,
            true,
          );
        } catch (error) {
          // No imprime tokens ni credenciales.
          console.error(
            'Error al validar la sesión de Firebase:',
            {
              codigo: error.code,
              mensaje: error.message,
            },
          );

          throw new ErrorHelpi(
            401,
            'No se pudo validar la sesión.',
          );
        }

        const perfil = await almacen.get(
          `usuarios/${solicitud.usuario.uid}`,
        );

        exigir(
          !perfil?.suspendido,
          'La cuenta está suspendida.',
          403,
        );

        const rutasExentasTerminos = new Set([
          '/terminos/vigentes',
          '/terminos/aceptar',
          '/perfil',
        ]);

        const rutaRelativa =
          solicitud.path.replace(/^\/api(?=\/|$)/, '') || '/';

        if (
          !rutasExentasTerminos.has(rutaRelativa) &&
          solicitud.usuario.admin !== true
        ) {
          exigir(
            tieneAceptacionVigente(
              perfil,
              solicitud.usuario.uid,
            ),
            'Debes aceptar los Términos y condiciones vigentes para continuar.',
            403,
          );
        }

        siguiente();
      } catch (error) {
        siguiente(error);
      }
    },
  );

  // Límite de desarrollo por usuario y proceso.
  const contadores = new Map();

  aplicacion.use('/api', (solicitud, respuesta, siguiente) => {
    const ahora = Date.now();
    const uid = solicitud.usuario.uid;

    if (contadores.size > 10000) {
      for (const [clave, contador] of contadores) {
        if (contador.fin < ahora) {
          contadores.delete(clave);
        }
      }
    }

    let contador = contadores.get(uid);

    if (!contador || contador.fin < ahora) {
      contador = {
        cantidad: 0,
        fin: ahora + 60000,
      };
    }

    contador.cantidad += 1;
    contadores.set(uid, contador);

    if (contador.cantidad > 120) {
      return respuesta.status(429).json({
        mensaje: 'Demasiadas solicitudes. Espera un minuto.',
      });
    }

    siguiente();
  });

  function registrarRuta(metodo, ruta, operacion) {
    aplicacion[metodo](
      `/api${ruta}`,
      async (solicitud, respuesta, siguiente) => {
        try {
          const resultado = await operacion(solicitud);
          respuesta.json(resultado);
        } catch (error) {
          siguiente(error);
        }
      },
    );
  }

  function verificarAdministrador(solicitud) {
    exigir(
      solicitud.usuario.admin === true,
      'Acceso exclusivo de administrador.',
      403,
    );
  }

  function identificador(solicitud) {
    const valor = texto(
      solicitud.params.id,
      'Identificador',
      1,
      150,
    );

    exigir(
      /^[A-Za-z0-9_-]+$/.test(valor),
      'El identificador no es válido.',
    );

    return valor;
  }

  registrarRuta('get', '/categorias', async () => ({
    datos: categorias,
  }));

  registrarRuta('get', '/terminos/vigentes', async () => ({
    datos: servicio.terminosVigentes(),
  }));

  registrarRuta('post', '/terminos/aceptar', async (solicitud) =>
    servicio.aceptarTerminos(solicitud.usuario.uid, solicitud.body),
  );

  registrarRuta('get', '/perfil', async (solicitud) => ({
    datos: await servicio.perfil(solicitud.usuario.uid, {
      exigirTerminos: false,
    }),
  }));

  registrarRuta('patch', '/perfil', async (solicitud) => ({
    datos: await servicio.actualizarPerfil(
      solicitud.usuario.uid,
      solicitud.body,
    ),
  }));

  registrarRuta('delete', '/perfil', async (solicitud) =>
    servicio.eliminarCuenta(solicitud.usuario.uid, {
      eliminarUsuarioAuth: async (uid) => {
        if (auth && typeof auth.deleteUser === 'function') {
          await auth.deleteUser(uid);
        }
      },
    }),
  );

  registrarRuta('get', '/perfiles/:id', async (solicitud) => {
    const idPerfil = identificador(solicitud);
    const perfil = await almacen.get(`usuarios/${idPerfil}`);

    exigir(
      perfil && !perfil.suspendido,
      'El perfil no está disponible.',
      404,
    );

    // Devuelve únicamente los datos públicos del perfil (nunca teléfono, correo ni términos).
    return {
      datos: {
        uid: perfil.uid ?? idPerfil,
        nombre: perfil.nombre,
        rol: perfil.rol ?? 'solicitante',
        ciudad: perfil.ciudad ?? '',
        sector: perfil.sector ?? '',
        presentacion: perfil.presentacion ?? '',
        disponibilidad: perfil.disponibilidad ?? '',
        habilidades: perfil.habilidades ?? '',
        categorias: perfil.categorias ?? [],
        fotoUrl: perfil.fotoUrl ?? '',
        promedio: perfil.promedio ?? null,
        totalCalificaciones: perfil.totalCalificaciones ?? 0,
      },
    };
  });

  registrarRuta(
    'get',
    '/perfiles/:id/calificaciones',
    async (solicitud) =>
      servicio.listarCalificacionesPerfil(
        solicitud.usuario.uid,
        identificador(solicitud),
        solicitud.query,
      ),
  );

  // Estas rutas requieren configurar Cloudinary para usarlas.
  registrarRuta('post', '/perfil/foto', async (solicitud) => {
    const uid = solicitud.usuario.uid;

    await servicio.perfil(uid);

    const foto = await integraciones.subirFoto(
      uid,
      solicitud.body,
    );

    try {
      await db.doc(`usuarios/${uid}`).update(foto);
    } catch (error) {
      await integraciones
        .eliminarFoto(foto.fotoPublicId)
        .catch(() => {});

      throw error;
    }

    return { datos: foto };
  });

  registrarRuta('delete', '/perfil/foto', async (solicitud) => {
    const uid = solicitud.usuario.uid;
    const perfil = await servicio.perfil(uid);

    await integraciones.eliminarFoto(perfil.fotoPublicId);

    await db.doc(`usuarios/${uid}`).update({
      fotoUrl: '',
      fotoPublicId: '',
    });

    return { correcto: true };
  });

  registrarRuta('post', '/solicitudes', (solicitud) =>
    servicio.crear(
      solicitud.usuario.uid,
      solicitud.body,
    ),
  );

  registrarRuta('get', '/solicitudes', (solicitud) =>
    servicio.listar(
      solicitud.usuario.uid,
      solicitud.query,
    ),
  );

  registrarRuta('get', '/solicitudes/:id', (solicitud) =>
    servicio.obtener(
      solicitud.usuario.uid,
      identificador(solicitud),
    ),
  );

  registrarRuta('patch', '/solicitudes/:id', (solicitud) =>
    servicio.editar(
      solicitud.usuario.uid,
      identificador(solicitud),
      solicitud.body,
    ),
  );

  registrarRuta(
    'post',
    '/solicitudes/:id/duplicar',
    (solicitud) =>
      servicio.duplicar(
        solicitud.usuario.uid,
        identificador(solicitud),
        solicitud.body,
      ),
  );

  for (const accion of [
    'aceptar',
    'iniciar',
    'finalizar',
    'confirmar',
    'cancelar',
  ]) {
    registrarRuta(
      'post',
      `/solicitudes/:id/${accion}`,
      (solicitud) =>
        servicio.cambiarEstado(
          solicitud.usuario.uid,
          identificador(solicitud),
          accion,
          solicitud.body.motivo,
        ),
    );
  }

  registrarRuta(
    'post',
    '/solicitudes/:id/ocultar',
    async (solicitud) => {
      const uid = solicitud.usuario.uid;
      const idSolicitud = identificador(solicitud);

      await servicio.obtener(uid, idSolicitud);

      await almacen.set(
        `ocultas/${uid}_${idSolicitud}`,
        {
          uid,
          solicitudId: idSolicitud,
        },
      );

      return { correcto: true };
    },
  );

  registrarRuta(
    'post',
    '/solicitudes/:id/calificaciones',
    (solicitud) =>
      servicio.calificar(
        solicitud.usuario.uid,
        identificador(solicitud),
        solicitud.body,
      ),
  );

  registrarRuta('get', '/lugares', (solicitud) =>
    integraciones.autocompletar(solicitud.query.texto),
  );

  registrarRuta('get', '/lugares/:id', (solicitud) =>
    integraciones.detalleLugar(identificador(solicitud)),
  );

  registrarRuta('post', '/rutas', (solicitud) =>
    integraciones.ruta(solicitud.body),
  );

  registrarRuta('get', '/notificaciones', (solicitud) =>
    servicio.listarNotificaciones(
      solicitud.usuario.uid,
      solicitud.query.cursor,
    ),
  );

  registrarRuta(
    'patch',
    '/notificaciones/:id',
    (solicitud) =>
      servicio.marcarNotificacionLeida(
        solicitud.usuario.uid,
        identificador(solicitud),
      ),
  );

  registrarRuta('post', '/dispositivos', async (solicitud) => {
    const token = texto(
      solicitud.body.token,
      'Token',
      20,
      4096,
    );

    const clave = createHash('sha256')
      .update(token)
      .digest('hex');

    await almacen.set(`dispositivos/${clave}`, {
      uid: solicitud.usuario.uid,
      token,
    });

    return { correcto: true };
  });

  registrarRuta('post', '/bloqueos/:id', async (solicitud) => {
    const uid = solicitud.usuario.uid;
    const destino = identificador(solicitud);

    exigir(
      destino !== uid,
      'No puedes bloquearte a ti mismo.',
    );

    await almacen.set(`bloqueos/${uid}_${destino}`, {
      uid,
      destino,
    });

    return { correcto: true };
  });

  registrarRuta('delete', '/bloqueos/:id', async (solicitud) => {
    const uid = solicitud.usuario.uid;
    const destino = identificador(solicitud);

    await db.doc(`bloqueos/${uid}_${destino}`).delete();

    return { correcto: true };
  });

  registrarRuta('post', '/reportes', async (solicitud) => {
    const uid = solicitud.usuario.uid;

    const destino = texto(
      solicitud.body.destinoUid,
      'Usuario',
      1,
      150,
    );

    const motivo = texto(
      solicitud.body.motivo,
      'Motivo',
      10,
      500,
    );

    exigir(
      destino !== uid,
      'No puedes reportarte a ti mismo.',
    );

    const servicios = await db
      .collection('solicitudes')
      .where('solicitanteUid', 'in', [uid, destino])
      .limit(100)
      .get();

    const existeRelacion = servicios.docs.some((documento) => {
      const servicioActual = documento.data();

      const participantes = [
        servicioActual.solicitanteUid,
        servicioActual.prestadorUid,
      ];

      return (
        participantes.includes(uid) &&
        participantes.includes(destino)
      );
    });

    exigir(
      existeRelacion,
      'Solo puedes reportar a una contraparte de tus servicios.',
      403,
    );

    await almacen.atomic(async (transaccion) => {
      const clave = `reportes/${uid}_${destino}`;

      const anterior = await transaccion.get(clave);

      const perfil = await transaccion.get(
        `usuarios/${destino}`,
      );

      exigir(perfil, 'El usuario no existe.', 404);

      exigir(
        !anterior,
        'Ya reportaste a este usuario.',
        409,
      );

      const cantidad = (perfil.reportesActivos ?? 0) + 1;

      transaccion.set(clave, {
        autorUid: uid,
        destinoUid: destino,
        motivo,
        estado: 'abierto',
        creada: new Date().toISOString(),
      });

      transaccion.set(`usuarios/${destino}`, {
        ...perfil,
        reportesActivos: cantidad,
        suspendido:
          cantidad >= 3 || perfil.suspendido === true,
      });
    });

    return { correcto: true };
  });

  registrarRuta('get', '/admin/reportes', async (solicitud) => {
    verificarAdministrador(solicitud);

    return almacen.list(
      'reportes',
      'estado',
      'abierto',
      solicitud.query.cursor,
    );
  });

  registrarRuta(
    'patch',
    '/admin/usuarios/:id',
    async (solicitud) => {
      verificarAdministrador(solicitud);

      exigir(
        typeof solicitud.body.suspendido === 'boolean',
        'Indica si la cuenta estará suspendida.',
      );

      await db
        .doc(`usuarios/${identificador(solicitud)}`)
        .update({
          suspendido: solicitud.body.suspendido,
        });

      return { correcto: true };
    },
  );

  registrarRuta(
    'get',
    '/admin/estadisticas',
    async (solicitud) => {
      verificarAdministrador(solicitud);

      const [usuarios, solicitudes] = await Promise.all([
        db.collection('usuarios').count().get(),
        db.collection('solicitudes').count().get(),
      ]);

      return {
        usuarios: usuarios.data().count,
        solicitudes: solicitudes.data().count,
      };
    },
  );

  registrarRuta(
    'delete',
    '/admin/solicitudes/:id',
    async (solicitud) => {
      verificarAdministrador(solicitud);

      const referencia = db.doc(
        `solicitudes/${identificador(solicitud)}`,
      );

      await db.runTransaction(async (transaccion) => {
        const documento = await transaccion.get(referencia);

        exigir(
          documento.exists,
          'La solicitud no existe.',
          404,
        );

        exigir(
          !documento.data().pagoId,
          'Resuelve el pago antes de retirar la solicitud.',
          409,
        );

        transaccion.update(referencia, {
          estado: 'Cancelada',
          retiradaPorAdmin: true,
        });
      });

      return { correcto: true };
    },
  );

  // Reservadas hasta definir el modelo financiero.
  const rutasFinancieras = [
    '/pagos',
    '/saldo/recargas',
    '/pagos/:id/capturar',
    '/pagos/:id/cancelar',
  ];

  for (const ruta of rutasFinancieras) {
    registrarRuta('post', ruta, async () => {
      throw new ErrorHelpi(
        501,
        'La integración financiera todavía no está implementada.',
      );
    });
  }

  registrarRuta('get', '/saldo', async () => {
    throw new ErrorHelpi(
      501,
      'La consulta del saldo financiero todavía no está implementada.',
    );
  });

  // Respuesta para rutas inexistentes.
  aplicacion.use((solicitud, respuesta) => {
    respuesta.status(404).json({
      correcto: false,
      mensaje: 'La ruta solicitada no existe.',
    });
  });

  // Manejo centralizado de errores.
  aplicacion.use(
    (error, solicitud, respuesta, siguiente) => {
      let estado = error.estado;
      let mensajePersonalizado = null;
      const textoError = String(error?.message || '');
      const codigoGrpc = error?.code;

      if (estado == null) {
        if (error.type === 'entity.too.large') {
          estado = 413;
          mensajePersonalizado =
            'El contenido enviado supera el tamaño máximo permitido.';
        } else if (error instanceof SyntaxError) {
          estado = 400;
          mensajePersonalizado =
            'El formato JSON enviado al servidor no es válido.';
        } else if (
          codigoGrpc === 9 ||
          /FAILED_PRECONDITION|requires an index/i.test(
            textoError,
          )
        ) {
          estado = 503;
          mensajePersonalizado =
            'La consulta en Firestore requiere un índice compuesto o ajuste de consulta. Pulsa Reintentar.';
        } else if (
          codigoGrpc === 7 ||
          /PERMISSION_DENIED/i.test(textoError)
        ) {
          estado = 503;
          mensajePersonalizado =
            'El servidor no tiene permisos suficientes en Firestore para realizar esta operación.';
        } else if (
          codigoGrpc === 14 ||
          codigoGrpc === 4 ||
          /UNAVAILABLE|DEADLINE_EXCEEDED|ETIMEDOUT|ECONNRESET/i.test(
            textoError,
          )
        ) {
          estado = 503;
          mensajePersonalizado =
            'No se pudo conectar temporalmente con la base de datos Firestore. Pulsa Reintentar.';
        } else if (
          codigoGrpc === 16 ||
          /UNAUTHENTICATED|invalid_grant/i.test(textoError)
        ) {
          estado = 503;
          mensajePersonalizado =
            'El servidor no pudo autenticarse con Firebase Admin / Firestore. Verifica la configuración del servidor.';
        } else {
          estado = 500;
        }
      }

      if (estado >= 500) {
        // Registro diagnóstico seguro: sin tokens, contraseñas ni datos personales
        console.error('Operación fallida en el servidor:', {
          metodo: solicitud.method,
          ruta: solicitud.originalUrl || solicitud.path,
          estado,
          codigo: error.code ?? error.name,
          detalle: textoError.slice(0, 300),
        });
      }

      let mensajeRespuesta =
        mensajePersonalizado ?? error.message;

      if (estado === 500 && !mensajePersonalizado) {
        const ruta = solicitud.path || '';
        if (ruta.includes('/solicitudes')) {
          mensajeRespuesta =
            'Ocurrió un error en el servidor al consultar los servicios. Pulsa Reintentar.';
        } else if (ruta.includes('/notificaciones')) {
          mensajeRespuesta =
            'Ocurrió un error en el servidor al consultar las notificaciones. Pulsa Reintentar.';
        } else if (ruta.includes('/terminos')) {
          mensajeRespuesta =
            'Ocurrió un error en el servidor al procesar los Términos y condiciones. Pulsa Reintentar.';
        } else {
          mensajeRespuesta =
            'Ocurrió un error interno en el servidor. Pulsa Reintentar.';
        }
      }

      respuesta.status(estado).json({
        correcto: false,
        codigo: error.code ?? undefined,
        mensaje: mensajeRespuesta,
      });
    },
  );

  return aplicacion;
}

module.exports = {
  crearAplicacion,
};