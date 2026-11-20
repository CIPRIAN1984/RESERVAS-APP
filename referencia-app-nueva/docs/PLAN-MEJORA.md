# Plan de mejora: diseño y funciones al nivel de la referencia

18 de noviembre de 2026 · Referencia: vídeo de la app MAAT que usa hoy ITACA (96 s, 11 pantallas).

## Resumen

La referencia es más sencilla de usar que nuestra app actual: **tema oscuro, cuatro pestañas sin texto y pocas cosas por pantalla**. Hay que rehacer la capa visual y la navegación, completar el perfil (que en la referencia es el centro de la cuenta) y añadir tres funciones que no tenemos: **ranking, novedades y membresías del alumno**.

Además: **contraseña** después del alta, **registro e inicio de sesión con Google** y recuperación de contraseña.

Se copia la estructura y el estilo, no la marca: logotipo, nombre, iconos e ilustraciones son de ITACA.

## Qué cambia respecto a hoy

| | Hoy | Referencia → objetivo |
| --- | --- | --- |
| Tema | Claro, titulares en mayúsculas condensadas | **Oscuro** (fondo casi negro, tarjetas gris oscuro), titulares en negrita normal ("Estadísticas", "Perfil") |
| Botones | Amarillos y negros | **Blancos con texto negro** ("Reservar clase", "Continuar al pago"); el amarillo solo marca lo seleccionado o "tú" |
| Navegación | 5 pestañas con texto | **4 iconos**: Inicio · Estadísticas · Novedades · Perfil |
| Inicio | Tarjeta grande de próxima clase, rachas, cinturón | Mes y franja de la semana (desplegable a mes completo) + **"Próximas clases" del día elegido** |
| Tarjeta de clase | Hora, nombre, aforo, botón | Logo, nombre, hora, **compartir**, "14/30 asistentes", **profesor**, botón "Reservar clase" |
| Estadísticas | Cinturón, contadores, gráfica por meses con detalle por días | Pestañas **Ranking** (podio de 3 con corona, lista, mi fila fija en amarillo) y **Actividad** (resumen, rendimiento del mes frente al anterior, tendencia por semanas, actividad reciente) + selector de periodo. Se mantiene el detalle por días |
| Novedades | No existe | **Muro de avisos** del gimnasio: fijados arriba, "Mostrar más" |
| Perfil | Datos, enlaces sueltos | Tarjeta con foto y nombre (deslizable entre **perfiles de la familia**), accesos **Membresías** y **Documentos**, aviso "Conecta tu móvil" y menú completo (ver abajo) |
| Membresías | Pantalla Tarifas | **Mis membresías** (activa, válida hasta…) y **Productos disponibles** con pestañas Membresías / Clases sueltas |

### Menú del perfil (igual que la referencia)

| Opción | Contenido |
| --- | --- |
| Configuración de la cuenta | Correo, teléfono, **contraseña**, cuentas vinculadas (Google), **eliminar cuenta** |
| Perfiles | Datos del perfil y **añadir perfil** (hijos bajo tu cuenta; la base ya lo admite) |
| Facturación y pago | Dirección de facturación. Tarjetas: cuando llegue Stripe; hasta entonces, "pago en recepción" |
| Promociones | Cinturón, grados e **historial de graduaciones en línea de tiempo** |
| Contacto de emergencia | El que ya tenemos, en su propia pantalla |
| Contactar con soporte | Correo del gimnasio |
| Ajustes de la app | **Tema** (sistema, claro, oscuro), idioma, notificaciones, privacidad, acerca de y versión |
| Cerrar sesión | |

## Cuenta: contraseña y Google

| Función | Cómo |
| --- | --- |
| Poner contraseña tras darse de alta | En Configuración de la cuenta. La guarda Supabase cifrada; nosotros nunca la vemos |
| Entrar | Pantalla nueva: **correo + contraseña**, **"Continuar con Google"** y "Enviarme un enlace" para quien no tenga contraseña |
| Registrarse | Con Google o con correo y contraseña (confirmación por email) |
| Olvidé mi contraseña | Correo con enlace para crear una nueva |
| Vincular Google a una cuenta existente | Si el correo coincide, Supabase las une |

**Lo que necesito de ti:**
- **Google:** crear unas credenciales OAuth en Google Cloud Console (gratis, unos 10 minutos; te guío paso a paso) y pegarlas en Supabase.
- **Correo propio (obligatorio antes de abrir la app):** recuperar la contraseña y confirmar el registro mandan emails, y el correo gratuito de Supabase solo envía unos pocos por hora. Propongo **Resend**: gratis hasta 3.000 correos al mes, y necesita acceso al DNS del dominio itacajiujitsu.com para enviar como `no-responder@itacajiujitsu.com`.

## Datos que aparecen en el vídeo

- El horario de tu app actual **sí tiene profesor por clase**: Samuel en NoGi Fundamentos de las 7:00, Marta en NoGi/Grappling de las 17:00, "sin entrenador" en Sparring y Kids… y aforo de 30. **Samuel no figura en la web.** Propongo cargar los profesores y aforos de la app actual: ¿me confirmas el horario completo con profesor?
- Aparece también una clase **"Kimono Drills" de 18:00 a 19:00** que no está en la web.

