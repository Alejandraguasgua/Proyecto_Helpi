'use strict';

class AlmacenFirestore {
  constructor(baseDeDatos, campoIdentificador) {
    this.db = baseDeDatos;
    this.campoId = campoIdentificador;
  }

  async get(ruta) {
    const documento = await this.db.doc(ruta).get();

    return documento.exists ? documento.data() : null;
  }

  async set(ruta, datos) {
    await this.db.doc(ruta).set(datos);
  }

  async list(coleccion, campo, valor, cursor) {
    let consulta = this.db
      .collection(coleccion)
      .where(campo, '==', valor)
      .orderBy(this.campoId())
      .limit(50);

    if (cursor) {
      consulta = consulta.startAfter(cursor);
    }

    const pagina = await consulta.get();

    return {
      datos: pagina.docs.map((documento) => ({
        ...documento.data(),
        id: documento.id,
      })),
      siguienteCursor:
        pagina.size === 50
          ? pagina.docs.at(-1).id
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

          return documento.exists ? documento.data() : null;
        },

        set: (ruta, datos) => {
          transaccion.set(this.db.doc(ruta), datos);
        },
      });
    });
  }
}

module.exports = { AlmacenFirestore };