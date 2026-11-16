'use strict';

// Uso (dentro de servidor_helpi):
//   node scripts/crear_admin.js correo@gmail.com
//   node scripts/crear_admin.js correo@gmail.com --quitar
//
// Usa las mismas credenciales que el servidor (applicationDefault).
// La persona debe cerrar sesión y volver a entrar para ver el cambio.

require('dotenv').config();

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const correo = process.argv[2];
const quitar = process.argv.includes('--quitar');

if (!correo) {
  console.error('Indica el correo: node scripts/crear_admin.js correo@gmail.com');
  process.exit(1);
}

initializeApp({
  credential: applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID || 'helpi-95e83',
});

(async () => {
  const auth = getAuth();
  const usuario = await auth.getUserByEmail(correo);
  const claims = { ...(usuario.customClaims || {}) };

  if (quitar) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }

  await auth.setCustomUserClaims(usuario.uid, claims);
  await auth.revokeRefreshTokens(usuario.uid);

  console.log(
    quitar
      ? `Se quitó el rol de administrador a ${correo}.`
      : `${correo} ahora es administrador (uid ${usuario.uid}).`,
  );
})().catch((error) => {
  console.error('No se pudo completar:', error.message);
  process.exit(1);
});
