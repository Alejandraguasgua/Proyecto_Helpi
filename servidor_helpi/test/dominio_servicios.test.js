'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  ServicioHelpi,
  ErrorHelpi,
  estaSuspendido,
} = require('../src/dominio');

class AlmacenEnMemoria {
  constructor() {
    this.datos = new Map();
    this.fallarEnRuta = null;
  }

  async get(ruta) {
    const doc = this.datos.get(ruta);
    return doc ? JSON.parse(JSON.stringify(doc)) : null;
  }

  async set(ruta, valor) {
    if (this.fallarEnRuta && ruta.startsWith(this.fallarEnRuta)) {
      throw new Error(`Fallo simulado al escribir en ${ruta}`);
    }
    this.datos.set(ruta, JSON.parse(JSON.stringify(valor)));
  }

  async delete(ruta) {
    this.datos.delete(ruta);
  }

  async list(coleccion, campo, valor) {
    const resultados = [];
    for (const [ruta, doc] of this.datos.entries()) {
      if (ruta.startsWith(`${coleccion}/`) && doc[campo] === valor) {
        // Igual que Firestore: cada resultado incluye el id del documento.
        resultados.push({
          ...JSON.parse(JSON.stringify(doc)),
          id: doc.id ?? ruta.slice(coleccion.length + 1),
        });
      }
    }
    return { datos: resultados, siguienteCursor: null };
  }

  async listNotificaciones(uid, cursor, limite = 20) {
    // Filtra por usuario antes de ordenar y paginar (idéntico al índice compuesto de Firestore)
    const delUsuario = [];
    for (const [ruta, doc] of this.datos.entries()) {
      if (ruta.startsWith('notificaciones/') && doc.uid === uid) {
        delUsuario.push(JSON.parse(JSON.stringify(doc)));
      }
    }

    delUsuario.sort((a, b) => {
      const cmpFecha = String(b.creada || '').localeCompare(
        String(a.creada || ''),
      );
      if (cmpFecha !== 0) return cmpFecha;
      return String(b.id || '').localeCompare(String(a.id || ''));
    });

    let filtrados = delUsuario;
    if (cursor) {
      const [cursorFecha, cursorId] = String(cursor).split('|');
      filtrados = delUsuario.filter(
        (item) =>
          item.creada < cursorFecha ||
          (item.creada === cursorFecha && item.id < cursorId),
      );
    }

    const datos = filtrados.slice(0, limite);
    const ultimo = datos.at(-1);

    return {
      datos,
      siguienteCursor:
        datos.length === limite && ultimo
          ? `${ultimo.creada}|${ultimo.id}`
          : null,
    };
  }

  async atomic(operacion) {
    // Copia de aislamiento transaccional: solo confirma si toda la operación tiene éxito
    const instantanea = new Map();
    for (const [clave, valor] of this.datos.entries()) {
      instantanea.set(clave, JSON.parse(JSON.stringify(valor)));
    }

    const resultado = await operacion({
      get: async (ruta) => {
        const doc = instantanea.get(ruta);
        return doc ? JSON.parse(JSON.stringify(doc)) : null;
      },
      set: (ruta, valor) => {
        if (this.fallarEnRuta && ruta.startsWith(this.fallarEnRuta)) {
          throw new Error(`Fallo simulado en transacción al escribir ${ruta}`);
        }
        instantanea.set(ruta, JSON.parse(JSON.stringify(valor)));
      },
      delete: (ruta) => {
        instantanea.delete(ruta);
      },
    });

    this.datos = instantanea;
    return resultado;
  }
}

function crearEscenarioBase() {
  const almacen = new AlmacenEnMemoria();
  const fechaFija = new Date('2026-11-10T12:00:00.000Z');
  const servicio = new ServicioHelpi(almacen, () => fechaFija);

  const uidSolicitante = 'solicitante_123';
  const uidPrestador = 'prestador_456';
  const uidTercero = 'tercero_789';

  const terminosAceptados = {
    documentoId: 'terminos_condiciones_helpi',
    versionTerminos: 'v1.0',
    avisoPrivacidadId: 'aviso_privacidad_helpi',
    versionPrivacidad: 'v1.0',
    fechaAceptacion: fechaFija.toISOString(),
  };

  almacen.set(`usuarios/${uidSolicitante}`, {
    uid: uidSolicitante,
    nombre: 'Ana Solicitante',
    rol: 'solicitante',
    perfilCompleto: true,
    suspendido: false,
    terminosAceptados,
  });

  almacen.set(`usuarios/${uidPrestador}`, {
    uid: uidPrestador,
    nombre: 'Pedro Prestador',
    rol: 'prestador',
    perfilCompleto: true,
    suspendido: false,
    terminosAceptados,
  });

  almacen.set(`usuarios/${uidTercero}`, {
    uid: uidTercero,
    nombre: 'Carlos Tercero',
    rol: 'prestador',
    perfilCompleto: true,
    suspendido: false,
    terminosAceptados,
  });

  const solicitudId = 'solicitud_abc';
  const solicitudBase = {
    id: solicitudId,
    titulo: 'Reparación de tubería en cocina',
    descripcion: 'Se necesita reparar fuga en tubería debajo del fregadero.',
    categoria: 'Reparaciones',
    ciudad: 'Riobamba',
    sector: 'Centro',
    horario: 'Por la mañana',
    fechaServicio: '2026-11-15T15:00:00.000Z',
    montoCentavos: 2500,
    ubicacion: { latitud: -1.67, longitud: -78.65 },
    solicitanteUid: uidSolicitante,
    prestadorUid: null,
    estado: 'Publicada',
    creada: fechaFija.toISOString(),
    version: 1,
  };

  almacen.set(`solicitudes/${solicitudId}`, solicitudBase);

  return {
    almacen,
    servicio,
    solicitudId,
    uidSolicitante,
    uidPrestador,
    uidTercero,
  };
}

test('Flujo completo de servicio: Publicada -> Aceptada -> En Proceso -> Finalización solicitada -> Completada', async () => {
  const { servicio, solicitudId, uidSolicitante, uidPrestador } = crearEscenarioBase();

  // 1. Prestador acepta la solicitud publicada
  const aceptada = await servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar');
  assert.equal(aceptada.estado, 'Aceptada');
  assert.equal(aceptada.prestadorUid, uidPrestador);

  // 2. Prestador inicia el servicio
  const iniciada = await servicio.cambiarEstado(uidPrestador, solicitudId, 'iniciar');
  assert.equal(iniciada.estado, 'En Proceso');

  // 3. Prestador solicita finalización
  const finalizacionPedida = await servicio.cambiarEstado(uidPrestador, solicitudId, 'finalizar');
  assert.equal(finalizacionPedida.estado, 'En Proceso');
  assert.equal(finalizacionPedida.finalizacionSolicitada, true);

  // 4. Solicitante confirma finalización
  const completada = await servicio.cambiarEstado(uidSolicitante, solicitudId, 'confirmar');
  assert.equal(completada.estado, 'Completada');
});

test('Validación de inicio: solo el prestador asignado puede iniciar cuando está Aceptada', async () => {
  const { servicio, solicitudId, uidSolicitante, uidPrestador, uidTercero } = crearEscenarioBase();

  // No se puede iniciar si sigue Publicada
  await assert.rejects(
    async () => servicio.cambiarEstado(uidPrestador, solicitudId, 'iniciar'),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );

  await servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar');

  // Solicitante no puede iniciar
  await assert.rejects(
    async () => servicio.cambiarEstado(uidSolicitante, solicitudId, 'iniciar'),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );

  // Tercero no puede iniciar
  await assert.rejects(
    async () => servicio.cambiarEstado(uidTercero, solicitudId, 'iniciar'),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );

  // Prestador asignado sí puede iniciar
  const iniciada = await servicio.cambiarEstado(uidPrestador, solicitudId, 'iniciar');
  assert.equal(iniciada.estado, 'En Proceso');
});

test('Validación de finalización y confirmación: reglas estrictas de rol y estado', async () => {
  const { servicio, solicitudId, uidSolicitante, uidPrestador } = crearEscenarioBase();

  await servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar');
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'iniciar');

  // Solicitante NO puede solicitar finalización
  await assert.rejects(
    async () => servicio.cambiarEstado(uidSolicitante, solicitudId, 'finalizar'),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );

  // Solicitante NO puede confirmar si el prestador aún no ha solicitado finalizar
  await assert.rejects(
    async () => servicio.cambiarEstado(uidSolicitante, solicitudId, 'confirmar'),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );

  // Prestador solicita finalización
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'finalizar');

  // Prestador NO puede confirmar su propia finalización
  await assert.rejects(
    async () => servicio.cambiarEstado(uidPrestador, solicitudId, 'confirmar'),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );

  // Solicitante confirma exitosamente
  const final = await servicio.cambiarEstado(uidSolicitante, solicitudId, 'confirmar');
  assert.equal(final.estado, 'Completada');
});

test('Cancelación: solicitante o prestador pueden cancelar con motivo válido (5 a 300 caracteres)', async () => {
  const { servicio, solicitudId, uidSolicitante, uidPrestador } = crearEscenarioBase();

  // Cancelar requiere motivo >= 5 caracteres
  await assert.rejects(
    async () => servicio.cambiarEstado(uidSolicitante, solicitudId, 'cancelar', 'hola'),
    (err) => err instanceof ErrorHelpi,
  );

  // Solicitante cancela con motivo válido
  const cancelada = await servicio.cambiarEstado(
    uidSolicitante,
    solicitudId,
    'cancelar',
    'Ya no necesito el servicio por cambio de planes.',
  );
  assert.equal(cancelada.estado, 'Cancelada');
  assert.equal(
    cancelada.motivoCancelacion,
    'Ya no necesito el servicio por cambio de planes.',
  );

  // Una vez cancelada, no se puede iniciar ni aceptar
  await assert.rejects(
    async () => servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar'),
    (err) => err instanceof ErrorHelpi,
  );
});

test('Cancelación: no se puede cancelar un servicio Completado ni con pago asociado', async () => {
  const { almacen, servicio, solicitudId, uidSolicitante, uidPrestador } = crearEscenarioBase();

  await servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar');
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'iniciar');
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'finalizar');
  await servicio.cambiarEstado(uidSolicitante, solicitudId, 'confirmar');

  // No se puede cancelar cuando ya está Completada
  await assert.rejects(
    async () =>
      servicio.cambiarEstado(
        uidSolicitante,
        solicitudId,
        'cancelar',
        'Quiero cancelar aunque ya terminó.',
      ),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );

  // Si tiene pagoId tampoco se cancela por esta vía
  const { almacen: a2, servicio: s2, solicitudId: id2 } = crearEscenarioBase();
  const doc = await a2.get(`solicitudes/${id2}`);
  doc.pagoId = 'pago_123';
  await a2.set(`solicitudes/${id2}`, doc);

  await assert.rejects(
    async () =>
      s2.cambiarEstado(
        uidSolicitante,
        id2,
        'cancelar',
        'Tengo un pagoId asociado.',
      ),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );
});

