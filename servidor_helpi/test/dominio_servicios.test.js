'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { ServicioHelpi, ErrorHelpi } = require('../src/dominio');

class AlmacenEnMemoria {
  constructor() {
    this.datos = new Map();
  }

  async get(ruta) {
    const doc = this.datos.get(ruta);
    return doc ? JSON.parse(JSON.stringify(doc)) : null;
  }

  async set(ruta, valor) {
    this.datos.set(ruta, JSON.parse(JSON.stringify(valor)));
  }

  async list(coleccion, campo, valor) {
    const resultados = [];
    for (const [ruta, doc] of this.datos.entries()) {
      if (ruta.startsWith(`${coleccion}/`) && doc[campo] === valor) {
        resultados.push(JSON.parse(JSON.stringify(doc)));
      }
    }
    return { datos: resultados, siguienteCursor: null };
  }

  async atomic(operacion) {
    return operacion({
      get: (ruta) => this.get(ruta),
      set: (ruta, valor) => this.set(ruta, valor),
    });
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
    versionTerminos: 'v1.0',
    versionPrivacidad: 'v1.0',
    fechaAceptacion: fechaFija.toISOString(),
    documentoId: 'terminos_y_privacidad_helpi',
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
  const { almacen, servicio, uidSolicitante } = crearEscenarioBase();

  // 1. Consulta de términos vigentes
  const vigentes = servicio.terminosVigentes();
  assert.equal(vigentes.versionTerminos, 'v1.0');
  assert.equal(vigentes.versionPrivacidad, 'v1.0');
  assert.equal(vigentes.fechaVigencia, '2026-11-11');

  // 2. Usuario sin términos aceptados no puede crear ni listar solicitudes protegidas
  const uidNuevo = 'usuario_sin_terminos';
  await almacen.set(`usuarios/${uidNuevo}`, {
    uid: uidNuevo,
    nombre: 'Usuario Sin Términos',
    rol: 'solicitante',
    perfilCompleto: true,
    suspendido: false,
    terminosAceptados: null,
  });

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

  // 3. Aceptar con versión incorrecta debe ser rechazado
  await assert.rejects(
    async () =>
      servicio.aceptarTerminos(uidNuevo, {
        versionTerminos: 'v0.9',
        versionPrivacidad: 'v1.0',
      }),
    (err) => err instanceof ErrorHelpi && err.estado === 400,
  );

  // 4. Aceptar con versiones vigentes registra en el usuario y en historial
  const resultado = await servicio.aceptarTerminos(uidNuevo, {
    versionTerminos: 'v1.0',
    versionPrivacidad: 'v1.0',
  });
  assert.equal(resultado.correcto, true);
  assert.equal(resultado.datos.versionTerminos, 'v1.0');
  assert.equal(resultado.datos.versionPrivacidad, 'v1.0');
  assert.ok(resultado.datos.fechaAceptacion);

  // Comprobar que se guardó en usuarios/${uidNuevo}
  const perfilActualizado = await almacen.get(`usuarios/${uidNuevo}`);
  assert.equal(perfilActualizado.terminosAceptados.versionTerminos, 'v1.0');
  assert.equal(perfilActualizado.terminosAceptados.versionPrivacidad, 'v1.0');

  // Comprobar que se guardó en historial aceptaciones_terminos/${id}
  const registroHistorial = await almacen.get(
    `aceptaciones_terminos/${resultado.datos.id}`,
  );
  assert.ok(registroHistorial);
  assert.equal(registroHistorial.uid, uidNuevo);
  assert.equal(registroHistorial.versionTerminos, 'v1.0');

  // 5. Ahora sí puede realizar la operación protegida
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

