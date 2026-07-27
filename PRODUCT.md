# Producto

## Roles

- **Administrador:** gestiona la aprobación de academias, sin pertenecer a una
  academia concreta.
- **Dueño:** configura y opera su academia.
- **Profesor:** crea clases y gestiona asistencias dentro de su academia.
- **Alumno:** consulta contenidos, mantiene su perfil y reserva clases según su
  suscripción.

El registro público crea únicamente Dueños de nuevas academias o Alumnos que se
unen a una academia aprobada. Administradores y Profesores nunca se
autoasignan desde el cliente.

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