test('Términos y condiciones: consulta de vigencia, registro y validación en operaciones protegidas', async () => {
  const { almacen, servicio, solicitudId } = crearEscenarioBase();

  // 1. Consulta de términos vigentes
  const vigentes = servicio.terminosVigentes();
  assert.equal(vigentes.documentoId, 'terminos_condiciones_helpi');
  assert.equal(vigentes.versionTerminos, 'v1.0');
  assert.equal(vigentes.avisoPrivacidadId, 'aviso_privacidad_helpi');
  assert.equal(vigentes.versionPrivacidad, 'v1.0');
  assert.equal(vigentes.fechaVigencia, '2026-11-11');

  // 2. Usuario sin términos aceptados no puede crear, listar, obtener ni operar solicitudes
  const uidNuevo = 'usuario_sin_terminos';
  await almacen.set(`usuarios/${uidNuevo}`, {
    uid: uidNuevo,
    nombre: 'Usuario Sin Términos',
    rol: 'solicitante',
    perfilCompleto: true,
    suspendido: false,
    terminosAceptados: null,
  });

  // Pero sí puede consultar su propio perfil con { exigirTerminos: false }
  const perfilSinTerminos = await servicio.perfil(uidNuevo, {
    exigirTerminos: false,
  });
  assert.equal(perfilSinTerminos.uid, uidNuevo);

  await assert.rejects(
    async () =>
      servicio.crear(uidNuevo, {
        titulo: 'Solicitud de prueba',
        descripcion: 'Descripción con suficiente longitud para validar.',
        categoria: 'Hogar',
        ciudad: 'Riobamba',
        sector: 'Norte',
        horario: 'Por la tarde',
        fechaServicio: '2026-11-20T10:00:00.000Z',
        montoCentavos: 1500,
        ubicacion: { latitud: -1.67, longitud: -78.65 },
      }),
    (err) => err instanceof ErrorHelpi && err.estado === 403,
  );

  await assert.rejects(
    async () => servicio.listar(uidNuevo),
    (err) => err instanceof ErrorHelpi && err.estado === 403,
  );

  await assert.rejects(
    async () => servicio.obtener(uidNuevo, solicitudId),
    (err) => err instanceof ErrorHelpi && err.estado === 403,
  );

  // 3. Usuario con versión desactualizada (v0.9) también es bloqueado hasta aceptar v1.0
  await almacen.set(`usuarios/${uidNuevo}`, {
    uid: uidNuevo,
    nombre: 'Usuario Sin Términos',
    rol: 'solicitante',
    perfilCompleto: true,
    suspendido: false,
    terminosAceptados: {
      documentoId: 'terminos_condiciones_helpi',
      versionTerminos: 'v0.9',
      avisoPrivacidadId: 'aviso_privacidad_helpi',
      versionPrivacidad: 'v0.9',
      fechaAceptacion: '2026-01-01T00:00:00.000Z',
    },
    historialAceptacionesTerminos: [
      {
        id: 'reg_antiguo',
        documentoId: 'terminos_condiciones_helpi',
        versionTerminos: 'v0.9',
        avisoPrivacidadId: 'aviso_privacidad_helpi',
        versionPrivacidad: 'v0.9',
        fechaAceptacion: '2026-01-01T00:00:00.000Z',
      },
    ],
  });

  await assert.rejects(
    async () => servicio.listar(uidNuevo),
    (err) => err instanceof ErrorHelpi && err.estado === 403,
  );

  // 4. Aceptar con versión incorrecta debe ser rechazado
  await assert.rejects(
    async () =>
      servicio.aceptarTerminos(uidNuevo, {
        versionTerminos: 'v0.9',
        versionPrivacidad: 'v1.0',
      }),
    (err) => err instanceof ErrorHelpi && err.estado === 400,
  );

  // 5. Aceptar con versiones vigentes registra en el usuario, preserva el historial previo y registra el documento
  const resultado = await servicio.aceptarTerminos(uidNuevo, {
    versionTerminos: 'v1.0',
    versionPrivacidad: 'v1.0',
  });
  assert.equal(resultado.correcto, true);
  assert.equal(resultado.datos.documentoId, 'terminos_condiciones_helpi');
  assert.equal(resultado.datos.versionTerminos, 'v1.0');
  assert.equal(resultado.datos.avisoPrivacidadId, 'aviso_privacidad_helpi');
  assert.equal(resultado.datos.versionPrivacidad, 'v1.0');
  assert.ok(resultado.datos.fechaAceptacion);

  // Comprobar que se guardó en usuarios/${uidNuevo} y conservó el historial (v0.9 + v1.0)
  const perfilActualizado = await almacen.get(`usuarios/${uidNuevo}`);
  assert.equal(
    perfilActualizado.terminosAceptados.documentoId,
    'terminos_condiciones_helpi',
  );
  assert.equal(perfilActualizado.terminosAceptados.versionTerminos, 'v1.0');
  assert.equal(perfilActualizado.terminosAceptados.versionPrivacidad, 'v1.0');
  assert.equal(perfilActualizado.historialAceptacionesTerminos.length, 2);

  // Comprobar que se guardó en historial inmutable aceptaciones_terminos/${id}
  const registroHistorial = await almacen.get(
    `aceptaciones_terminos/${resultado.datos.id}`,
  );
  assert.ok(registroHistorial);
  assert.equal(registroHistorial.uid, uidNuevo);
  assert.equal(registroHistorial.versionTerminos, 'v1.0');

  // Comprobar versión del documento legal registrada
  const docLegal = await almacen.get(
    'documentos_legales/terminos_condiciones_helpi_v1.0',
  );
  assert.ok(docLegal);
  assert.equal(docLegal.versionTerminos, 'v1.0');

  // 6. Ahora sí puede realizar las operaciones protegidas
  const nuevaSolicitud = await servicio.crear(uidNuevo, {
    titulo: 'Solicitud autorizada tras aceptar',
    descripcion: 'Descripción completa para validar la creación.',
    categoria: 'Hogar',
    ciudad: 'Riobamba',
    sector: 'Norte',
    horario: 'Por la tarde',
    fechaServicio: '2026-11-20T10:00:00.000Z',
    montoCentavos: 1500,
    ubicacion: { latitud: -1.67, longitud: -78.65 },
  });
  assert.ok(nuevaSolicitud.id);
  assert.equal(nuevaSolicitud.solicitanteUid, uidNuevo);
});

test('Notificaciones (Módulo 2): generación en los 5 eventos, destinatarios e idempotencia al finalizar', async () => {
  const almacen = new AlmacenEnMemoria();
  let instanteMs = Date.parse('2026-11-10T12:00:00.000Z');
  const reloj = () => new Date(instanteMs);
  const servicio = new ServicioHelpi(almacen, reloj);

  const { solicitudId, uidSolicitante, uidPrestador } = crearEscenarioBase();
  // Copiar escenario base al almacen con reloj dinámico
  const base = crearEscenarioBase();
  almacen.datos = base.almacen.datos;

  // 1. Prestador acepta -> genera notificación para el solicitante
  instanteMs += 1000;
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar');

  let avisosSolicitante = await servicio.listarNotificaciones(uidSolicitante);
  let avisosPrestador = await servicio.listarNotificaciones(uidPrestador);
  assert.equal(avisosSolicitante.datos.length, 1);
  assert.equal(avisosPrestador.datos.length, 0);
  assert.equal(avisosSolicitante.datos[0].tipo, 'solicitud_aceptada');
  assert.equal(avisosSolicitante.datos[0].titulo, 'Solicitud aceptada');
  assert.equal(avisosSolicitante.datos[0].solicitudId, solicitudId);
  assert.equal(avisosSolicitante.datos[0].leida, false);
  assert.equal(avisosSolicitante.datos[0].fechaLectura, null);

  // 2. Prestador inicia -> genera notificación para el solicitante
  instanteMs += 1000;
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'iniciar');

  avisosSolicitante = await servicio.listarNotificaciones(uidSolicitante);
  assert.equal(avisosSolicitante.datos.length, 2);
  assert.equal(avisosSolicitante.datos[0].tipo, 'servicio_iniciado');
  assert.equal(avisosSolicitante.datos[0].titulo, 'Servicio iniciado');

  // 3. Prestador solicita finalizar -> genera notificación para el solicitante
  instanteMs += 1000;
  const trasFinalizar1 = await servicio.cambiarEstado(
    uidPrestador,
    solicitudId,
    'finalizar',
  );
  assert.equal(trasFinalizar1.finalizacionSolicitada, true);
  const versionTrasFinalizar1 = trasFinalizar1.version;

  avisosSolicitante = await servicio.listarNotificaciones(uidSolicitante);
  assert.equal(avisosSolicitante.datos.length, 3);
  assert.equal(avisosSolicitante.datos[0].tipo, 'finalizacion_solicitada');
  assert.equal(
    avisosSolicitante.datos[0].titulo,
    'Confirmación de finalización pendiente',
  );

  // Reintento de solicitar finalización: NO debe incrementar versión ni crear otro aviso
  instanteMs += 1000;
  const trasFinalizar2 = await servicio.cambiarEstado(
    uidPrestador,
    solicitudId,
    'finalizar',
  );
  assert.equal(trasFinalizar2.version, versionTrasFinalizar1);
  avisosSolicitante = await servicio.listarNotificaciones(uidSolicitante);
  assert.equal(avisosSolicitante.datos.length, 3);

  // 4. Solicitante confirma -> genera notificación para el prestador
  instanteMs += 1000;
  await servicio.cambiarEstado(uidSolicitante, solicitudId, 'confirmar');

  avisosPrestador = await servicio.listarNotificaciones(uidPrestador);
  assert.equal(avisosPrestador.datos.length, 1);
  assert.equal(avisosPrestador.datos[0].tipo, 'servicio_completado');
  assert.equal(avisosPrestador.datos[0].titulo, 'Servicio completado');
  assert.equal(avisosPrestador.datos[0].uid, uidPrestador);

  // 5. Cancelación en una segunda solicitud aceptada -> notifica a la contraparte
  const segundaSolicitud = await servicio.crear(uidSolicitante, {
    titulo: 'Instalación de repisa en sala',
    descripcion: 'Colocar dos repisas de madera con taladro en pared.',
    categoria: 'Hogar',
    ciudad: 'Riobamba',
    sector: 'Centro',
    horario: 'Por la tarde',
    fechaServicio: '2026-11-22T16:00:00.000Z',
    montoCentavos: 1800,
    ubicacion: { latitud: -1.67, longitud: -78.65 },
  });

  instanteMs += 1000;
  await servicio.cambiarEstado(uidPrestador, segundaSolicitud.id, 'aceptar');

  instanteMs += 1000;
  await servicio.cambiarEstado(
    uidSolicitante,
    segundaSolicitud.id,
    'cancelar',
    'Surgió un viaje imprevisto fuera de la ciudad.',
  );

  avisosPrestador = await servicio.listarNotificaciones(uidPrestador);
  assert.equal(avisosPrestador.datos.length, 2);
  assert.equal(avisosPrestador.datos[0].tipo, 'servicio_cancelado');
  assert.equal(avisosPrestador.datos[0].titulo, 'Servicio cancelado');
  assert.ok(
    avisosPrestador.datos[0].mensaje.includes(
      'Surgió un viaje imprevisto fuera de la ciudad.',
    ),
  );
});

