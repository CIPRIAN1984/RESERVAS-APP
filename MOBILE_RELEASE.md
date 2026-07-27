# Publicación móvil de ITACA

Estado de preparación: el código genera Android e iOS, la firma Android ya no
usa una clave de depuración y existe un proceso manual reproducible para crear
artefactos. La publicación efectiva necesita cuentas, credenciales y decisiones
que no deben inventarse ni guardarse en el repositorio.

## Identidad candidata

- Nombre: `ITACA`
- Android application ID: `com.itaca.itaca`
- iOS bundle ID: `com.itaca.itaca`
- Esquema de deep link: `itaca://`
- Versión inicial: `1.0.0`
- URL web y soporte: `https://itc2-reservas.vercel.app`
- Política de privacidad:
  `https://itc2-reservas.vercel.app/privacidad`

Los IDs deben reservarse en las dos consolas antes de subir el primer binario.
Si alguno no está disponible, hay que decidir el reemplazo y cambiar Android,
iOS, Firebase y los deep links juntos antes de publicar.

## Ficha propuesta

**Descripción breve**

Gestión de clases, reservas y comunidad para academias de Brazilian Jiu-Jitsu.

**Descripción**

ITACA reúne en una sola aplicación la actividad diaria de una academia de BJJ.
Los alumnos consultan el calendario, reservan plaza, entran en lista de espera,
siguen su asistencia y progreso y reciben las novedades de su escuela.

Los profesores y responsables gestionan clases, miembros, tarifas, contenido y
operaciones desde permisos separados por academia y rol. Los pagos se procesan
mediante Stripe y la aplicación no almacena los datos completos de las
tarjetas.

**Categoría sugerida**

Deportes o Salud y forma física. La elección final debe coincidir con el
posicionamiento comercial de la academia.

## Material pendiente para las tiendas

- nombre legal del responsable o empresa;
- correo y URL de soporte;
- política de conservación y plazos legales definitivos;
- icono, capturas por tamaño de dispositivo y gráfico promocional de Play;
- países, precio y fecha de disponibilidad;
- clasificación por edades y respuestas de seguridad/privacidad;
- texto de novedades de la versión;
- cuentas de prueba para el equipo de revisión, sin datos reales.

## Criterio de finalización

1. Push funciona de extremo a extremo en Android e iPhone físicos.
2. El AAB firmado pasa la pista interna de Google Play.
3. El archivo iOS firmado pasa TestFlight.
4. Recuperación de contraseña, reservas y pagos de prueba funcionan en ambas
   instalaciones.
5. Las fichas de privacidad y soporte están completas y verificadas.
6. Google y Apple muestran la versión aprobada en el alcance elegido.
