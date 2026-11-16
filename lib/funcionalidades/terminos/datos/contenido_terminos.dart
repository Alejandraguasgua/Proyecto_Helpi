class SeccionLegal {
  const SeccionLegal({
    required this.numero,
    required this.titulo,
    required this.contenido,
    this.puntos,
    this.datosPendientes,
  });

  final String numero;
  final String titulo;
  final String contenido;
  final List<String>? puntos;
  final List<String>? datosPendientes;
}

const String documentoTerminosId = 'terminos_condiciones_helpi';
const String documentoPrivacidadId = 'aviso_privacidad_helpi';
const String versionTerminosVigente = 'v1.0';
const String versionPrivacidadVigente = 'v1.0';
const String fechaVigenciaDocumentos = '11 de noviembre de 2026';

const String notaBorradorLegal =
    'Borrador preliminar preparado para HELPI. '
    'Pendiente de revisión y validación legal para la República del Ecuador.';

const List<String> datosPendientesDefinicion = [
  'Razón social o denominación legal del operador de HELPI en Ecuador.',
  'Número de Registro Único de Contribuyentes (RUC) ante el SRI.',
  'Domicilio legal, ciudad sede y dirección física para notificaciones en Ecuador.',
  'Correo electrónico oficial y canal directo de soporte y atención al usuario.',
  'Designación y contacto del Delegado de Protección de Datos (LOPDP Ecuador).',
  'Edad mínima definitiva (referencia legal supletoria: 18 años, Código Civil de Ecuador).',
  'Catálogo oficial de actividades restringidas o que requieran título/licencia técnica habilitante.',
  'Plazos específicos de retención documental para auditoría y regulaciones tributarias.',
  'Procedimiento operativo y canal exclusivo para el ejercicio de derechos LOPDP.',
];

