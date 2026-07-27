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