test('Notificaciones (Módulo 2): permisos, lectura idempotente, paginación estable y atomicidad ante fallos', async () => {
  const almacen = new AlmacenEnMemoria();
  let instanteMs = Date.parse('2026-11-10T12:00:00.000Z');
  const reloj = () => new Date(instanteMs);
  const servicio = new ServicioHelpi(almacen, reloj);

  const base = crearEscenarioBase();
  almacen.datos = base.almacen.datos;
  const { solicitudId, uidSolicitante, uidPrestador, uidTercero } = base;

  // Generar 3 avisos para uidSolicitante (2 de ellos con la misma marca de tiempo para probar desempate por id)
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar');
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'iniciar');
  instanteMs += 5000;
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'finalizar');

  // También generar 1 aviso para uidPrestador para comprobar filtrado por usuario antes de paginar
  instanteMs += 5000;
  await servicio.cambiarEstado(uidSolicitante, solicitudId, 'confirmar');

  // 1. Paginación estable de más reciente a más antiguo filtrando por uidSolicitante
  const pagina1 = await servicio.listarNotificaciones(
    uidSolicitante,
    undefined,
    2,
  );
  assert.equal(pagina1.datos.length, 2);
  assert.ok(pagina1.siguienteCursor);
  assert.equal(pagina1.datos[0].tipo, 'finalizacion_solicitada');

  const pagina2 = await servicio.listarNotificaciones(
    uidSolicitante,
    pagina1.siguienteCursor,
    2,
  );
  assert.equal(pagina2.datos.length, 1);
  assert.equal(pagina2.siguienteCursor, null);

  // Verificar que los 3 avisos de las dos páginas son distintos y todos pertenecen a uidSolicitante
  const idsPaginados = [
    ...pagina1.datos.map((d) => d.id),
    ...pagina2.datos.map((d) => d.id),
  ];
  assert.equal(new Set(idsPaginados).size, 3);

  // 2. Permisos: otro usuario (uidPrestador o uidTercero) NO puede marcar una notificación de uidSolicitante
  const idAvisoSolicitante = pagina1.datos[0].id;
  await assert.rejects(
    async () =>
      servicio.marcarNotificacionLeida(uidPrestador, idAvisoSolicitante),
    (err) => err instanceof ErrorHelpi && err.estado === 404,
  );
  await assert.rejects(
    async () =>
      servicio.marcarNotificacionLeida(uidTercero, idAvisoSolicitante),
    (err) => err instanceof ErrorHelpi && err.estado === 404,
  );

  // 3. Marcar como leída es idempotente y conserva la primera fecha de lectura
  instanteMs = Date.parse('2026-11-10T14:00:00.000Z');
  const primeraLectura = await servicio.marcarNotificacionLeida(
    uidSolicitante,
    idAvisoSolicitante,
  );
  assert.equal(primeraLectura.correcto, true);
  assert.equal(primeraLectura.datos.leida, true);
  assert.equal(
    primeraLectura.datos.fechaLectura,
    '2026-11-10T14:00:00.000Z',
  );

  // Avanza el reloj 1 hora y vuelve a marcar como leída
  instanteMs = Date.parse('2026-11-10T15:00:00.000Z');
  const segundaLectura = await servicio.marcarNotificacionLeida(
    uidSolicitante,
    idAvisoSolicitante,
  );
  assert.equal(segundaLectura.correcto, true);
  assert.equal(segundaLectura.datos.leida, true);
  assert.equal(
    segundaLectura.datos.fechaLectura,
    '2026-11-10T14:00:00.000Z',
  );

  // 4. Ausencia de avisos y reversión cuando falla una transacción
  const solicitudNueva = await servicio.crear(uidSolicitante, {
    titulo: 'Limpieza de jardín frontal',
    descripcion: 'Podar césped y recoger hojas secas del jardín frontal.',
    categoria: 'Hogar',
    ciudad: 'Riobamba',
    sector: 'Norte',
    horario: 'Por la mañana',
    fechaServicio: '2026-11-24T09:00:00.000Z',
    montoCentavos: 2000,
    ubicacion: { latitud: -1.67, longitud: -78.65 },
  });

  // Simular fallo al escribir en la colección notificaciones dentro de la transacción
  almacen.fallarEnRuta = 'notificaciones/';
  await assert.rejects(
    async () =>
      servicio.cambiarEstado(uidPrestador, solicitudNueva.id, 'aceptar'),
  );
  almacen.fallarEnRuta = null;

  // Verificar que ni la solicitud cambió de estado ni se creó notificación huérfana
  const solicitudSinCambios = await almacen.get(
    `solicitudes/${solicitudNueva.id}`,
  );
  assert.equal(solicitudSinCambios.estado, 'Publicada');
  assert.equal(solicitudSinCambios.prestadorUid, null);

  const avisosTrasFallo = await servicio.listarNotificaciones(uidSolicitante);
  assert.equal(avisosTrasFallo.datos.length, 3);
});

test('Rutas HTTP /api/notificaciones: toma el UID del token autenticado e ignora parámetros externos', async () => {
  const http = require('node:http');
  const { Socket } = require('node:net');
  const { crearAplicacion } = require('../src/aplicacion');
  const {
    almacen,
    servicio,
    solicitudId,
    uidSolicitante,
    uidPrestador,
  } = crearEscenarioBase();

  await servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar');

  const authFalso = {
    verifyIdToken: async (token) => {
      if (token === 'token_solicitante') return { uid: uidSolicitante };
      if (token === 'token_prestador') return { uid: uidPrestador };
      throw new Error('Token inválido');
    },
  };

  const app = crearAplicacion({ almacen, auth: authFalso, db: {} });

  function peticionExpress({ metodo = 'GET', url, headers = {}, body }) {
    return new Promise((resolve, reject) => {
      const socket = new Socket();
      const req = new http.IncomingMessage(socket);
      req.method = metodo;
      req.url = url;
      req.headers = Object.fromEntries(
        Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v]),
      );
      if (body != null) {
        req.body = body;
      }
      req.push(null);

      const res = new http.ServerResponse(req);
      const chunks = [];
      res.write = (chunk) => {
        if (chunk) chunks.push(Buffer.from(chunk));
        return true;
      };
      res.end = (chunk) => {
        if (chunk) chunks.push(Buffer.from(chunk));
        const raw = Buffer.concat(chunks).toString('utf8');
        // Extraer el cuerpo JSON después de las cabeceras HTTP si existen, o directo
        const idx = raw.indexOf('\r\n\r\n');
        const cuerpoTexto = idx !== -1 ? raw.slice(idx + 4) : raw;
        resolve({
          status: res.statusCode,
          json: () => JSON.parse(cuerpoTexto),
        });
        return res;
      };

      app.handle(req, res, reject);
    });
  }

  // El prestador intenta consultar pasando ?uid=solicitante_123 en query:
  // el servidor debe ignorar query.uid y usar el UID del token (uidPrestador -> 0 avisos)
  const respPrestador = await peticionExpress({
    metodo: 'GET',
    url: `/api/notificaciones?uid=${uidSolicitante}`,
    headers: { Authorization: 'Bearer token_prestador' },
  });
  assert.equal(respPrestador.status, 200);
  const jsonPrestador = respPrestador.json();
  assert.equal(jsonPrestador.datos.length, 0);

  // El solicitante consulta con su token y recibe su notificación
  const respSolicitante = await peticionExpress({
    metodo: 'GET',
    url: '/api/notificaciones',
    headers: { Authorization: 'Bearer token_solicitante' },
  });
  assert.equal(respSolicitante.status, 200);
  const jsonSolicitante = respSolicitante.json();
  assert.equal(jsonSolicitante.datos.length, 1);
  const idNotif = jsonSolicitante.datos[0].id;

  // El prestador intenta marcar como leída la notificación del solicitante enviando uid en body -> 404
  const respIntruso = await peticionExpress({
    metodo: 'PATCH',
    url: `/api/notificaciones/${idNotif}`,
    headers: {
      Authorization: 'Bearer token_prestador',
    },
    body: { uid: uidSolicitante },
  });
  assert.equal(respIntruso.status, 404);

  // El solicitante marca su propia notificación -> 200
  const respMarcar = await peticionExpress({
    metodo: 'PATCH',
    url: `/api/notificaciones/${idNotif}`,
    headers: {
      Authorization: 'Bearer token_solicitante',
    },
  });
  assert.equal(respMarcar.status, 200);
  const jsonMarcar = respMarcar.json();
  assert.equal(jsonMarcar.correcto, true);
  assert.equal(jsonMarcar.datos.leida, true);
  assert.ok(jsonMarcar.datos.fechaLectura);
});