const List<SeccionLegal> seccionesTerminos = [
  SeccionLegal(
    numero: '1',
    titulo: 'Objeto de HELPI y rol de los participantes',
    contenido:
        'HELPI es una plataforma tecnológica que facilita el contacto y la coordinación '
        'entre miembros de una comunidad local: personas que solicitan apoyo en tareas '
        'puntuales ("solicitantes") y personas dispuestas a prestar su tiempo y habilidades '
        '("prestadores"). HELPI actúa exclusivamente como intermediario tecnológico.',
    puntos: [
      'HELPI no es empleador, contratista, mandatario ni agencia de colocación de personal.',
      'HELPI no forma parte del acuerdo particular celebrado directamente entre solicitante y prestador.',
      'Cada participante actúa por cuenta propia, con plena autonomía técnica y de voluntad.',
    ],
    datosPendientes: [
      '[POR DEFINIR: Razón social, RUC y domicilio fiscal del operador en Ecuador]',
    ],
  ),
  SeccionLegal(
    numero: '2',
    titulo: 'Requisitos de uso y cuidado de la cuenta',
    contenido:
        'El acceso a HELPI requiere una cuenta vinculada a Google Authentication. '
        'La cuenta es estrictamente personal e intransferible. El usuario es responsable '
        'de la veracidad de los datos registrados y del resguardo de su dispositivo.',
    puntos: [
      'Edad mínima de uso: debes contar con capacidad legal para obligarte (18 años o más según la normativa ecuatoriana aplicable).',
      'Debes proporcionar información verídica y mantener actualizados tu nombre, número de teléfono (+593), ciudad y sector.',
      'No se permite suplantar la identidad de terceros ni crear cuentas falsas o múltiples para fines engañosos.',
    ],
    datosPendientes: [
      '[POR DEFINIR: Procedimiento ante cuentas de personas menores o emancipadas]',
    ],
  ),
  SeccionLegal(
    numero: '3',
    titulo: 'Alcance real de la autenticación con Google',
    contenido:
        'La autenticación a través de Google Sign-In comprueba únicamente el acceso y '
        'control del usuario sobre su correo electrónico de Google. No constituye una '
        'verificación oficial ni aval estatal.',
    puntos: [
      'No acredita identidad legal ni sustituye el documento de identidad emitido por el Registro Civil del Ecuador.',
      'No valida idoneidad técnica, titulación profesional, experiencia práctica ni antecedentes penales o policiales.',
      'Cada participante debe ejercer diligencia debida antes de concertar o recibir un servicio.',
    ],
  ),
  SeccionLegal(
    numero: '4',
    titulo:
        'Acuerdos entre participantes: alcance, precio, horario y materiales',
    contenido:
        'El solicitante y el prestador son los únicos responsables de definir y acordar '
        'las condiciones específicas antes y durante la ejecución del servicio.',
    puntos: [
      'Alcance de la labor: detalle claro de lo que se va a realizar.',
      'Monto acordado: valor en dólares de los Estados Unidos (USD) ofrecido por la tarea completa.',
      'Fecha y horario: puntualidad y disponibilidad convenida entre ambas partes.',
      'Herramientas y materiales: especificar con antelación quién suministra los insumos y repuestos.',
    ],
  ),
  SeccionLegal(
    numero: '5',
    titulo: 'Seguridad personal, encuentros e ingreso a domicilios',
    contenido:
        'La seguridad es prioritaria para la comunidad. Todo servicio presencial implica '
        'precauciones de sentido común que cada participante debe observar.',
    puntos: [
      'Coordina los detalles en la plataforma y verifica los datos de tu contraparte antes de concertar el encuentro.',
      'Si el servicio involucra el ingreso a un domicilio o recinto privado, procura estar acompañado y resguardar bienes de valor.',
      'Tienes pleno derecho de abstenerte de iniciar o suspender un servicio si percibes situaciones de riesgo o desconfianza.',
    ],
  ),
  SeccionLegal(
    numero: '6',
    titulo: 'Actividades estrictamente prohibidas',
    contenido:
        'Para mantener una comunidad confiable, queda prohibido cualquier uso abusivo o '
        'contrario a la moral, el orden público y la legislación ecuatoriana.',
    puntos: [
      'Fraude, engaño, cobros indebidos o simulación de servicios.',
      'Acoso, discriminación por cualquier motivo, violencia verbal o física, intimidación o amenazas.',
      'Actos penados por el Código Orgánico Integral Penal (COIP) de la República del Ecuador.',
      'Difusión o publicación de datos personales de terceros (teléfonos, domicilios) sin consentimiento expreso.',
    ],
  ),
  SeccionLegal(
    numero: '7',
    titulo: 'Servicios de alto riesgo o que requieren habilitación profesional',
    contenido:
        'Determinadas tareas conllevan riesgos graves para la integridad física o patrimonial '
        '(por ejemplo: instalaciones eléctricas complejas, redes de gas, trabajos en altura '
        'crítica, medicina, enfermería, asesoría legal o contable reservada por ley).',
    puntos: [
      'HELPI no valida certificaciones profesionales ni peritajes técnicos.',
      'Los prestadores no deben ofrecer servicios que por ley requieran licencias o registros que no posean.',
      'El catálogo de categorías permitidas podrá ser restringido o condicionado por HELPI en cualquier momento.',
    ],
    datosPendientes: [
      '[POR DEFINIR: Lista taxativa de categorías prohibidas y requisitos técnicos exigidos]',
    ],
  ),
  SeccionLegal(
    numero: '8',
    titulo: 'Publicaciones, fotografías y reseñas',
    contenido:
        'Al publicar solicitudes, fotografías o reseñas en HELPI, el usuario declara ser '
        'titular de los derechos sobre el contenido o contar con la debida autorización.',
    puntos: [
      'Licencia limitada: concedes a HELPI autorización gratuita para exhibir el contenido dentro de la plataforma con el único fin de prestar el servicio.',
      'Las reseñas deben ser veraces y fundadas únicamente en servicios efectivamente completados.',
      'HELPI se reserva el derecho de retirar contenidos o suspender cuentas que vulneren estas directrices.',
    ],
  ),
  SeccionLegal(
    numero: '9',
    titulo: 'Cancelaciones, desacuerdos y moderación',
    contenido:
        'El flujo de estados en HELPI es: Publicada → Aceptada → En Proceso → Completada. '
        'Cualquier participante puede cancelar antes de la finalización indicando un motivo verídico.',
    puntos: [
      'HELPI no actúa como órgano jurisdiccional ni tribunal arbitral entre particulares.',
      'Los desacuerdos deben comunicarse mediante los canales de reporte para revisión de moderación.',
      'En la fase actual no existen pagos procesados por la app, seguros contra daños ni fondos de garantía.',
    ],
  ),
  SeccionLegal(
    numero: '10',
    titulo: 'Disponibilidad técnica y servicios de terceros',
    contenido:
        'HELPI opera a través de internet y se apoya en proveedores externos como Google Firebase '
        'y Google Maps. No se garantiza operación ininterrumpida o exenta de fallas de conectividad.',
    puntos: [
      'Pueden ocurrir interrupciones por mantenimiento, actualizaciones o eventos de fuerza mayor.',
      'HELPI no responde por fallas técnicas imputables a redes de telecomunicaciones de terceros.',
    ],
  ),
  SeccionLegal(
    numero: '11',
    titulo: 'Soporte, gestión de cuenta y canales de contacto',
    contenido:
        'Los usuarios pueden solicitar información sobre su cuenta, reportar problemas '
        'o pedir el cierre de su perfil a través de los canales oficiales de contacto.',
    datosPendientes: [
      '[POR DEFINIR: Dirección de correo electrónico de soporte y mesa de ayuda oficial]',
      '[POR DEFINIR: Plazos de respuesta y trámite de solicitudes de soporte]',
    ],
  ),
  SeccionLegal(
    numero: '12',
    titulo: 'Modificaciones y actualizaciones del documento',
    contenido:
        'Cualquier cambio sustancial en estos Términos y condiciones requerirá nueva '
        'aceptación expresa para continuar utilizando las funciones protegidas de HELPI.',
    puntos: [
      'Versión actual: v1.0.',
      'Fecha de vigencia: 11 de noviembre de 2026.',
      'El historial de versiones y aceptaciones se mantiene registrado en el sistema.',
    ],
  ),
];

