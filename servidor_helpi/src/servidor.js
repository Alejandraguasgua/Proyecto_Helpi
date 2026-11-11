'use strict';

require('dotenv').config();

const {
  initializeApp,
  applicationDefault,
} = require('firebase-admin/app');

const { getAuth } = require('firebase-admin/auth');

const {
  getFirestore,
  FieldPath,
} = require('firebase-admin/firestore');

const { AlmacenFirestore } = require('./almacen_firestore');
const { crearAplicacion } = require('./aplicacion');

initializeApp({
  credential: applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID || 'helpi-95e83',
});

const baseDeDatos = getFirestore();

const aplicacion = crearAplicacion({
  db: baseDeDatos,
  auth: getAuth(),
  almacen: new AlmacenFirestore(
    baseDeDatos,
    FieldPath.documentId,
  ),
});

const puerto = Number(process.env.PORT || 3000);
const host = process.env.HOST || '127.0.0.1';

const servidor = aplicacion.listen(puerto, host, () => {
  console.log(`Servidor Helpi disponible en http://${host}:${puerto}`);
});

servidor.on('error', (error) => {
  console.error('No se pudo iniciar el servidor:', error.message);
  process.exitCode = 1;
});