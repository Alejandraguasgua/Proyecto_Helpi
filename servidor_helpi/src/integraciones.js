'use strict';

const {
  createHash,
  randomUUID,
} = require('node:crypto');

const {
  exigir,
  ErrorHelpi,
  coordenadas,
  texto,
} = require('./dominio');

function variable(nombre) {
  const valor = process.env[nombre];

  if (!valor || valor.startsWith('COMPLETAR')) {
    throw new ErrorHelpi(
      503,
      `Completa ${nombre} en el archivo .env del servidor.`,
    );
  }

  return valor;
}

async function consultar(url, opciones = {}) {
  const respuesta = await fetch(url, {
    ...opciones,
    signal: AbortSignal.timeout(15000),
  });

  const datos = await respuesta.json();

  if (!respuesta.ok) {
    throw new ErrorHelpi(
      502,
      'El proveedor externo rechazó la operación. Revisa su configuración.',
    );
  }

  return datos;
}

function firmaCloudinary(parametros, secreto) {
  const cadena = Object.keys(parametros)
    .sort()
    .map((clave) => `${clave}=${parametros[clave]}`)
    .join('&');

  return createHash('sha1')
    .update(cadena + secreto)
    .digest('hex');
}

async function subirFoto(uid, datos = {}) {
  const nube = variable('CLOUDINARY_CLOUD_NAME');
  const clave = variable('CLOUDINARY_API_KEY');
  const secreto = variable('CLOUDINARY_API_SECRET');

  exigir(
    typeof datos.base64 === 'string' &&
      datos.base64.length <= 710000,
    'La foto debe tener como máximo 512 KB.',
  );

  exigir(
    /^[A-Za-z0-9+/]*={0,2}$/.test(datos.base64),
    'El contenido de la imagen no es válido.',
  );

  const bytes = Buffer.from(
    datos.base64,
    'base64',
  );

  exigir(
    bytes.length > 0 &&
      bytes.length <= 512 * 1024,
    'La foto está vacía o supera los 512 KB.',
  );

  const esPng = bytes.subarray(0, 8).equals(
    Buffer.from([
      137, 80, 78, 71,
      13, 10, 26, 10,
    ]),
  );

  const esJpg =
    bytes[0] === 255 &&
    bytes[1] === 216 &&
    bytes[2] === 255;

  exigir(
    esPng || esJpg,
    'Selecciona una imagen JPG o PNG.',
  );

  const parametros = {
    public_id: `helpi/perfiles/${uid}/${randomUUID()}`,
    timestamp: Math.floor(Date.now() / 1000),
  };

  const formulario = new FormData();

  formulario.set(
    'file',
    new Blob(
      [bytes],
      {
        type: esPng
          ? 'image/png'
          : 'image/jpeg',
      },
    ),
    esPng
      ? 'perfil.png'
      : 'perfil.jpg',
  );

  for (const [nombre, valor] of Object.entries(parametros)) {
    formulario.set(
      nombre,
      String(valor),
    );
  }

  formulario.set(
    'api_key',
    clave,
  );

  formulario.set(
    'signature',
    firmaCloudinary(parametros, secreto),
  );

  const resultado = await consultar(
    `https://api.cloudinary.com/v1_1/${encodeURIComponent(nube)}/image/upload`,
    {
      method: 'POST',
      body: formulario,
    },
  );

  return {
    fotoUrl: resultado.secure_url,
    fotoPublicId: resultado.public_id,
  };
}

async function eliminarFoto(publicId) {
  if (!publicId) {
    return;
  }

  const parametros = {
    public_id: publicId,
    timestamp: Math.floor(Date.now() / 1000),
    invalidate: true,
  };

  const formulario = new URLSearchParams({
    ...parametros,
    api_key: variable('CLOUDINARY_API_KEY'),

    signature: firmaCloudinary(
      parametros,
      variable('CLOUDINARY_API_SECRET'),
    ),
  });

  await consultar(
    `https://api.cloudinary.com/v1_1/${encodeURIComponent(variable('CLOUDINARY_CLOUD_NAME'))}/image/destroy`,
    {
      method: 'POST',
      body: formulario,
    },
  );
}

async function autocompletar(busqueda) {
  return consultar(
    'https://places.googleapis.com/v1/places:autocomplete',
    {
      method: 'POST',

      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': variable(
          'GOOGLE_MAPS_SERVER_KEY',
        ),
      },

      body: JSON.stringify({
        input: texto(
          busqueda,
          'Búsqueda',
          3,
          150,
        ),
        includedRegionCodes: ['ec'],
        languageCode: 'es',
      }),
    },
  );
}

async function detalleLugar(identificador) {
  const lugar = texto(
    identificador,
    'Lugar',
    1,
    250,
  );

  return consultar(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(lugar)}`,
    {
      headers: {
        'X-Goog-Api-Key': variable(
          'GOOGLE_MAPS_SERVER_KEY',
        ),

        'X-Goog-FieldMask':
          'location,formattedAddress,displayName',
      },
    },
  );
}

async function ruta(datos = {}) {
  const origen = coordenadas(datos.origen);
  const destino = coordenadas(datos.destino);

  const punto = (ubicacion) => ({
    location: {
      latLng: {
        latitude: ubicacion.latitud,
        longitude: ubicacion.longitud,
      },
    },
  });

  const resultado = await consultar(
    'https://routes.googleapis.com/directions/v2:computeRoutes',
    {
      method: 'POST',

      headers: {
        'Content-Type': 'application/json',

        'X-Goog-Api-Key': variable(
          'GOOGLE_MAPS_SERVER_KEY',
        ),

        'X-Goog-FieldMask':
          'routes.distanceMeters,routes.duration',
      },

      body: JSON.stringify({
        origin: punto(origen),
        destination: punto(destino),
        travelMode: 'DRIVE',
        languageCode: 'es',
      }),
    },
  );

  exigir(
    resultado.routes?.length,
    'No se encontró una ruta disponible.',
    404,
  );

  return {
    ...resultado.routes[0],

    urlGoogleMaps:
      'https://www.google.com/maps/dir/?api=1' +
      `&destination=${destino.latitud},${destino.longitud}`,
  };
}

module.exports = {
  subirFoto,
  eliminarFoto,
  autocompletar,
  detalleLugar,
  ruta,
  variable,
  firmaCloudinary,
};