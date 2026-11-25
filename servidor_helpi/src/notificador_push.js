'use strict';

const { getMessaging } = require('firebase-admin/messaging');

const TOKENS_MUERTOS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

async function enviarPush(db, notificacion) {
  const dispositivos = await db
    .collection('dispositivos')
    .where('uid', '==', notificacion.uid)
    .get();

  const docs = dispositivos.docs.filter((d) => d.data().token);
  if (docs.length === 0) return;

  const respuesta = await getMessaging().sendEachForMulticast({
    tokens: docs.map((d) => d.data().token),
    notification: { title: notificacion.titulo, body: notificacion.mensaje },
    data: {
      tipo: String(notificacion.tipo ?? ''),
      solicitudId: String(notificacion.solicitudId ?? ''),
      notificacionId: String(notificacion.id ?? ''),
    },
    android: { priority: 'high' },
  });

  // Borra los tokens que ya no sirven.
  await Promise.all(
    respuesta.responses.map((r, i) =>
      !r.success && TOKENS_MUERTOS.has(r.error?.code)
        ? docs[i].ref.delete()
        : null,
    ),
  );
}

/** Envía un push por cada notificación nueva que aparezca en Firestore. */
function iniciarEnvioPush(db) {
  let primeraCarga = true;

  return db.collection('notificaciones').onSnapshot(
    (instantanea) => {
      // La primera carga trae las notificaciones antiguas: se ignoran.
      if (primeraCarga) {
        primeraCarga = false;
        return;
      }
      for (const cambio of instantanea.docChanges()) {
        if (cambio.type !== 'added') continue;
        const n = { ...cambio.doc.data(), id: cambio.doc.id };
        if (n.leida === true || !n.uid) continue;
        enviarPush(db, n).catch((e) =>
          console.error('No se pudo enviar el push:', e.message),
        );
      }
    },
    (error) =>
      console.error('Escucha de notificaciones detenida:', error.message),
  );
}

/** Recordatorio: finalización pendiente de confirmar por más de 24 h. */
function iniciarRecordatorios(db) {
  const HORA = 60 * 60 * 1000;

  async function recordatorioFinalizacion() {
    const limite = new Date(Date.now() - 24 * HORA).toISOString();
    const pendientes = await db
      .collection('solicitudes')
      .where('estado', '==', 'En Proceso')
      .where('finalizacionSolicitada', '==', true)
      .get();

    for (const doc of pendientes.docs) {
      const s = doc.data();
      if (!s.solicitanteUid || String(s.actualizada ?? '') > limite) continue;

      const id = `notif_${doc.id}_recordatorio_finalizacion_${s.solicitanteUid}`;
      try {
        // create() falla si ya existe, así no se repite el recordatorio.
        await db.collection('notificaciones').doc(id).create({
          id,
          uid: s.solicitanteUid,
          destinatarioUid: s.solicitanteUid,
          solicitudId: doc.id,
          servicioTitulo: s.titulo ?? '',
          tipo: 'recordatorio_finalizacion',
          titulo: 'Confirma la finalización',
          mensaje: `Tienes pendiente confirmar "${s.titulo ?? 'el servicio'}".`,
          leida: false,
          fechaLectura: null,
          creada: new Date().toISOString(),
        });
      } catch (e) {
        if (e.code !== 6) console.error('Recordatorio falló:', e.message);
      }
    }
  }

  setInterval(
    () => recordatorioFinalizacion().catch((e) => console.error(e.message)),
    HORA,
  );
}

module.exports = { iniciarEnvioPush, iniciarRecordatorios };
