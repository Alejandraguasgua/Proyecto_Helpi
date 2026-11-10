String normalizarBusqueda(String valor) {
  var texto = valor.trim().toLowerCase();

  const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};

  acentos.forEach((original, reemplazo) {
    texto = texto.replaceAll(original, reemplazo);
  });

  return texto;
}

class SolicitudDemostracion {
  const SolicitudDemostracion(
    this.titulo,
    this.categoria,
    this.descripcion,
    this.ciudad,
    this.sector,
    this.distancia,
    this.centavos,
  );

  final String titulo;
  final String categoria;
  final String descripcion;
  final String ciudad;
  final String sector;
  final double distancia;
  final int centavos;

  String get monto {
    final valor = (centavos / 100).toStringAsFixed(2).replaceAll('.', ',');
    return '\$$valor';
  }
}

const solicitudesDemostracion = [
  SolicitudDemostracion(
    'Configurar una laptop',
    'Soporte técnico',
    'Instalar herramientas de estudio y configurar una computadora.',
    'Riobamba',
    'Sector ESPOCH',
    1.2,
    1500,
  ),
  SolicitudDemostracion(
    'Pasear a una mascota',
    'Mascotas',
    'Pasear a una perrita durante una hora.',
    'Riobamba',
    'Centro',
    2,
    800,
  ),
  SolicitudDemostracion(
    'Repaso de cálculo',
    'Tutorías',
    'Repasar derivadas y ejercicios para un examen.',
    'Riobamba',
    'Sector universitario',
    4.3,
    1200,
  ),
  SolicitudDemostracion(
    'Ayuda con una impresora',
    'Soporte técnico',
    'Configurar la conexión de una impresora.',
    'Quito',
    'La Carolina',
    1.8,
    1800,
  ),
  SolicitudDemostracion(
    'Armar un escritorio',
    'Hogar',
    'Ayudar a armar un escritorio pequeño.',
    'Quito',
    'Centro',
    3.5,
    2000,
  ),
  SolicitudDemostracion(
    'Repasar inglés',
    'Tutorías',
    'Practicar ejercicios básicos de inglés.',
    'Cuenca',
    'Centro',
    1.5,
    1000,
  ),
  SolicitudDemostracion(
    'Mover unas cajas',
    'Mudanzas',
    'Ayudar a transportar cajas pequeñas.',
    'Cuenca',
    'El Vergel',
    4,
    1600,
  ),
];

List<SolicitudDemostracion> filtrarSolicitudes({
  required String ciudad,
  String sector = '',
  String categoria = 'Todas',
  String busqueda = '',
  int radio = 5,
}) {
  final texto = normalizarBusqueda(busqueda);
  final zona = normalizarBusqueda(sector);

  return solicitudesDemostracion.where((solicitud) {
    final coincideCiudad =
        normalizarBusqueda(solicitud.ciudad) == normalizarBusqueda(ciudad);

    final coincideSector =
        zona.isEmpty || normalizarBusqueda(solicitud.sector).contains(zona);

    final coincideCategoria =
        categoria == 'Todas' || solicitud.categoria == categoria;

    final coincideDistancia = solicitud.distancia <= radio;

    final contenido = normalizarBusqueda(
      '${solicitud.titulo} ${solicitud.descripcion} '
      '${solicitud.categoria} ${solicitud.sector}',
    );

    return coincideCiudad &&
        coincideSector &&
        coincideCategoria &&
        coincideDistancia &&
        contenido.contains(texto);
  }).toList();
}
