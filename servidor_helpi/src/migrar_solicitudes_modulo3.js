'use strict';

/**
 * Migración idempotente del Módulo 3 para solicitudes anteriores.
 * Completa los campos derivados `tituloNormalizado` y `ciudadNormalizada`
 * requeridos por la búsqueda por prefijo e índices de Firestore.
 *
 * Por defecto se ejecuta en MODO SIMULACIÓN (no escribe en Firestore).
 * Para aplicar los cambios:
 *   node src/migrar_solicitudes_modulo3.js --aplicar
 */

require('dotenv').config();

const {
  initializeApp,
  applicationDefault,
} = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { normalizarTextoBusqueda } = require('./dominio');

async function ejecutarMigracion() {
  const aplicar = process.argv.includes('--aplicar');

  initializeApp({
    credential: applicationDefault(),
    projectId: process.env.FIREBASE_PROJECT_ID || 'helpi-95e83',
  });

  const db = getFirestore();
  console.log(
    aplicar
      ? '[MODO APLICAR] Actualizando documentos pendientes en solicitudes...'
      : '[MODO SIMULACIÓN] Analizando documentos pendientes (usa --aplicar para guardar cambios)...',
  );

  let ultimoDoc = null;
  let revisados = 0;
  let pendientes = 0;
  let actualizados = 0;

  while (true) {
    let consulta = db
      .collection('solicitudes')
      .orderBy('__name__')
      .limit(200);

    if (ultimoDoc) {
      consulta = consulta.startAfter(ultimoDoc);
    }

    const pagina = await consulta.get();
    if (pagina.empty) break;

    const lote = db.batch();
    let cambiosEnLote = 0;

    for (const doc of pagina.docs) {
      revisados += 1;
      const datos = doc.data();
      const tituloNormalizado = normalizarTextoBusqueda(datos.titulo || '');
      const ciudadNormalizada = normalizarTextoBusqueda(datos.ciudad || '');

      const faltaTitulo = datos.tituloNormalizado !== tituloNormalizado;
      const faltaCiudad = datos.ciudadNormalizada !== ciudadNormalizada;

      if (faltaTitulo || faltaCiudad) {
        pendientes += 1;
        if (aplicar) {
          lote.update(doc.ref, {
            tituloNormalizado,
            ciudadNormalizada,
          });
          cambiosEnLote += 1;
        }
      }
    }

    if (aplicar && cambiosEnLote > 0) {
      await lote.commit();
      actualizados += cambiosEnLote;
    }

    ultimoDoc = pagina.docs.at(-1);
    if (pagina.size < 200) break;
  }

  console.log(
    JSON.stringify(
      {
        modo: aplicar ? 'aplicado' : 'simulacion',
        revisados,
        pendientes,
        actualizados,
      },
      null,
      2,
    ),
  );
}

if (require.main === module) {
  ejecutarMigracion().catch((error) => {
    console.error('Error en migración:', error.message);
    process.exitCode = 1;
  });
}

module.exports = { ejecutarMigracion };