test('Edición de solicitudes (Módulo 3): autoría, estado Publicada, control de versión y protección de campos internos', async () => {
  const { servicio, solicitudId, uidSolicitante, uidPrestador } =
    crearEscenarioBase();

  // 1. Edición exitosa por el autor cuando está Publicada (version 1 -> 2)
  // Intenta inyectar campos internos maliciosos (prestadorUid, estado, pagoId) que el servidor debe ignorar
  const editada = await servicio.editar(uidSolicitante, solicitudId, {
    titulo: 'Reparación urgente de grifería y sifón',
    descripcion:
      'Se requiere cambiar el sifón completo y ajustar la llave de paso en cocina.',
    categoria: 'Reparaciones',
    ciudad: 'Riobamba',
    sector: 'La Politécnica',
    horario: '15:00 a 17:00',
    fechaServicio: '2026-11-18T15:00:00.000Z',
    montoCentavos: 3200,
    ubicacion: { latitud: -1.66, longitud: -78.66 },
    version: 1,
    prestadorUid: uidPrestador,
    estado: 'Completada',
    pagoId: 'pago_falso',
  });

  assert.equal(editada.version, 2);
  assert.equal(editada.titulo, 'Reparación urgente de grifería y sifón');
  assert.equal(
    editada.tituloNormalizado,
    'reparacion urgente de griferia y sifon',
  );
  assert.equal(editada.montoCentavos, 3200);
  assert.equal(editada.prestadorUid, null);
  assert.equal(editada.estado, 'Publicada');
  assert.equal(editada.pagoId, undefined);

  // 2. Otro usuario NO puede editar la solicitud ajena -> 403
  await assert.rejects(
    async () =>
      servicio.editar(uidPrestador, solicitudId, {
        titulo: 'Intento de edición ajena',
        descripcion:
          'Descripción válida pero enviada por quien no es propietario.',
        categoria: 'Reparaciones',
        ciudad: 'Riobamba',
        sector: 'Centro',
        horario: 'Por la mañana',
        fechaServicio: '2026-11-18T15:00:00.000Z',
        montoCentavos: 3000,
        ubicacion: { latitud: -1.67, longitud: -78.65 },
        version: 2,
      }),
    (err) => err instanceof ErrorHelpi && err.estado === 403,
  );

  // 3. Conflicto de versión (envía version: 1 cuando ya es 2) -> 409
  await assert.rejects(
    async () =>
      servicio.editar(uidSolicitante, solicitudId, {
        titulo: 'Edición con versión desactualizada',
        descripcion: 'Esta edición usa la versión anterior y debe rechazarse.',
        categoria: 'Reparaciones',
        ciudad: 'Riobamba',
        sector: 'Centro',
        horario: 'Por la mañana',
        fechaServicio: '2026-11-18T15:00:00.000Z',
        montoCentavos: 3000,
        ubicacion: { latitud: -1.67, longitud: -78.65 },
        version: 1,
      }),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );

  // 4. Conflicto entre edición y aceptación simultáneas:
  // El prestador acepta la solicitud mientras el solicitante tenía el formulario abierto en versión 2
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar');

  await assert.rejects(
    async () =>
      servicio.editar(uidSolicitante, solicitudId, {
        titulo: 'Intento de guardar tras aceptación',
        descripcion:
          'El solicitante intenta guardar cambios pero ya fue aceptada.',
        categoria: 'Reparaciones',
        ciudad: 'Riobamba',
        sector: 'Centro',
        horario: 'Por la mañana',
        fechaServicio: '2026-11-18T15:00:00.000Z',
        montoCentavos: 3500,
        ubicacion: { latitud: -1.67, longitud: -78.65 },
        version: 2,
      }),
    (err) => err instanceof ErrorHelpi && err.estado === 409,
  );

  // Verificar que la aceptación y los datos vigentes no fueron sobrescritos
  const vigente = await servicio.obtener(uidSolicitante, solicitudId);
  assert.equal(vigente.estado, 'Aceptada');
  assert.equal(vigente.prestadorUid, uidPrestador);
  assert.equal(vigente.titulo, 'Reparación urgente de grifería y sifón');
});

test('Duplicación de solicitudes (Módulo 3): nuevo documento limpio, rechazo de fecha vencida e idempotencia', async () => {
  const { almacen, servicio, solicitudId, uidSolicitante, uidPrestador } =
    crearEscenarioBase();

  // Avanzar la solicitud original hasta Cancelada para comprobar que NO copia estado ni campos internos
  await servicio.cambiarEstado(uidPrestador, solicitudId, 'aceptar');
  await servicio.cambiarEstado(
    uidSolicitante,
    solicitudId,
    'cancelar',
    'Cancelada para probar duplicación limpia.',
  );

  // 1.Otro usuario no puede duplicar una solicitud ajena -> 403
  await assert.rejects(
    async () =>
      servicio.duplicar(uidPrestador, solicitudId, {
        fechaServicio: '2026-11-25T16:00:00.000Z',
      }),
    (err) => err instanceof ErrorHelpi && err.estado === 403,
  );

  // 2. No permite duplicar sin especificar fechaServicio o con fecha vencida -> 400
  await assert.rejects(
    async () => servicio.duplicar(uidSolicitante, solicitudId, {}),
    (err) => err instanceof ErrorHelpi && err.estado === 400,
  );

  await assert.rejects(
    async () =>
      servicio.duplicar(uidSolicitante, solicitudId, {
        fechaServicio: '2026-11-01T10:00:00.000Z', // anterior al reloj fijo (2026-11-10)
      }),
    (err) => err instanceof ErrorHelpi && err.estado === 400,
  );

  // 3. Duplicación exitosa con claveIdempotencia
  const duplicada1 = await servicio.duplicar(uidSolicitante, solicitudId, {
    fechaServicio: '2026-11-25T16:00:00.000Z',
    montoCentavos: 2800,
    claveIdempotencia: 'intento_duplicar_001',
    estado: 'Completada', // debe ignorarse
    prestadorUid: uidPrestador, // debe ignorarse
  });

  assert.notEqual(duplicada1.id, solicitudId);
  assert.equal(duplicada1.solicitanteUid, uidSolicitante);
  assert.equal(duplicada1.prestadorUid, null);
  assert.equal(duplicada1.estado, 'Publicada');
  assert.equal(duplicada1.version, 1);
  assert.equal(duplicada1.montoCentavos, 2800);
  assert.equal(duplicada1.motivoCancelacion, undefined);
  assert.equal(duplicada1.finalizacionSolicitada, undefined);

  // 4. Reintento con la misma claveIdempotencia NO crea otro documento
  const reintentoDuplicada1 = await servicio.duplicar(
    uidSolicitante,
    solicitudId,
    {
      fechaServicio: '2026-11-25T16:00:00.000Z',
      montoCentavos: 2800,
      claveIdempotencia: 'intento_duplicar_001',
    },
  );
  assert.equal(reintentoDuplicada1.id, duplicada1.id);

  // 5. Nueva duplicación intencional con distinta claveIdempotencia SÍ crea otro documento
  const duplicada2 = await servicio.duplicar(uidSolicitante, solicitudId, {
    fechaServicio: '2026-11-28T10:00:00.000Z',
    claveIdempotencia: 'intento_duplicar_002',
  });
  assert.notEqual(duplicada2.id, duplicada1.id);

  // 6. La solicitud original permanece intacta en estado Cancelada
  const originalIntacta = await almacen.get(`solicitudes/${solicitudId}`);
  assert.equal(originalIntacta.estado, 'Cancelada');
  assert.equal(
    originalIntacta.motivoCancelacion,
    'Cancelada para probar duplicación limpia.',
  );
});

test('Filtros, búsqueda por prefijo, ordenamiento y paginación (Módulo 3): combinación antes de paginar y aislamiento', async () => {
  const almacen = new AlmacenEnMemoria();
  let instanteMs = Date.parse('2026-11-10T12:00:00.000Z');
  const servicio = new ServicioHelpi(almacen, () => new Date(instanteMs));

  const base = crearEscenarioBase();
  almacen.datos = base.almacen.datos;
  const { uidSolicitante, uidPrestador, uidTercero } = base;

  // Eliminar la solicitud base para controlar el conjunto exacto de pruebas
  almacen.datos.delete(`solicitudes/${base.solicitudId}`);

  // Crear 3 solicitudes de uidSolicitante con distintas fechas, categorías y títulos con tildes
  instanteMs += 1000;
  const sol1 = await servicio.crear(uidSolicitante, {
    titulo: 'Tutoría de Cálculo Diferencial',
    descripcion: 'Repaso práctico de límites y derivadas para examen parcial.',
    categoria: 'Tutorías',
    ciudad: 'Riobamba',
    sector: 'La Politécnica',
    horario: '14:00 a 16:00',
    fechaServicio: '2026-11-25T14:00:00.000Z',
    montoCentavos: 1500,
    ubicacion: { latitud: -1.66, longitud: -78.66 },
  });

  instanteMs += 1000;
  const sol2 = await servicio.crear(uidSolicitante, {
    titulo: 'Tutoría de Álgebra Lineal',
    descripcion: 'Matrices, determinantes y sistemas de ecuaciones lineales.',
    categoria: 'Tutorías',
    ciudad: 'Riobamba',
    sector: 'Centro',
    horario: '09:00 a 11:00',
    fechaServicio: '2026-11-18T09:00:00.000Z',
    montoCentavos: 1800,
    ubicacion: { latitud: -1.67, longitud: -78.65 },
  });

  instanteMs += 1000;
  const sol3 = await servicio.crear(uidSolicitante, {
    titulo: 'Reparación de enchufe en sala',
    descripcion: 'Revisión y cambio de tomacorriente doble en pared.',
    categoria: 'Reparaciones',
    ciudad: 'Riobamba',
    sector: 'Norte',
    horario: '16:00 a 17:00',
    fechaServicio: '2026-11-20T16:00:00.000Z',
    montoCentavos: 1200,
    ubicacion: { latitud: -1.65, longitud: -78.64 },
  });

  // Crear 1 solicitud de otro usuario (uidTercero) para verificar aislamiento entre cuentas
  instanteMs += 1000;
  const solAjena = await servicio.crear(uidTercero, {
    titulo: 'Tutoría de Física Clásica',
    descripcion: 'Cinemática y dinámica de partículas para primer semestre.',
    categoria: 'Tutorías',
    ciudad: 'Riobamba',
    sector: 'Centro',
    horario: '10:00 a 12:00',
    fechaServicio: '2026-11-19T10:00:00.000Z',
    montoCentavos: 2000,
    ubicacion: { latitud: -1.67, longitud: -78.65 },
  });

  // uidPrestador acepta sol2 -> sol2 pasa a estado 'Aceptada'
  instanteMs += 1000;
  await servicio.cambiarEstado(uidPrestador, sol2.id, 'aceptar');

  // 1. Búsqueda por prefijo normalizado ("tutoria", sin tilde) en solicitudes propias de uidSolicitante:
  // Debe devolver sol2 y sol1, pero NUNCA solAjena ni sol3
  const porPrefijo = await servicio.listar(uidSolicitante, {
    mias: 'true',
    busqueda: 'tutoria',
  });
  assert.equal(porPrefijo.datos.length, 2);
  assert.deepEqual(
    porPrefijo.datos.map((s) => s.id),
    [sol2.id, sol1.id],
  );

  // 2. Combinación de estado ('Publicada') + categoría ('Tutorías') + prefijo ('Tutoría'):
  // Solo sol1 sigue 'Publicada' (porque sol2 está 'Aceptada')
  const combinados = await servicio.listar(uidSolicitante, {
    mias: 'true',
    estado: 'Publicada',
    categoria: 'Tutorías',
    busqueda: 'Tutoría',
  });
  assert.equal(combinados.datos.length, 1);
  assert.equal(combinados.datos[0].id, sol1.id);

  // 3. Ordenar por fecha_servicio ascendente con paginación de límite 2:
  // Fechas de servicio de uidSolicitante: sol2 (18 nov), sol3 (20 nov), sol1 (25 nov)
  const pagFecha1 = await servicio.listar(uidSolicitante, {
    mias: 'true',
    orden: 'fecha_servicio',
    limite: '2',
  });
  assert.deepEqual(
    pagFecha1.datos.map((s) => s.id),
    [sol2.id, sol3.id],
  );
  assert.ok(pagFecha1.siguienteCursor);

  const pagFecha2 = await servicio.listar(uidSolicitante, {
    mias: 'true',
    orden: 'fecha_servicio',
    limite: '2',
    cursor: pagFecha1.siguienteCursor,
  });
  assert.deepEqual(
    pagFecha2.datos.map((s) => s.id),
    [sol1.id],
  );
  assert.equal(pagFecha2.siguienteCursor, null);

  // 4. En exploración de prestador (sin mias ni aceptadas):
  // Si consulta uidSolicitante, NO deben aparecer sus propias solicitudes (sol1, sol3), solo solAjena
  const exploracionSolicitante = await servicio.listar(uidSolicitante, {
    ciudad: 'Riobamba',
  });
  assert.deepEqual(
    exploracionSolicitante.datos.map((s) => s.id),
    [solAjena.id],
  );

  // 5. En servicios aceptados de uidPrestador (aceptadas: 'true'):
  // Solo aparece sol2
  const aceptadasPrestador = await servicio.listar(uidPrestador, {
    aceptadas: 'true',
  });
  assert.deepEqual(
    aceptadasPrestador.datos.map((s) => s.id),
    [sol2.id],
  );
});