const List<SeccionLegal> seccionesPrivacidad = [
  SeccionLegal(
    numero: '1',
    titulo: 'Responsable del tratamiento de datos personales',
    contenido:
        'El tratamiento de datos personales en HELPI se realiza conforme a la Ley Orgánica '
        'de Protección de Datos Personales (LOPDP) de la República del Ecuador.',
    datosPendientes: [
      '[POR DEFINIR: Razón social, RUC y domicilio legal del Responsable del Tratamiento]',
      '[POR DEFINIR: Datos de contacto del Delegado de Protección de Datos (DPO)]',
    ],
  ),
  SeccionLegal(
    numero: '2',
    titulo: 'Datos que recopilamos efectivamente',
    contenido: 'HELPI recopila únicamente los datos necesarios para brindar el servicio comunitario:',
    puntos: [
      'Datos de cuenta: identificador único (UID), correo electrónico y nombre provistos por Google Sign-In.',
      'Datos de perfil: nombre visible, número telefónico (+593), ciudad, sector de residencia, habilidades, categorías de ayuda y presentación personal.',
      'Datos de solicitudes: título, descripción, categoría, compensación ofrecida, fecha, horario y ubicación aproximada.',
      'Registros de aceptación: versión y fecha/hora generada por el servidor al aceptar Términos y Privacidad.',
      'Notificaciones: avisos internos sobre el estado de tus solicitudes.',
    ],
  ),
  SeccionLegal(
    numero: '3',
    titulo: 'Datos que NO recopilamos ni vendemos',
    contenido: 'HELPI no comercializa bases de datos personales ni realiza prácticas de rastreo invasivo.',
    puntos: [
      'No recopilamos dirección IP para perfiles comerciales ni huella digital (fingerprinting).',
      'No compartimos información con redes de publicidad programática de terceros.',
      'No accedemos a tus contactos, mensajes privados ni archivos personales fuera de la foto que selecciones voluntariamente.',
    ],
  ),
  SeccionLegal(
    numero: '4',
    titulo: 'Finalidades del tratamiento de datos',
    contenido: 'Tus datos personales se tratan con finalidades legítimas y específicas:',
    puntos: [
      'Autenticar tu identidad técnica y gestionar tu sesión en la plataforma.',
      'Permitir que solicitantes y prestadores coordinen la ayuda comunitaria solicitada.',
      'Mostrar información pública de perfil (nombre, categoría, calificación) a otros miembros de HELPI.',
      'Acreditar el consentimiento y aceptación de las condiciones del servicio.',
    ],
  ),
  SeccionLegal(
    numero: '5',
    titulo: 'Visibilidad, confidencialidad y ubicación',
    contenido: 'La privacidad y la seguridad de los datos están incorporadas en el diseño de la plataforma.',
    puntos: [
      'Tu ciudad y sector son visibles en las publicaciones para permitir la búsqueda comunitaria local.',
      'Tus coordenadas GPS exactas no se publican de forma irrestricta en el mapa.',
      'Tu número de teléfono se utiliza para coordinar los servicios en los que participas y no se expone a usuarios no vinculados.',
    ],
  ),
  SeccionLegal(
    numero: '6',
    titulo: 'Proveedores de servicios y transferencias',
    contenido: 'Para operar la aplicación nos apoyamos en proveedores tecnológicos que cumplen estándares internacionales de seguridad:',
    puntos: [
      'Google Firebase (Google LLC): servicio de autenticación y base de datos Cloud Firestore con cifrado en tránsito y en reposo.',
      'Google Maps Platform (Google LLC): visualización de mapas y búsqueda de sectores.',
      'Cloudinary: servicio opcional para procesamiento y almacenamiento seguro de imágenes de perfil.',
    ],
  ),
  SeccionLegal(
    numero: '7',
    titulo: 'Distinción de consentimientos y permisos',
    contenido:
        'Diferenciamos con claridad los distintos niveles de autorización:',
    puntos: [
      'Aceptación de Términos y condiciones: compromiso contractual para el uso del servicio.',
      'Aviso de privacidad: información transparente sobre el tratamiento de tus datos personales.',
      'Permiso de ubicación del dispositivo: permiso del sistema operativo que puedes activar o desactivar libremente desde tu dispositivo.',
      'No condicionamos el servicio a consentimientos publicitarios.',
    ],
  ),
  SeccionLegal(
    numero: '8',
    titulo: 'Derechos del titular de los datos (LOPDP Ecuador)',
    contenido:
        'Como titular de datos personales en el Ecuador, gozas de los derechos de acceso, '
        'rectificación, actualización, eliminación, oposición y portabilidad.',
    datosPendientes: [
      '[POR DEFINIR: Procedimiento formal y dirección de correo específica para ejercer derechos LOPDP]',
      '[POR DEFINIR: Plazo de respuesta legal (15 días conforme a la LOPDP)]',
    ],
  ),
  SeccionLegal(
    numero: '9',
    titulo: 'Conservación de la información',
    contenido:
        'Tus datos se conservan mientras mantengas activa tu cuenta o hasta que solicites '
        'su eliminación, salvo obligaciones legales o tributarias aplicables en Ecuador.',
    datosPendientes: [
      '[POR DEFINIR: Período de retención legal para auditorías y comprobantes contables]',
    ],
  ),
  SeccionLegal(
    numero: '10',
    titulo: 'Vigencia y cambios en el Aviso de privacidad',
    contenido:
        'Toda modificación relevante a este aviso se publicará oportunamente en la plataforma '
        'y requerirá aceptación previa cuando afecte las finalidades del tratamiento.',
    puntos: ['Versión: v1.0.', 'Fecha de vigencia: 11 de noviembre de 2026.'],
  ),
];
