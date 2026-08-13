# Producto

## Roles

- **Administrador:** gestiona la aprobación de academias, sin pertenecer a una
  academia concreta.
- **Dueño:** configura y opera su academia.
- **Profesor:** crea clases y gestiona asistencias dentro de su academia.
- **Alumno:** consulta contenidos, mantiene su perfil y reserva clases según su
  suscripción.

El registro público crea únicamente Alumnos que se unen a ITACA, la única
academia operativa en esta versión (ver `FREEZE.md`). El alta de Dueños de
academias nuevas existe en el código pero está congelada — no tiene ningún
acceso desde la interfaz. Administradores y Profesores nunca se autoasignan
desde el cliente.

## Gestión de Profesores y equipo

El Dueño dispone de una pantalla de equipo con búsqueda y actualización. Puede:

- consultar los miembros de su propia academia;
- convertir un Alumno existente en Profesor;
- devolver un Profesor al rol Alumno.

No puede modificar su propio rol, otros Dueños, Administradores ni miembros de
otra academia. Los nuevos miembros se registran primero como Alumnos, de modo
que la identidad y el correo quedan verificados por Supabase Auth antes de
conceder permisos de Profesor.

## Recuperación de contraseña

Desde el inicio de sesión cualquier usuario puede solicitar un enlace de
recuperación. La pantalla siempre muestra una respuesta neutra para no revelar
si un correo está registrado. El enlace abre la aplicación web o móvil, valida
la sesión temporal de Supabase y permite establecer una contraseña nueva de al
menos ocho caracteres.

Después del cambio se cierra la sesión temporal y el usuario vuelve al inicio
de sesión. Supabase envía además una notificación de seguridad por correo.

## Privacidad y diagnóstico

La información de privacidad es accesible antes y después de iniciar sesión.
Explica las categorías de datos, finalidades, proveedores, conservación y
derechos, e identifica a la academia como primer punto de contacto.

El diagnóstico de errores es opcional por despliegue. Cuando Sentry está
configurado, se envía únicamente el identificador interno del usuario; no se
envían nombre, correo ni capturas de pantalla. ITACA no vende datos ni los usa
para publicidad personalizada.

## Notificaciones móviles

Las notificaciones push son opcionales y solo se activan en compilaciones
móviles que incluyan la configuración Firebase de `RESERVAS-APP`. La app pide
permiso al sistema, registra el token del dispositivo para el usuario
autenticado y lo actualiza cuando Firebase lo rota.

El backend procesa una cola desacoplada. Los tokens inválidos se eliminan y los
errores transitorios permanecen pendientes para reintento. Si falta la
configuración de Firebase o el secreto del programador, el envío queda
bloqueado sin afectar al inicio ni al resto de funciones de la aplicación.