test('Corrección de Términos y Mis servicios: aceptación, cambio de rol, preservación de perfil y protección por UID', async () => {
  const { crearAplicacion } = require('../src/aplicacion');
  const { almacen, uidSolicitante, uidPrestador } = crearEscenarioBase();

  const uidUsuario = 'usuario_flujo_terminos';
  await almacen.set(`usuarios/${uidUsuario}`, {
    uid: uidUsuario,
    nombre: 'Mariana Torres',
    telefono: '+593991234567',
    ciudad: 'Riobamba',
    sector: 'Centro',
    rol: 'solicitante',
    perfilCompleto: true,
    suspendido: false,
    terminosAceptados: null,
  });

  const authFalso = {
    verifyIdToken: async (token) => {
      if (token === 'token_mariana') return { uid: uidUsuario };
      if (token === 'token_solicitante') return { uid: uidSolicitante };
      if (token === 'token_prestador') return { uid: uidPrestador };
      throw new Error('Token inválido');
    },
  };

  const app = crearAplicacion({ almacen, auth: authFalso, db: {} });

  function peticionExpress({ metodo, url, headers = {}, body = null }) {
    return new Promise((resolve, reject) => {
      const urlObj = new URL(url, 'http://localhost');
      const query = Object.fromEntries(urlObj.searchParams.entries());
      const normHeaders = {};
      for (const [k, v] of Object.entries(headers)) {
        normHeaders[k.toLowerCase()] = v;
      }

      const req = {
        method: metodo,
        url: urlObj.pathname + urlObj.search,
        originalUrl: urlObj.pathname + urlObj.search,
        path: urlObj.pathname,
        query,
        headers: normHeaders,
        body: body ?? {},
        get(nombre) {
          return normHeaders[nombre.toLowerCase()];
        },
      };

      const resHeaders = {};
      const res = {
        statusCode: 200,
        set(clave, valor) {
          resHeaders[clave.toLowerCase()] = valor;
          return this;
        },
        vary() {
          return this;
        },
        status(codigo) {
          this.statusCode = codigo;
          return this;
        },
        sendStatus(codigo) {
          this.statusCode = codigo;
          resolve({ status: this.statusCode, json: () => ({}) });
          return this;
        },
        json(datos) {
          resolve({
            status: this.statusCode,
            json: () => datos,
          });
          return this;
        },
      };

      app.handle(req, res, reject);
    });
  }

  // 1. Antes de aceptar términos, Mis servicios rechaza con 403
  const sinAceptar = await peticionExpress({
    metodo: 'GET',
    url: '/api/solicitudes?mias=true',
    headers: { Authorization: 'Bearer token_mariana' },
  });
  assert.equal(sinAceptar.status, 403);
  assert.equal(
    sinAceptar.json().mensaje,
    'Debes aceptar los Términos y condiciones vigentes para continuar.',
  );

  // 2. Rechazar términos vencidos o de otra versión (ej. v0.9)
  const intentoVersionAntigua = await peticionExpress({
    metodo: 'POST',
    url: '/api/terminos/aceptar',
    headers: { Authorization: 'Bearer token_mariana' },
    body: {
      versionTerminos: 'v0.9',
      versionPrivacidad: 'v1.0',
    },
  });
  assert.equal(intentoVersionAntigua.status, 400);

  // 3. Impedir que un usuario acepte en nombre de otro UID enviando uid en el cuerpo:
  // uidPrestador envía uid: uidUsuario en el body, pero el servidor solo registra en uidPrestador
  const intentoSuplantarAceptacion = await peticionExpress({
    metodo: 'POST',
    url: '/api/terminos/aceptar',
    headers: { Authorization: 'Bearer token_prestador' },
    body: {
      uid: uidUsuario,
      versionTerminos: 'v1.0',
      versionPrivacidad: 'v1.0',
    },
  });
  assert.equal(intentoSuplantarAceptacion.status, 200);
  assert.equal(intentoSuplantarAceptacion.json().datos.uid, uidPrestador);

  // Mariana sigue sin términos aceptados porque la suplantación fue ignorada
  const perfilMarianaAunSinTerminos = await almacen.get(`usuarios/${uidUsuario}`);
  assert.equal(perfilMarianaAunSinTerminos.terminosAceptados, null);

  // 4. Mariana acepta la versión vigente v1.0 con su propio token y accede inmediatamente a Mis servicios
  const aceptacionMariana = await peticionExpress({
    metodo: 'POST',
    url: '/api/terminos/aceptar',
    headers: { Authorization: 'Bearer token_mariana' },
    body: {
      versionTerminos: 'v1.0',
      versionPrivacidad: 'v1.0',
    },
  });
  assert.equal(aceptacionMariana.status, 200);
  assert.equal(aceptacionMariana.json().datos.uid, uidUsuario);
  assert.equal(aceptacionMariana.json().datos.versionTerminos, 'v1.0');
  assert.equal(aceptacionMariana.json().datos.versionPrivacidad, 'v1.0');
  assert.ok(aceptacionMariana.json().datos.fechaAceptacion);

  const misServiciosSolicitante = await peticionExpress({
    metodo: 'GET',
    url: '/api/solicitudes?mias=true',
    headers: { Authorization: 'Bearer token_mariana' },
  });
  assert.equal(misServiciosSolicitante.status, 200);
  assert.ok(Array.isArray(misServiciosSolicitante.json().datos));

  // Compatibilidad con perfiles previos que guardaron documentoId = 'terminos_y_privacidad_helpi'
  const docMariana = await almacen.get(`usuarios/${uidUsuario}`);
  await almacen.set(`usuarios/${uidUsuario}`, {
    ...docMariana,
    terminosAceptados: {
      ...docMariana.terminosAceptados,
      documentoId: 'terminos_y_privacidad_helpi',
    },
  });

  const misServiciosConIdLegado = await peticionExpress({
    metodo: 'GET',
    url: '/api/solicitudes?mias=true',
    headers: { Authorization: 'Bearer token_mariana' },
  });
  assert.equal(misServiciosConIdLegado.status, 200);

  // 5. Cambiar de rol (solicitante -> prestador) y actualizar otros campos del perfil
  // sin perder ni sobrescribir la aceptación válida (incluso si el body envía terminosAceptados: null)
  const cambioRolYPerfil = await peticionExpress({
    metodo: 'PATCH',
    url: '/api/perfil',
    headers: { Authorization: 'Bearer token_mariana' },
    body: {
      rol: 'prestador',
      presentacion: 'Ingeniera en sistemas con experiencia en redes.',
      disponibilidad: 'Fines de semana',
      terminosAceptados: null,
      uid: 'otro_uid_falso',
    },
  });
  assert.equal(cambioRolYPerfil.status, 200);
  assert.equal(cambioRolYPerfil.json().datos.uid, uidUsuario);
  assert.equal(cambioRolYPerfil.json().datos.rol, 'prestador');
  assert.equal(
    cambioRolYPerfil.json().datos.presentacion,
    'Ingeniera en sistemas con experiencia en redes.',
  );
  assert.ok(cambioRolYPerfil.json().datos.terminosAceptados);
  assert.equal(
    cambioRolYPerfil.json().datos.terminosAceptados.versionTerminos,
    'v1.0',
  );

  // Tras cambiar al rol prestador, Mis servicios (aceptadas=true) sigue funcionando sin pedir términos otra vez
  const misServiciosPrestador = await peticionExpress({
    metodo: 'GET',
    url: '/api/solicitudes?aceptadas=true',
    headers: { Authorization: 'Bearer token_mariana' },
  });
  assert.equal(misServiciosPrestador.status, 200);
  assert.ok(Array.isArray(misServiciosPrestador.json().datos));

  // 6. Impedir que un usuario consulte Mis servicios en nombre de otro UID enviando uid en query
  const consultaAjena = await peticionExpress({
    metodo: 'GET',
    url: `/api/solicitudes?mias=true&uid=${uidSolicitante}&solicitanteUid=${uidSolicitante}`,
    headers: { Authorization: 'Bearer token_mariana' },
  });
  assert.equal(consultaAjena.status, 200);
  // Mariana no tiene solicitudes propias, por lo que no debe recibir las de uidSolicitante
  assert.equal(consultaAjena.json().datos.length, 0);
});

