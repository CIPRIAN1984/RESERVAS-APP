# Privacidad y protección de datos

Última actualización: 27 de julio de 2026.

## Alcance y responsabilidad

ITACA permite que cada academia gestione a sus miembros. La academia en la que
está registrada una persona es el primer punto de contacto para solicitudes
sobre sus datos. Antes de entregar, rectificar o eliminar información debe
verificar la identidad del solicitante.

## Categorías de datos

- Identidad y cuenta: nombre, apellidos, correo gestionado por Auth, fotografía,
  rol, estado y cinturón.
- Actividad de academia: clases, reservas, lista de espera, asistencias,
  progreso, ranking, noticias, cambios de escuela y préstamos.
- Contratación: tarifa, estado de suscripción, pedidos y referencias externas
  de pago. ITACA no almacena los datos completos de una tarjeta.
- Comunicaciones: tokens técnicos para notificaciones push cuando el usuario
  las habilita.
- Diagnóstico: errores técnicos y rendimiento cuando Sentry está configurado.
  Se usa un UUID interno sin nombre ni correo; la PII predeterminada y las
  capturas de pantalla están desactivadas.

## Finalidades

Los datos se utilizan para prestar la aplicación, aplicar los permisos de cada
rol, operar reservas y cobros, enviar comunicaciones solicitadas, proteger las
cuentas y resolver incidencias. No se venden ni se destinan a publicidad
personalizada.

## Proveedores

- Supabase: autenticación, base de datos, archivos y funciones de backend.
- Stripe: pagos y suscripciones.
- Firebase Cloud Messaging: notificaciones push.
- Vercel: alojamiento de la aplicación web.
- Sentry: diagnóstico opcional de errores técnicos.

Cada proveedor debe configurarse únicamente para `RESERVAS-APP`, con acceso
mínimo y sin reutilizar credenciales de otros proyectos.

### Agente personal del Dueño

El Dueño puede generar claves de **solo lectura** (*Herramientas → Claves para
tu agente*) para que un asistente externo — hoy ChatGPT — consulte datos de su
academia. Esto añade un proveedor que el Dueño elige por su cuenta, así que
conviene tenerlo claro:

- Lo que el agente lee **sale de la app** y entra en la empresa que lo
  fabrica. Cada consulta queda registrada en `consultas_agente` y el Dueño la
  ve en la propia pantalla.
- Por defecto el agente accede a datos de gestión: recuentos, estado de cuota,
  cinturón, asistencia y horario, con nombre y apellidos en los avisos.
- **El correo electrónico solo sale si esa clave lo tiene autorizado**
  expresamente (`incluye_contacto`), y el interruptor viene apagado. Es el
  único dato de contacto que la app guarda de un alumno; no hay teléfonos.
- Las claves se anulan en cualquier momento y el corte es inmediato.

Una academia que quiera usar esto debe valorar si su base legal cubre esa
comunicación a un tercero, e informarlo en su propio aviso de privacidad. Si
no está segura, la recomendación es dejar el interruptor de contacto apagado:
los recuentos y avisos funcionan igual.

## Conservación

Los datos operativos se mantienen mientras la cuenta y la relación con la
academia estén activas. Al tramitar una baja se eliminan o anonimizan cuando ya
no sean necesarios, salvo los registros que deban conservarse por obligaciones
legales, contractuales, antifraude o de defensa de reclamaciones. Los plazos
concretos deben ser definidos por la academia según su jurisdicción.

## Derechos

La persona puede solicitar acceso, rectificación, supresión, portabilidad,
limitación u oposición a través de la academia. El procedimiento operativo y
las comprobaciones necesarias están documentados en `OPERATIONS.md`.

## Seguridad y transparencia

La base de datos aplica aislamiento por academia y rol. Las claves privadas no
se distribuyen en Flutter ni se versionan. Los incidentes se investigan con el
mínimo dato técnico necesario y se documentan sin copiar secretos ni datos
personales a tickets, commits o chats.
