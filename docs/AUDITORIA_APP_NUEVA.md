# Auditoría de la app nueva (ITACA Jiu Jitsu, React + Supabase)

Fecha: 20/11/2026 · Alcance: solo lectura. No se ha tocado RESERVAS-APP, ni Supabase, ni Vercel, ni Stripe.
Origen: `itaca-jiu-jitsu-codigo.zip` subido por Cipri (178 ficheros, ~12.900 líneas de TypeScript, 23 migraciones SQL, 3.100 líneas de SQL).
La copia de MAAT **todavía no se ha recibido**: la parte de "qué tiene MAAT que importa" queda pendiente.

## Qué es

Una PWA (web instalable en el móvil, sin tiendas) hecha con React 19, Vite, Tailwind 4 y Supabase, con despliegue en Cloudflare Pages. Una sola sede (ITACA), con `gym_id` en todo. Su propio plan de mejora dice que copia la estructura y el estilo de la app de MAAT (tema oscuro, 4 pestañas).

Es un proyecto distinto de RESERVAS-APP (Flutter): no comparte código ni modelo de datos.

## Lo que he comprobado yo (y lo que no)

| Comprobación | Resultado |
|---|---|
| Comprobación de tipos (`tsc`) | Pasa |
| Pruebas de lógica (Vitest) | 46 de 46 en verde |
| Compilación de producción | Pasa (un solo bloque de 695 KB, 218 KB comprimido) |
| Secretos en el zip | No hay claves; datos de contacto y `project_ref` sustituidos por ejemplos |
| Pruebas de base de datos (pgTAP, "327" según su documentación) | **No ejecutadas**: necesitan Docker y Supabase local. Las he leído, no las he corrido |
| Prueba de concurrencia (dos reservas a la vez) | No ejecutada; leído el script y la función: el bloqueo de fila es correcto |
| Verla en pantalla en un móvil | **No hecho** |
| Integración continua (CI) | No hay: ni GitHub Actions ni nada equivalente en el zip |

## Lo bueno

- La base de datos manda: reservar, cancelar, fichar y pasar lista son funciones SQL, no código del cliente. Reservar bloquea la fila de la clase (aforo imposible de superar) y la lista de espera sube sola, respetando el límite de clases de cada tarifa.
- Permisos cuidados: RLS en todas las tablas, `anon` sin acceso, funciones con `search_path` fijado, escritura solo por funciones en reservas, asistencia, tarifas, graduaciones. El código QR de la sede solo lo lee el personal (permisos por columna, con la lección del `revoke` de columna ya aprendida). Quien se registra queda **pendiente** hasta que recepción lo activa. Cambiar roles solo el propietario y queda en auditoría. Eliminar cuenta anonimiza (RGPD).
- Asistencia sin duplicados ni en modo avión: cada marca lleva un identificador del móvil y hay cola sin conexión con pruebas. Esto no lo tiene RESERVAS-APP.
- Límites por tarifa bien pensados para ITACA (mes natural, "1 día por semana" por semana de lunes a domingo, bonos en total), con las reglas escritas.
- Ranking sin menores y con opción de ocultarse; fotos en cubo privado; cinturones con historial.
- Documentación honesta: dice qué está simulado y qué falta.

## Lo roto o incompleto

1. **No hay cobros.** No existe Stripe ni registro de pagos: "cobrado" no existe, solo un "previsto" calculado desde las tarifas que recepción asigna a mano. No hay deuda, ni impagos, ni bloqueo por deuda (en `book_session` queda el comentario "PASO 6"). Ni suscripciones ni webhooks. Es justo lo más caro y arriesgado, y lo que RESERVAS-APP ya tiene.
2. **No hay documentos**: la pantalla Documentos está vacía. Sin certificado médico ni descargo firmado.
3. **No hay avisos**: cuando alguien sube de la lista de espera o se cancela una clase, nadie se entera (en el código quedan comentarios "PASO 7"). Tampoco push.
4. **Sin importador desde MAAT.** Los 166 alumnos tendrían que darse de alta uno a uno o hacerse el importador.
5. **Inicio de sesión con Google, correo propio (SMTP) y doble factor para administradores: pendientes.** Sin SMTP propio, el correo gratuito de Supabase manda muy pocos correos por hora: no aguantaría un alta masiva ni los enlaces de acceso de 166 personas.
6. Al eliminar la cuenta de un tutor, sus hijos quedan sin tutor (lo anotan como pendiente).
7. ITACA+ (vídeos): el reproductor simula el avance; no hay vídeo real ni Stripe.
8. Sin pruebas de interfaz ni de extremo a extremo, ni se ha probado en un iPhone y un Android reales (ellos mismos lo apuntan).

## Riesgos con consecuencias reales