test('AlmacenFirestore real sin índices compuestos desplegados y con objetos Timestamp: carga Mis servicios y Notificaciones sin error 500', async () => {
  const { AlmacenFirestore } = require('../src/almacen_firestore');
  const { crearAplicacion } = require('../src/aplicacion');

  const uidSolicitante = 'uid_solicitante_firestore';
  const uidPrestador = 'uid_prestador_firestore';

  // Simula el comportamiento real de Cloud Firestore cuando no se han desplegado índices compuestos:
  // cualquier consulta que combine .where() con .orderBy() o múltiples .where() lanza code 9 FAILED_PRECONDITION.
  const documentos = new Map([
    [
      `usuarios/${uidSolicitante}`,
      {
        uid: uidSolicitante,
        nombre: 'Elena Solicitante',
        rol: 'solicitante',
        perfilCompleto: true,
        suspendido: false,
        terminosAceptados: {
          uid: uidSolicitante,
          documentoId: 'terminos_condiciones_helpi',
          versionTerminos: 'v1.0',
          avisoPrivacidadId: 'aviso_privacidad_helpi',
          versionPrivacidad: 'v1.0',
          // Simula un objeto Timestamp de Firestore con .toDate()
          fechaAceptacion: {
            toDate: () => new Date('2026-11-12T10:00:00.000Z'),
          },
        },
      },
    ],
    [
      'solicitudes/sol_a',
      {
        titulo: 'Instalación de impresora Wi-Fi',
        descripcion: 'Configuración de impresora en red doméstica para dos equipos.',
        categoria: 'Soporte técnico',
        ciudad: 'Riobamba',
        sector: 'Centro',
        horario: '10:00 a 12:00',
        fechaServicio: '2026-11-20T10:00:00.000Z',
        montoCentavos: 1500,
        ubicacion: { latitud: -1.67, longitud: -78.65 },
        solicitanteUid: uidSolicitante,
        prestadorUid: null,
        estado: 'Publicada',
        creada: '2026-11-12T11:00:00.000Z',
        version: 1,
      },
    ],
    [
      'solicitudes/sol_b',
      {
        titulo: 'Instalación de router y repetidor',
        descripcion: 'Mejorar cobertura de señal en segundo piso de vivienda.',
        categoria: 'Soporte técnico',
        ciudad: 'Riobamba',
        sector: 'Norte',
        horario: '15:00 a 17:00',
        fechaServicio: '2026-11-18T15:00:00.000Z',
        montoCentavos: 2200,
        ubicacion: { latitud: -1.66, longitud: -78.64 },
        solicitanteUid: uidSolicitante,
        prestadorUid: uidPrestador,
        estado: 'Aceptada',
        creada: '2026-11-12T14:00:00.000Z',
        version: 2,
      },
    ],
    [
      'notificaciones/notif_1',
      {
        uid: uidSolicitante,
        solicitudId: 'sol_b',
        tipo: 'solicitud_aceptada',
        titulo: 'Solicitud aceptada',
        mensaje: 'Un prestador aceptó tu solicitud.',
        leida: false,
        creada: '2026-11-12T14:05:00.000Z',
      },
    ],
  ]);

  function crearConsultaFirestoreSimulada(coleccion, filtros = [], tieneOrderBy = false) {
    return {
      where(campo, op, valor) {
        return crearConsultaFirestoreSimulada(
          coleccion,
          [...filtros, { campo, op, valor }],
          tieneOrderBy,
        );
      },
      orderBy() {
        return crearConsultaFirestoreSimulada(coleccion, filtros, true);
      },
      startAfter() {
        return this;
      },
      limit() {
        return this;
      },
      async get() {
        if (tieneOrderBy || filtros.length > 1) {
          const errorIndice = new Error(
            '9 FAILED_PRECONDITION: The query requires an index.',
          );
          errorIndice.code = 9;
          throw errorIndice;
        }

        const docs = [];
        for (const [ruta, datos] of documentos.entries()) {
          if (!ruta.startsWith(`${coleccion}/`)) continue;
          const id = ruta.slice(coleccion.length + 1);
          const cumple = filtros.every((f) => datos[f.campo] === f.valor);
          if (cumple) {
            docs.push({
              id,
              exists: true,
              data: () => datos,
            });
          }
        }
        return { docs, size: docs.length };
      },
    };
  }

  const dbSimulada = {
    doc(ruta) {
      return {
        async get() {
          const valor = documentos.get(ruta);
          return {
            exists: valor !== undefined,
            data: () => valor,
          };
        },
        async set(datos) {
          documentos.set(ruta, datos);
        },
      };
    },
    collection(nombre) {
      return crearConsultaFirestoreSimulada(nombre);
    },
    async runTransaction(operacion) {
      return operacion({
        async get(ref) {
          return ref.get();
        },
        set(ref, datos) {
          ref.set(datos);
        },
      });
    },
  };

  const almacen = new AlmacenFirestore(dbSimulada, () => '__name__');
  const auth = {
    verifyIdToken: async () => ({ uid: uidSolicitante }),
  };

  const app = crearAplicacion({ almacen, auth, db: dbSimulada });

  function peticion(url) {
    return new Promise((resolve, reject) => {
      const urlObj = new URL(url, 'http://localhost');
      const query = Object.fromEntries(urlObj.searchParams.entries());
      const req = {
        method: 'GET',
        url: urlObj.pathname + urlObj.search,
        originalUrl: urlObj.pathname + urlObj.search,
        path: urlObj.pathname,
        query,
        headers: { authorization: 'Bearer token_valido' },
        body: {},
        get(h) {
          return this.headers[h.toLowerCase()];
        },
      };
      const res = {
        statusCode: 200,
        set() {
          return this;
        },
        vary() {
          return this;
        },
        status(c) {
          this.statusCode = c;
          return this;
        },
        json(d) {
          resolve({ status: this.statusCode, body: d });
          return this;
        },
      };
      app.handle(req, res, reject);
    });
  }

  // 1. Cargar Mis servicios (mias=true&orden=recientes) devuelve 200 y ordena de más reciente a más antigua
  const respMisServicios = await peticion(
    '/api/solicitudes?mias=true&orden=recientes',
  );
  assert.equal(respMisServicios.status, 200);
  assert.deepEqual(
    respMisServicios.body.datos.map((s) => s.id),
    ['sol_b', 'sol_a'],
  );

  // 2. Filtrar por estado y prefijo sin índice compuesto en Firestore
  const respFiltrado = await peticion(
    '/api/solicitudes?mias=true&estado=Publicada&busqueda=instalacion',
  );
  assert.equal(respFiltrado.status, 200);
  assert.deepEqual(
    respFiltrado.body.datos.map((s) => s.id),
    ['sol_a'],
  );

  // 3. Cargar Notificaciones sin índice compuesto en Firestore devuelve 200
  const respNotificaciones = await peticion('/api/notificaciones');
  assert.equal(respNotificaciones.status, 200);
  assert.equal(respNotificaciones.body.datos.length, 1);
  assert.equal(respNotificaciones.body.datos[0].id, 'notif_1');
});