## Estado

- 18/11/2026 · **Fases 1 y 2 hechas**: tema oscuro por defecto con opción clara o "como el sistema" (Perfil → Ajustes de la app), 4 pestañas, Inicio nuevo con mes y semana y tarjeta de clase con compartir. Decisiones aplicadas a la espera de confirmación: ITACA+ como acceso en Inicio y Perfil.
- 18/11/2026 · **Fase 3 hecha** salvo Google, que se deja para el final: entrar con contraseña o enlace, registro (queda pendiente hasta que recepción lo active), olvidé mi contraseña, cambiar contraseña y eliminar cuenta. Tema decidido: oscuro por defecto con opción clara.
- 18/11/2026 · **Fase 4 hecha**: perfil con selector de hijos, Membresías y Documentos, menú completo, Promociones con historial, contacto de emergencia, facturación (pago en recepción) y soporte con los datos de la web. Sin pedir sexo, peso ni DNI (decisión 3 pendiente); el NIF es opcional y solo para facturas.
- 18/11/2026 · **Límite de clases por tarifa** (adelanto de la fase 7) y aforo 50.
- 18/11/2026 · **Fase 5 hecha**: ranking con podio y Actividad. Decisión 2 aplicada como propuse: cada alumno puede ocultarse del ranking; los menores no aparecen.
- 19/11/2026 · **Fase 6 hecha**: Novedades con avisos fijados, en tiempo real y con punto de "sin ver"; el personal publica, edita y borra.
- 19/11/2026 · **Fase 7 hecha**: Mis membresías (también de los hijos), productos con "Solicitar" y solicitudes en Alumnos para recepción. Hover amarillo en todos los botones.
- 19/11/2026 · **ITACA+** a 5 €/mes como complemento que exige una tarifa mensual de pago. **Fase 8 hecha**: Cobros con datos reales y menú Más con el estilo nuevo. Pendiente del plan: Google.

## Plan por fases

Cada fase se prueba (pruebas automáticas y en el navegador, en móvil, tablet y portátil), se publica y se sube a GitHub antes de empezar la siguiente.

| Fase | Contenido | Hecho cuando |
| --- | --- | --- |
| **1. Nuevo estilo y navegación** | Tema oscuro con opción clara, nuevos colores, tipografía y componentes; 4 pestañas; menú lateral en tablet y portátil con el mismo estilo | Todas las pantallas actuales con el estilo nuevo, sin perder funciones |
| **2. Inicio y clases** | Mes y semana desplegable, próximas clases del día, tarjeta nueva con profesor y compartir, detalle de clase con quién va | Reservar, cancelar y fichar como hoy, con el diseño nuevo |
| **3. Cuenta** | Entrar con contraseña, con Google o con enlace; registro; olvidé mi contraseña; poner o cambiar contraseña; eliminar cuenta | Un usuario nuevo se registra con Google; otro pone contraseña y entra con ella |
| **4. Perfil completo** | Tarjeta con perfiles de la familia, menú completo, Promociones con historial, contacto de emergencia, ajustes (tema), soporte | Todas las opciones del menú de la referencia funcionan |
| **5. Estadísticas** | Ranking con podio y mi posición; Actividad con resumen, rendimiento frente al mes anterior, tendencia por semanas y actividad reciente; selector de periodo; detalle por días | Ranking y actividad con datos reales |
| **6. Novedades** | Avisos del personal (fijar, editar, borrar); los alumnos los ven en su pestaña | Un aviso publicado desde la vista del personal aparece a los alumnos al momento |
| **7. Membresías** | Recepción asigna la membresía a cada alumno (tarifa y fecha de fin); el alumno ve "Mis membresías" y los productos disponibles | Un alumno ve su membresía activa y hasta cuándo vale |
| **8. Vista del personal** | Mismo estilo; publicar novedades; asignar membresías; el resto como está | El personal hace todo desde su vista con el estilo nuevo |

Fuera de este plan, más adelante: **pago con tarjeta** (Stripe), **documentos firmados**, **notificaciones push** y **vídeos reales** en ITACA+.

## Decisiones que necesito de ti

1. **ITACA+ (vídeos)** no existe en la referencia. ¿Lo pongo como acceso destacado en Inicio, como opción del Perfil o como quinta pestaña?
2. **Ranking:** muestra nombre, foto, cinturón y clases de todos los alumnos. Propongo que cada alumno pueda ocultarse en Ajustes. ¿De acuerdo?
3. **Datos del perfil:** la referencia pide sexo, peso, país y DNI. Por protección de datos propongo pedir solo sexo y peso, opcionales (útiles para competición), y el DNI únicamente si hace falta para la licencia federativa. ¿Vale?
4. **Tema:** ¿oscuro siempre, como la referencia, u oscuro por defecto con opción clara en Ajustes (mi propuesta)?
5. **Horario con profesores:** ¿me pasas el horario completo con profesor y aforo, o lo saco del vídeo y completas tú lo que falte?
