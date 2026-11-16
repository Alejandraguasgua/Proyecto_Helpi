'use strict';

function normalizarTexto(valor) {
  return String(valor || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizarValorFirestore(valor) {
  if (valor == null) return valor;

  if (typeof valor.toDate === 'function') {
    return valor.toDate().toISOString();
  }

  if (Array.isArray(valor)) {
    return valor.map(normalizarValorFirestore);
  }

  if (typeof valor === 'object') {
    const salida = {};
    for (const [clave, elemento] of Object.entries(valor)) {
      salida[clave] = normalizarValorFirestore(elemento);
    }
    return salida;
  }

  return valor;
}

class AlmacenFirestore {
  constructor(baseDeDatos, campoIdentificador) {
    this.db = baseDeDatos;
    this.campoId = campoIdentificador;
  }

  async get(ruta) {
    const documento = await this.db.doc(ruta).get();

    return documento.exists
      ? normalizarValorFirestore(documento.data())
      : null;
  }

  async set(ruta, datos) {
    await this.db.doc(ruta).set(datos);
  }

  async delete(ruta) {
    await this.db.doc(ruta).delete();
  }

  async list(coleccion, campo, valor, cursor) {
    if (!cursor) {
      const pagina = await this.db
        .collection(coleccion)
        .where(campo, '==', valor)
        .limit(100)
        .get();

      const datos = pagina.docs
        .map((documento) => ({
          ...normalizarValorFirestore(documento.data()),
          id: documento.id,
        }))
        .sort((a, b) =>
          String(a.id || '').localeCompare(String(b.id || '')),
        );

      const recorte = datos.slice(0, 50);

      return {
        datos: recorte,
        siguienteCursor:
          datos.length > 50 && recorte.length === 50
            ? recorte.at(-1).id
            : null,
      };
    }

    try {
      const consulta = this.db
        .collection(coleccion)
        .where(campo, '==', valor)
        .orderBy(this.campoId())
        .startAfter(cursor)
        .limit(50);

      const pagina = await consulta.get();

      return {
        datos: pagina.docs.map((documento) => ({
          ...normalizarValorFirestore(documento.data()),
          id: documento.id,
        })),
        siguienteCursor:
          pagina.size === 50 ? pagina.docs.at(-1).id : null,
      };
    } catch (error) {
      const instantanea = await this.db
        .collection(coleccion)
        .where(campo, '==', valor)
        .get();

      const ordenados = instantanea.docs
        .map((documento) => ({
          ...normalizarValorFirestore(documento.data()),
          id: documento.id,
        }))
        .sort((a, b) =>
          String(a.id || '').localeCompare(String(b.id || '')),
        )
        .filter((item) => String(item.id || '') > String(cursor));

      const datos = ordenados.slice(0, 50);

      return {
        datos,
        siguienteCursor:
          ordenados.length > 50 && datos.length === 50
            ? datos.at(-1).id
            : null,
      };
    }
  }

  async listNotificaciones(uid, cursor, limite = 20) {
    const instantanea = await this.db
      .collection('notificaciones')
      .where('uid', '==', uid)
      .get();

    const delUsuario = instantanea.docs.map((documento) => ({
      ...normalizarValorFirestore(documento.data()),
      id: documento.id,
    }));

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
          String(item.creada || '') < cursorFecha ||
          (String(item.creada || '') === cursorFecha &&
            String(item.id || '') < cursorId),
      );
    }

    const datos = filtrados.slice(0, limite);
    const ultimo = datos.at(-1);

    return {
      datos,
      siguienteCursor:
        filtrados.length > limite &&
        datos.length === limite &&
        ultimo
          ? `${ultimo.creada}|${ultimo.id}`
          : null,
    };
  }

  async listCalificaciones(destinoUid, cursor, limite = 10) {
    const instantanea = await this.db
      .collection('calificaciones')
      .where('destinoUid', '==', destinoUid)
      .get();

    const delPrestador = instantanea.docs.map((documento) => ({
      ...normalizarValorFirestore(documento.data()),
      id: documento.id,
    }));

    delPrestador.sort((a, b) => {
      const cmpFecha = String(b.creada || '').localeCompare(
        String(a.creada || ''),
      );
      if (cmpFecha !== 0) return cmpFecha;
      return String(b.id || '').localeCompare(String(a.id || ''));
    });

    let filtrados = delPrestador;
    if (cursor) {
      const [cursorFecha, cursorId] = String(cursor).split('|');
      filtrados = delPrestador.filter(
        (item) =>
          String(item.creada || '') < cursorFecha ||
          (String(item.creada || '') === cursorFecha &&
            String(item.id || '') < cursorId),
      );
    }

    const datos = filtrados.slice(0, limite);
    const ultimo = datos.at(-1);

    return {
      datos,
      siguienteCursor:
        filtrados.length > limite &&
        datos.length === limite &&
        ultimo
          ? `${ultimo.creada || ''}|${ultimo.id}`
          : null,
    };
  }

  async listSolicitudes({
    campoPropietario,
    uid,
    estado,
    categoria,
    ciudadNormalizada,
    prefijoTitulo,
    orden = 'recientes',
    cursorOrden,
    cursorId,
    limite = 20,
  }) {
    const instantanea = await this.db
      .collection('solicitudes')
      .where(campoPropietario, '==', uid)
      .get();

    const delUsuario = instantanea.docs.map((doc) => ({
      ...normalizarValorFirestore(doc.data()),
      id: doc.id,
    }));

    const coincidencias = delUsuario.filter((solicitud) => {
      if (estado && solicitud.estado !== estado) {
        return false;
      }

      if (categoria && solicitud.categoria !== categoria) {
        return false;
      }

      if (
        ciudadNormalizada &&
        normalizarTexto(
          solicitud.ciudadNormalizada || solicitud.ciudad,
        ) !== ciudadNormalizada
      ) {
        return false;
      }

      if (
        prefijoTitulo &&
        !normalizarTexto(
          solicitud.tituloNormalizado || solicitud.titulo,
        ).startsWith(prefijoTitulo)
      ) {
        return false;
      }

      return true;
    });

    const campoOrden =
      orden === 'fecha_servicio' ? 'fechaServicio' : 'creada';

    coincidencias.sort((a, b) => {
      if (orden === 'fecha_servicio') {
        const cmp = String(a.fechaServicio || '').localeCompare(
          String(b.fechaServicio || ''),
        );
        if (cmp !== 0) return cmp;
        return String(a.id || '').localeCompare(String(b.id || ''));
      }

      const cmp = String(b.creada || '').localeCompare(
        String(a.creada || ''),
      );
      if (cmp !== 0) return cmp;
      return String(b.id || '').localeCompare(String(a.id || ''));
    });

    const filtradosCursor =
      cursorOrden && cursorId
        ? coincidencias.filter((item) => {
            const valorOrden = String(item[campoOrden] || '');
            const valorId = String(item.id || '');

            if (orden === 'fecha_servicio') {
              return (
                valorOrden > cursorOrden ||
                (valorOrden === cursorOrden && valorId > cursorId)
              );
            }

            return (
              valorOrden < cursorOrden ||
              (valorOrden === cursorOrden && valorId < cursorId)
            );
          })
        : coincidencias;

    const datos = filtradosCursor.slice(0, limite);
    const ultimo = datos.at(-1);

    return {
      datos,
      siguienteCursor:
        filtradosCursor.length > limite &&
        datos.length === limite &&
        ultimo
          ? `${ultimo[campoOrden]}|${ultimo.id}`
          : null,
    };
  }

  atomic(operacion) {
    return this.db.runTransaction((transaccion) => {
      return operacion({
        get: async (ruta) => {
          const documento = await transaccion.get(
            this.db.doc(ruta),
          );

          return documento.exists
            ? normalizarValorFirestore(documento.data())
            : null;
        },

        set: (ruta, datos) => {
          transaccion.set(this.db.doc(ruta), datos);
        },

        delete: (ruta) => {
          if (typeof transaccion.delete === 'function') {
            transaccion.delete(this.db.doc(ruta));
          }
        },
      });
    });
  }
}

module.exports = {
  AlmacenFirestore,
  normalizarValorFirestore,
};