| Riesgo | Qué podría pasar | Gravedad |
|---|---|---|
| El QR no se exige en el servidor. La función `check_in` deja a cualquier alumno con sesión fichar su propia clase reservada dentro de la ventana (30 min antes, 15 después) **sin estar delante del cartel**; `check_in_by_code` solo es la vía del botón. Además el cartel es un QR fijo que se puede fotografiar. Su decisión nº 28 dice lo contrario. | Alumnos fichando desde casa: asistencia falsa, ranking falseado, estadísticas y futuros "listo para graduar" sin valor | Media |
| Los **profesores leen el perfil completo de todos los alumnos** por la API (política `profiles_select` con rol `coach`), incluidos NIF y dirección de facturación, teléfono, fecha de nacimiento y contacto de emergencia. Solo recepción y administración necesitan el NIF. | Un profesor (o una cuenta de profesor robada) puede bajarse los datos fiscales de los 166 alumnos. Problema de minimización de datos (RGPD) | Media |
| **Modo demo silencioso**: sin las variables de Supabase la app arranca con datos de ejemplo, sin avisar. | Un despliegue al que se le olvida la configuración enseña reservas y alumnos inventados y parece funcionar | Media |
| Un alumno o tutor puede editar su propia fecha de nacimiento (`profiles_update` sin límite de columnas). | Un padre cambia la edad de su hijo para entrar en clases de adultos, o al revés | Baja |
| Todo se asigna a mano: recepción es el único control del dinero y no queda registro de qué se cobró. | Con ~10.000 €/mes, errores de cuota que nadie puede cuadrar | Alta si se usara para cobrar |
| Supabase gratuito: el propio plan de producción indica plan gratuito. Ese plan pausa los proyectos inactivos y no incluye copias de seguridad diarias (comprobar en tu panel). | Caída o pérdida de datos de 166 personas | Alta si se lanza así |
| Supuesto de una sola sede en funciones clave (`join_default_gym` toma la primera sede; `my_plan_status` y `has_itaca_plus` la primera pertenencia). El `gym_id` está en las tablas, pero la lógica no es realmente multi-sede. | Si algún día hay segunda sede (Ítaca 2), habría que revisar esas funciones | Baja ahora |

## Comparación con RESERVAS-APP

| Tema | App nueva | RESERVAS-APP |
|---|---|---|
| Tecnología | PWA React, Cloudflare | Flutter (web, Android, iOS), Vercel |
| Cobros | Ninguno (solo previsto) | Stripe Connect, webhook, cuotas en efectivo, renovación y pausa, descuentos |
| Familias y menores | Tutor con menores sin cuenta (`add_minor`), selector de hijos | Familias y tutores con varias rondas de pruebas |
| Documentos | Vacío | Hay (`documentos_alumno`) |
| Pasar lista y asistencia | **Mejor**: QR de sede, kiosco, cola sin conexión, sin duplicados | Pasar lista con candados de hora |
| Límite de clases por tarifa | Semana / mes / bono, bien definido | Tarifas por clases, ciclo de consumo, saldo por ciclo |
| Ranking y novedades | Con podio y ocultarse | Hay ranking por periodo y novedades |
| Graduaciones | Historial; criterios aún provisionales | Promociones y "listo para graduarse" |
| Avisos | Ninguno | Push (`send-push`) y avisos a tutores |
| Pruebas | Vitest 46 + pgTAP (declaradas 327), sin CI | 46 suites pgTAP, pruebas golden, CI |
| Migraciones | 23 | 73 |
| Usuarios reales | Ninguno todavía | Ninguno todavía |

## Qué se podría reutilizar (como idea o especificación, no copiando código)

El código de interfaz no se puede copiar: otro lenguaje y otro modelo. Lo aprovechable son las reglas y los diseños:

- Fichar con QR de sede + modo kiosco, con la cola sin conexión y el identificador por marca (lo único que RESERVAS-APP no tiene). Si se quiere, hay que corregir antes el hueco de `check_in`.
- La regla "1 día por semana" y los casos límite de límites por tarifa, con sus pruebas, para contrastar con las reglas de RESERVAS-APP.
- Generar clases con 12 semanas de horizonte y manejar cambios de hora sin dejar clases sueltas (la migración `move_bookings_on_edit`).
- El flujo de **solicitud de tarifa**: el alumno pide, recepción aprueba o rechaza con motivo.
- Alta pendiente de aprobación hasta que recepción activa (RESERVAS-APP ya tiene aprobación de academias; aquí es por alumno).
- La documentación de diseño (`docs/diseno/`, 11 pantallas) y `docs/SPEC.md` como material de decisión.

## Qué no encaja con lo ya decidido en RESERVAS-APP

- **ITACA+ (vídeos, currículos)** pertenece al mundo de `itacaplus` y a lo que Cipri ya decidió no mezclar ("el método pedagógico vive en itacaplus"). Aquí está dentro de la propia app.
- El tema es **oscuro** con botones blancos (copiando a MAAT); RESERVAS-APP decidió solo tema claro y amarillo eléctrico.
- Cuenta de Google y dominio propio: las mismas dependencias externas que RESERVAS-APP tendrá en algún momento.

## Qué falta saber (necesita la copia de MAAT)

- Qué hace MAAT que a la academia le importa de verdad: facturación y recibos, domiciliaciones, emails automáticos, informes, lo que usan recepción y profesores a diario.
- Si los datos de MAAT se pueden exportar (alumnos, tarifas, historial de asistencia) y en qué formato, para el importador.
- Qué parte del Stripe de MAAT sigue activa y cómo se migran las suscripciones.

## Decisiones que tiene que tomar Cipri

1. ¿El fichaje con QR/kiosco te importa lo bastante como para llevarlo a RESERVAS-APP? Si sí, hay que decidir si se exige estar delante del cartel (QR que cambia, ubicación) o si basta con la confianza actual.
2. ¿Los profesores deben ver NIF, dirección y teléfono de todos los alumnos, o solo recepción y administración?
3. ¿Quieres una PWA (sin tiendas) como la app nueva o seguir con Flutter para publicar en tiendas?
4. ¿Los vídeos de ITACA+ van dentro de la app de reservas o separados, en `itacaplus`?
5. ¿Estilo oscuro (parecido a MAAT, para que los alumnos no noten el cambio) o el claro de I+?
6. ¿Me pasas la copia de MAAT y, si se puede, una exportación de datos (sin datos reales por el chat) para cerrar la comparativa?