test('Módulo 4: edición de perfil sin pérdida de términos, calificaciones con paginación y privacidad, y eliminación de cuenta protegida por servicios activos', async () => {
  const { crearAplicacion } = require('../src/aplicacion');
  let instanteMs = Date.parse('2026-11-12T10:00:00.000Z');
  const almacen = new AlmacenEnMemoria();
  const base = crearEscenarioBase();
  almacen.datos = base.almacen.datos;
  const { uidSolicitante, uidPrestador, uidTercero, solicitudId } = base;

  // Añadir datos privados al perfil del prestador y del solicitante para verificar que no se expongan ni se borren al editar
  const docPrestador = await almacen.get(`usuarios/${uidPrestador}`);
  await almacen.set(`usuarios/${uidPrestador}`, {
    ...docPrestador,
    correo: 'pedro.privado@correo.ec',
    telefono: '+593998887777',
    ciudad: 'Riobamba',
    sector: 'Centro',
  });

  const docSolicitante = await almacen.get(`usuarios/${uidSolicitante}`);
  await almacen.set(`usuarios/${uidSolicitante}`, {
    ...docSolicitante,
    correo: 'ana.privada@correo.ec',
    telefono: '+593991112222',
    ciudad: 'Riobamba',
    sector: 'Norte',
  });

  // Asegurar que la solicitud base tenga fecha futura respecto al reloj del sistema
  const docSolicitudBase = await almacen.get(`solicitudes/${solicitudId}`);
  await almacen.set(`solicitudes/${solicitudId}`, {
    ...docSolicitudBase,
    fechaServicio: '2026-11-25T15:00:00.000Z',
  });

  const usuariosEliminadosAuth = [];
  const authFalso = {
    verifyIdToken: async (token) => {
      if (token === 'token_solicitante') return { uid: uidSolicitante };
      if (token === 'token_prestador') return { uid: uidPrestador };
      if (token === 'token_tercero') return { uid: uidTercero };
      throw new Error('Token inválido');
    },
    deleteUser: async (uid) => {
      usuariosEliminadosAuth.push(uid);
    },
  };

  const app = crearAplicacion({ almacen, auth: authFalso, db: {} });

  function peticionExpress({ metodo, url, token, body = null }) {
    return new Promise((resolve, reject) => {
      const urlObj = new URL(url, 'http://localhost');
      const query = Object.fromEntries(urlObj.searchParams.entries());
      const headers = token ? { authorization: `Bearer ${token}` } : {};
      const req = {
        method: metodo,
        url: urlObj.pathname + urlObj.search,
        originalUrl: urlObj.pathname + urlObj.search,
        path: urlObj.pathname,
        query,
        headers,
        body: body ?? {},
        get(h) {
          return this.headers[h.toLowerCase()];
        },
      };
      const res = {
        statusCode: 200,
        set() {
          return this;
        },
        vary() {
          return this;
        },
        status(c) {
          this.statusCode = c;
          return this;
        },
        json(d) {
          resolve({ status: this.statusCode, body: d });
          return this;
        },
      };
      app.handle(req, res, reject);
    });
  }

  // 1. Edición de perfil y cambio de rol preservando UID, correo autenticado y aceptación de términos
  const respEditarPerfil = await peticionExpress({
    metodo: 'PATCH',
    url: '/api/perfil',
    token: 'token_prestador',
    body: {
      nombre: 'Pedro Morales Actualizado',
      telefono: '+593987654321',
      ciudad: 'Riobamba',
      sector: 'Parque Infantil',
      presentacion: 'Técnico electricista y plomero con 8 años de experiencia.',
      disponibilidad: 'Lunes a sábado',
      categorias: ['Reparaciones', 'Hogar'],
      // Intento de sobrescribir campos protegidos que debe ignorarse:
      uid: 'uid_falso',
      correo: 'impostor@correo.ec',
      terminosAceptados: null,
      promedio: 5.0,
      totalCalificaciones: 999,
    },
  });
  assert.equal(respEditarPerfil.status, 200);
  assert.equal(respEditarPerfil.body.datos.uid, uidPrestador);
  assert.equal(respEditarPerfil.body.datos.correo, 'pedro.privado@correo.ec');
  assert.equal(respEditarPerfil.body.datos.nombre, 'Pedro Morales Actualizado');
  assert.equal(respEditarPerfil.body.datos.telefono, '+593987654321');
  assert.ok(respEditarPerfil.body.datos.terminosAceptados);
  assert.equal(
    respEditarPerfil.body.datos.terminosAceptados.versionTerminos,
    'v1.0',
  );
  assert.notEqual(respEditarPerfil.body.datos.totalCalificaciones, 999);

  // 2. Calificación rechazada antes de completar el servicio (está Publicada -> 409)
  const calificarAntesDeTiempo = await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${solicitudId}/calificaciones`,
    token: 'token_solicitante',
    body: { estrellas: 5, comentario: 'Intento antes de completar.' },
  });
  assert.equal(calificarAntesDeTiempo.status, 409);

  // 3. Eliminación de cuenta bloqueada cuando existen servicios activos (solicitudId está Publicada -> 409)
  const eliminarConServicioPublicada = await peticionExpress({
    metodo: 'DELETE',
    url: '/api/perfil',
    token: 'token_solicitante',
    body: { uid: uidTercero }, // intenta pasar otro UID en body
  });
  assert.equal(eliminarConServicioPublicada.status, 409);
  assert.match(
    eliminarConServicioPublicada.body.mensaje,
    /servicio\(s\) activo\(s\)/,
  );
  assert.equal(usuariosEliminadosAuth.length, 0);

  // Avanzar solicitudId a Aceptada y comprobar que tampoco el prestador puede eliminar su cuenta mientras esté activa
  await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${solicitudId}/aceptar`,
    token: 'token_prestador',
  });

  const eliminarPrestadorConServicioActivo = await peticionExpress({
    metodo: 'DELETE',
    url: '/api/perfil',
    token: 'token_prestador',
  });
  assert.equal(eliminarPrestadorConServicioActivo.status, 409);

  // Avanzar solicitudId hasta Completada
  await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${solicitudId}/iniciar`,
    token: 'token_prestador',
  });
  await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${solicitudId}/finalizar`,
    token: 'token_prestador',
  });
  await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${solicitudId}/confirmar`,
    token: 'token_solicitante',
  });

  // 4. Permisos de calificación: ni un tercero ni el propio prestador pueden calificar al prestador -> 403
  const calificarPorTercero = await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${solicitudId}/calificaciones`,
    token: 'token_tercero',
    body: { estrellas: 5, comentario: 'No participé.' },
  });
  assert.equal(calificarPorTercero.status, 403);

  const calificarPorPrestador = await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${solicitudId}/calificaciones`,
    token: 'token_prestador',
    body: { estrellas: 5, comentario: 'Me autocalifico.' },
  });
  assert.equal(calificarPorPrestador.status, 403);

  // 5. El solicitante califica válidamente al prestador (5 estrellas + comentario)
  const calificarValida = await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${solicitudId}/calificaciones`,
    token: 'token_solicitante',
    body: {
      estrellas: 5,
      comentario: 'Excelente trabajo, dejó la tubería impecable y llegó puntual.',
    },
  });
  assert.equal(calificarValida.status, 200);
  assert.equal(calificarValida.body.estrellas, 5);
  assert.equal(calificarValida.body.destinoUid, uidPrestador);
  assert.equal(calificarValida.body.autorNombre, 'Ana');

  // 6. Intento duplicado de calificar la misma solicitud es rechazado -> 409
  const calificarDuplicada = await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${solicitudId}/calificaciones`,
    token: 'token_solicitante',
    body: { estrellas: 4, comentario: 'Segundo intento.' },
  });
  assert.equal(calificarDuplicada.status, 409);

  // Crear, completar y calificar una segunda solicitud para probar promedio y paginación de reseñas
  instanteMs += 60000;
  const crearSegunda = await peticionExpress({
    metodo: 'POST',
    url: '/api/solicitudes',
    token: 'token_solicitante',
    body: {
      titulo: 'Revisión de interruptor en pasillo',
      descripcion: 'El interruptor del pasillo hace falso contacto al encender.',
      categoria: 'Reparaciones',
      ciudad: 'Riobamba',
      sector: 'Centro',
      horario: '16:00 a 17:00',
      fechaServicio: '2026-11-22T16:00:00.000Z',
      montoCentavos: 1200,
      ubicacion: { latitud: -1.67, longitud: -78.65 },
    },
  });
  const idSegunda = crearSegunda.body.id;

  await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${idSegunda}/aceptar`,
    token: 'token_prestador',
  });
  await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${idSegunda}/iniciar`,
    token: 'token_prestador',
  });
  await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${idSegunda}/finalizar`,
    token: 'token_prestador',
  });
  await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${idSegunda}/confirmar`,
    token: 'token_solicitante',
  });
  await peticionExpress({
    metodo: 'POST',
    url: `/api/solicitudes/${idSegunda}/calificaciones`,
    token: 'token_solicitante',
    body: {
      estrellas: 4,
      comentario: 'Buen servicio y rápido.',
    },
  });

  // 7. Consulta de perfil público y reseñas paginadas del prestador sin exponer datos privados
  const perfilPublico = await peticionExpress({
    metodo: 'GET',
    url: `/api/perfiles/${uidPrestador}`,
    token: 'token_solicitante',
  });
  assert.equal(perfilPublico.status, 200);
  assert.equal(perfilPublico.body.datos.promedio, 4.5);
  assert.equal(perfilPublico.body.datos.totalCalificaciones, 2);
  assert.equal(perfilPublico.body.datos.telefono, undefined);
  assert.equal(perfilPublico.body.datos.correo, undefined);

  const pag1 = await peticionExpress({
    metodo: 'GET',
    url: `/api/perfiles/${uidPrestador}/calificaciones?limite=1`,
    token: 'token_solicitante',
  });
  assert.equal(pag1.status, 200);
  assert.equal(pag1.body.promedio, 4.5);
  assert.equal(pag1.body.totalCalificaciones, 2);
  assert.equal(pag1.body.datos.length, 1);
  assert.ok(pag1.body.siguienteCursor);
  assert.equal(pag1.body.datos[0].telefono, undefined);
  assert.equal(pag1.body.datos[0].correo, undefined);

  const pag2 = await peticionExpress({
    metodo: 'GET',
    url: `/api/perfiles/${uidPrestador}/calificaciones?limite=1&cursor=${encodeURIComponent(pag1.body.siguienteCursor)}`,
    token: 'token_solicitante',
  });
  assert.equal(pag2.status, 200);
  assert.equal(pag2.body.datos.length, 1);
  assert.notEqual(pag2.body.datos[0].id, pag1.body.datos[0].id);
  assert.equal(pag2.body.siguienteCursor, null);

  // 8. Ahora que uidSolicitante no tiene servicios activos (ambos están Completada), puede eliminar su cuenta:
  // Verifica que usa el UID del token (uidSolicitante), elimina el perfil personal y Auth, y anonimiza sus reseñas
  const eliminarExitosa = await peticionExpress({
    metodo: 'DELETE',
    url: '/api/perfil',
    token: 'token_solicitante',
    body: { uid: uidPrestador }, // intento de borrar otro UID que el servidor debe ignorar
  });
  assert.equal(eliminarExitosa.status, 200);
  assert.deepEqual(usuariosEliminadosAuth, [uidSolicitante]);

  const perfilSolicitanteBorrado = await almacen.get(
    `usuarios/${uidSolicitante}`,
  );
  assert.equal(perfilSolicitanteBorrado, null);

  // El perfil y promedio del prestador siguen intactos, y las reseñas ahora muestran "Usuario eliminado"
  const resenasTrasEliminacion = await peticionExpress({
    metodo: 'GET',
    url: `/api/perfiles/${uidPrestador}/calificaciones`,
    token: 'token_prestador',
  });
  assert.equal(resenasTrasEliminacion.status, 200);
  assert.equal(resenasTrasEliminacion.body.promedio, 4.5);
  assert.equal(resenasTrasEliminacion.body.totalCalificaciones, 2);
  assert.ok(
    resenasTrasEliminacion.body.datos.every(
      (r) => r.autorNombre === 'Usuario eliminado',
    ),
  );
});





// -----------------------------------------------------------------------------
// Administración
// -----------------------------------------------------------------------------

function escenarioAdmin() {
  const almacen = new AlmacenEnMemoria();
  let ahora = new Date('2026-11-18T12:00:00.000Z');
  const servicio = new ServicioHelpi(almacen, () => ahora);
  const admin = { uid: 'admin_1', correo: 'admin@helpi.ec' };

  almacen.datos.set('usuarios/usuario_1', {
    nombre: 'Ana Pérez',
    rol: 'solicitante',
    suspendido: false,
  });
  almacen.datos.set('usuarios/prestador_1', {
    nombre: 'Luis Gómez',
    rol: 'prestador',
    totalCalificaciones: 2,
    sumaCalificaciones: 9,
    promedio: 4.5,
    reportesActivos: 2,
  });

  return {
    almacen,
    servicio,
    admin,
    avanzar: (dias) => {
      ahora = new Date(ahora.getTime() + dias * 24 * 60 * 60 * 1000);
    },
  };
}

function documentosDe(almacen, coleccion) {
  return [...almacen.datos.entries()]
    .filter(([ruta]) => ruta.startsWith(`${coleccion}/`))
    .map(([, doc]) => doc);
}

test('Admin: suspensión temporal vence sola y se puede levantar', async () => {
  const { almacen, servicio, admin, avanzar } = escenarioAdmin();

  const resultado = await servicio.suspenderUsuarioAdmin(admin, 'usuario_1', {
    dias: 3,
    motivo: 'Lenguaje ofensivo',
  });

  assert.equal(resultado.suspendidoHasta, '2026-11-21T12:00:00.000Z');

  const perfil = await almacen.get('usuarios/usuario_1');
  assert.equal(perfil.suspendido, true);
  assert.equal(perfil.motivoSuspension, 'Lenguaje ofensivo');
  assert.equal(perfil.nombre, 'Ana Pérez');
  assert.equal(estaSuspendido(perfil, new Date('2026-11-20T12:00:00Z')), true);
  assert.equal(estaSuspendido(perfil, new Date('2026-11-22T12:00:00Z')), false);

  // Antes de vencer no se levanta.
  assert.equal(await servicio.levantarSuspensionVencida('usuario_1'), false);

  avanzar(4);
  assert.equal(await servicio.levantarSuspensionVencida('usuario_1'), true);

  const levantado = await almacen.get('usuarios/usuario_1');
  assert.equal(levantado.suspendido, false);
  assert.equal(levantado.suspendidoHasta, null);

  const historial = documentosDe(almacen, 'acciones_admin');
  assert.equal(historial.length, 1);
  assert.equal(historial[0].accion, 'suspension_temporal');
  assert.equal(historial[0].detalle.dias, 3);
});

test('Admin: suspensión indefinida, validaciones y reactivación', async () => {
  const { almacen, servicio, admin } = escenarioAdmin();

  await assert.rejects(
    servicio.suspenderUsuarioAdmin(admin, admin.uid, {}),
    (e) => e instanceof ErrorHelpi && e.estado === 409,
  );
  await assert.rejects(
    servicio.suspenderUsuarioAdmin(admin, 'usuario_1', { dias: 0 }),
    (e) => e instanceof ErrorHelpi && e.estado === 400,
  );
  await assert.rejects(
    servicio.suspenderUsuarioAdmin(admin, 'no_existe', {}),
    (e) => e instanceof ErrorHelpi && e.estado === 404,
  );

  await servicio.suspenderUsuarioAdmin(admin, 'usuario_1', {});
  const suspendido = await almacen.get('usuarios/usuario_1');
  assert.equal(suspendido.suspendidoHasta, null);
  assert.equal(estaSuspendido(suspendido, new Date('2030-01-01')), true);

  await servicio.reactivarUsuarioAdmin(admin, 'usuario_1');
  const reactivado = await almacen.get('usuarios/usuario_1');
  assert.equal(reactivado.suspendido, false);
  assert.equal(estaSuspendido(reactivado), false);
});

test('Admin: eliminar solicitud la borra con sus calificaciones y avisos', async () => {
  const { almacen, servicio, admin } = escenarioAdmin();

  almacen.datos.set('solicitudes/sol_1', {
    id: 'sol_1',
    titulo: 'Arreglar puerta',
    estado: 'Completada',
    solicitanteUid: 'usuario_1',
    prestadorUid: 'prestador_1',
  });
  almacen.datos.set('calificaciones/sol_1_usuario_1', {
    id: 'sol_1_usuario_1',
    solicitudId: 'sol_1',
    autorUid: 'usuario_1',
    destinoUid: 'prestador_1',
    estrellas: 5,
  });
  almacen.datos.set('notificaciones/notif_sol_1_a', {
    id: 'notif_sol_1_a',
    uid: 'usuario_1',
    solicitudId: 'sol_1',
  });
  almacen.datos.set('notificaciones/otra', {
    id: 'otra',
    uid: 'usuario_1',
    solicitudId: 'sol_2',
  });
  almacen.datos.set('idempotencia_solicitudes/usuario_1_crear_x', {
    uid: 'usuario_1',
    solicitudId: 'sol_1',
  });

  await servicio.eliminarSolicitudAdmin(admin, 'sol_1', {
    motivo: 'Contenido falso',
  });

  assert.equal(await almacen.get('solicitudes/sol_1'), null);
  assert.equal(await almacen.get('calificaciones/sol_1_usuario_1'), null);
  assert.equal(await almacen.get('notificaciones/notif_sol_1_a'), null);
  assert.equal(
    await almacen.get('idempotencia_solicitudes/usuario_1_crear_x'),
    null,
  );
  assert.ok(await almacen.get('notificaciones/otra'));

  // El promedio del prestador se recalcula sin esa calificación (9-5)/1.
  const prestador = await almacen.get('usuarios/prestador_1');
  assert.equal(prestador.totalCalificaciones, 1);
  assert.equal(prestador.sumaCalificaciones, 4);
  assert.equal(prestador.promedio, 4);

  // Ambos participantes reciben un aviso sin solicitud vinculada.
  const avisos = documentosDe(almacen, 'notificaciones').filter(
    (n) => n.tipo === 'aviso_admin',
  );
  assert.deepEqual(avisos.map((a) => a.uid).sort(), [
    'prestador_1',
    'usuario_1',
  ]);
  assert.ok(avisos.every((a) => a.solicitudId === null));
  assert.match(avisos[0].mensaje, /Contenido falso/);

  const historial = documentosDe(almacen, 'acciones_admin');
  assert.equal(historial[0].accion, 'solicitud_eliminada');

  await assert.rejects(
    servicio.eliminarSolicitudAdmin(admin, 'sol_1'),
    (e) => e instanceof ErrorHelpi && e.estado === 404,
  );
});

test('Admin: no elimina solicitudes con pago pendiente', async () => {
  const { almacen, servicio, admin } = escenarioAdmin();

  almacen.datos.set('solicitudes/sol_pago', {
    id: 'sol_pago',
    estado: 'En Proceso',
    pagoId: 'pago_1',
  });

  await assert.rejects(
    servicio.eliminarSolicitudAdmin(admin, 'sol_pago'),
    (e) => e instanceof ErrorHelpi && e.estado === 409,
  );
  assert.ok(await almacen.get('solicitudes/sol_pago'));
});

test('Admin: atender reporte descuenta reportes activos una sola vez', async () => {
  const { almacen, servicio, admin } = escenarioAdmin();

  almacen.datos.set('reportes/usuario_1_prestador_1', {
    autorUid: 'usuario_1',
    destinoUid: 'prestador_1',
    motivo: 'No llegó',
    estado: 'abierto',
  });

  await assert.rejects(
    servicio.atenderReporteAdmin(admin, 'usuario_1_prestador_1', {
      estado: 'cerrado',
    }),
    (e) => e instanceof ErrorHelpi && e.estado === 400,
  );

  await servicio.atenderReporteAdmin(admin, 'usuario_1_prestador_1', {
    estado: 'resuelto',
    nota: 'Se habló con el prestador',
  });

  const reporte = await almacen.get('reportes/usuario_1_prestador_1');
  assert.equal(reporte.estado, 'resuelto');
  assert.equal(reporte.atendidoPor, admin.uid);
  assert.equal(
    (await almacen.get('usuarios/prestador_1')).reportesActivos,
    1,
  );

  await assert.rejects(
    servicio.atenderReporteAdmin(admin, 'usuario_1_prestador_1', {
      estado: 'descartado',
    }),
    (e) => e instanceof ErrorHelpi && e.estado === 409,
  );
});

test('Admin: enviar aviso crea una notificación para el usuario', async () => {
  const { almacen, servicio, admin } = escenarioAdmin();

  await assert.rejects(
    servicio.enviarAvisoAdmin(admin, 'usuario_1', { mensaje: 'Hey' }),
    (e) => e instanceof ErrorHelpi && e.estado === 400,
  );

  await servicio.enviarAvisoAdmin(admin, 'usuario_1', {
    mensaje: 'Recuerda respetar las normas de la comunidad.',
  });

  const avisos = documentosDe(almacen, 'notificaciones');
  assert.equal(avisos.length, 1);
  assert.equal(avisos[0].uid, 'usuario_1');
  assert.equal(avisos[0].tipo, 'aviso_admin');
  assert.equal(avisos[0].leida, false);
});

test('Una suspensión temporal vencida ya no bloquea al usuario', async () => {
  const { almacen, servicio } = escenarioAdmin();
  const vencido = {
    suspendido: true,
    suspendidoHasta: '2026-11-17T00:00:00.000Z',
  };

  assert.equal(estaSuspendido(vencido, new Date('2026-11-18')), false);
  assert.equal(estaSuspendido({ suspendido: true }), true);
  assert.equal(estaSuspendido({ suspendido: false }), false);
  assert.equal(estaSuspendido(null), false);

  almacen.datos.set('usuarios/usuario_1', {
    ...(await almacen.get('usuarios/usuario_1')),
    ...vencido,
  });
  assert.equal(await servicio.levantarSuspensionVencida('usuario_1'), true);
});


test('Admin: alerta con título y lista de alertas pendientes del usuario', async () => {
  const { almacen, servicio, admin } = escenarioAdmin();

  await servicio.enviarAvisoAdmin(admin, 'usuario_1', {
    titulo: 'Lenguaje inapropiado',
    mensaje: 'Mantén un trato respetuoso con la comunidad.',
  });
  await servicio.enviarAvisoAdmin(admin, 'usuario_1', {
    mensaje: 'Completa tu perfil para recibir más solicitudes.',
  });
  // Notificación normal y alerta de otro usuario: no deben aparecer.
  almacen.datos.set('notificaciones/normal', {
    id: 'normal',
    uid: 'usuario_1',
    tipo: 'servicio_aceptado',
    leida: false,
  });
  await servicio.enviarAvisoAdmin(admin, 'prestador_1', {
    mensaje: 'Este aviso es para otra persona.',
  });

  const { datos } = await servicio.avisosAdminPendientes('usuario_1');
  assert.equal(datos.length, 2);
  assert.ok(datos.every((n) => n.tipo === 'aviso_admin' && n.uid === 'usuario_1'));
  assert.deepEqual(
    datos.map((n) => n.titulo).sort(),
    ['Aviso del equipo de Helpi', 'Lenguaje inapropiado'],
  );

  // Una vez leída, ya no vuelve a salir.
  const ruta = `notificaciones/${datos[0].id}`;
  almacen.datos.set(ruta, { ...(await almacen.get(ruta)), leida: true });
  const despues = await servicio.avisosAdminPendientes('usuario_1');
  assert.equal(despues.datos.length, 1);

  await assert.rejects(
    servicio.enviarAvisoAdmin(admin, 'usuario_1', {
      titulo: 'x',
      mensaje: 'Mensaje válido de prueba.',
    }),
    (e) => e instanceof ErrorHelpi && e.estado === 400,
  );
});


test('Campanita: cuenta solo las notificaciones sin leer del usuario', async () => {
  const { almacen, servicio } = escenarioAdmin();

  assert.deepEqual(await servicio.contarNotificacionesSinLeer('usuario_1'), {
    total: 0,
  });

  almacen.datos.set('notificaciones/a', { id: 'a', uid: 'usuario_1', leida: false });
  almacen.datos.set('notificaciones/b', { id: 'b', uid: 'usuario_1', leida: false });
  almacen.datos.set('notificaciones/c', { id: 'c', uid: 'usuario_1', leida: true });
  almacen.datos.set('notificaciones/d', { id: 'd', uid: 'prestador_1', leida: false });

  assert.deepEqual(await servicio.contarNotificacionesSinLeer('usuario_1'), {
    total: 2,
  });
});
