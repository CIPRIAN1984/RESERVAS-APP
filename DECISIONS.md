# Decisiones técnicas

## 2026-07-23 — Permisos explícitos para funciones Supabase

Las funciones del esquema `public` se consideran API remota porque PostgREST
puede exponerlas como RPC. Por tanto:

- `PUBLIC`, `anon` y `authenticated` no reciben `EXECUTE` por defecto.
- Cada migración debe conceder explícitamente las RPC que necesite Flutter.
- Las funciones internas, de trigger, cron o mantenimiento quedan accesibles
  solo para su propietario y `service_role`.
- Las funciones fijan `search_path`; no dependen del valor de la sesión.
- Las funciones `SECURITY DEFINER` deben validar identidad y rol cuando sean
  RPC públicas. Los avisos restantes del Security Advisor se revisan como
  excepciones explícitas, no se ignoran globalmente.

Motivo: reducir la superficie RPC, evitar que helpers internos se conviertan
en endpoints y mantener los permisos reproducibles entre entornos Supabase.

## 2026-07-27 — Bootstrap del Administrador inicial fuera del registro público

El primer Administrador se crea a partir de un usuario de Auth con correo
confirmado mediante `bootstrap_initial_admin`. La función:

- solo es ejecutable por `service_role` y por el propietario de la base;
- usa un bloqueo transaccional para impedir carreras;
- solo funciona mientras no exista ningún Administrador;
- no convierte perfiles ya existentes ni acepta usuarios anónimos;
- nunca se invoca desde Flutter ni depende de metadata controlada por cliente.

Motivo: el alta pública debe limitarse a Dueños y Alumnos. Un secreto de
bootstrap en el cliente permitiría autoascensos y no puede protegerse en una
aplicación web o móvil.

## 2026-07-27 — Observabilidad con minimización de datos

La capa de errores de Flutter continúa centralizada en `Observability` y solo
se activa cuando el despliegue aporta un `SENTRY_DSN`.

- `sendDefaultPii`, las capturas de pantalla, la jerarquía visual y la captura
  automática de peticiones fallidas permanecen desactivadas.
- El usuario se identifica únicamente por su UUID interno, sin nombre ni
  correo.
- La versión reportada es el commit del despliegue.
- En producción se muestrea el 5 % de las trazas; los errores siguen
  capturándose.
- Sin Sentry, los errores controlados solo muestran tipo y contexto en modo
  debug; no se imprime su contenido en builds de producción.

La disponibilidad web se vigila con una prueba sintética de solo lectura sobre
el dominio canónico y las rutas críticas. Web Analytics y Speed Insights no se
activan automáticamente porque su uso y coste requieren una decisión separada.

## 2026-07-27 — Identidad y firma de las aplicaciones móviles

Se conserva `com.itaca.itaca` como identificador candidato de Android e iOS
porque ya forma parte del código nativo y de los deep links. Debe comprobarse
su disponibilidad en Google Play Console y Apple Developer antes de la primera
alta; después del primer binario no se cambia.

Las compilaciones Android de producción nunca usan la clave debug. La firma se
inyecta desde secretos de GitHub y se entrega como Android App Bundle para Play
App Signing. iOS requiere firma administrada por la cuenta Apple y una
distribución posterior desde Xcode o App Store Connect.

La configuración Firebase se inyecta por plataforma durante la compilación y
no se comparte con otros proyectos. El cliente solo habilita push cuando
`PUSH_ENABLED=true`. `send-push` se despliega sin verificación JWT porque lo
invoca un programador, pero falla de forma cerrada si `CRON_SECRET` no existe o
no coincide.

## 2026-07-29 — Eliminación definitiva del árbol de progreso

El módulo de técnicas (pantallas, tablas `tecnicas`, `media_tecnica` y
`progreso_alumno_tecnica`, sus funciones y disparadores) se retira de raíz por
decisión de producto. No se vuelve a proponer.

Motivo: las técnicas que contenía eran una plantilla genérica de BJJ de relleno
—no el método Ítaca, que vive en el repositorio `itacaplus` y no se replica
aquí—, y mantener un módulo vacío de significado añadía superficie de código,
de base de datos y de permisos sin aportar nada al lanzamiento.

Comprobación previa al borrado, ejecutada contra producción antes de aplicar
`20260729090000_eliminar_arbol_progreso.sql`:

- `tecnicas`: 14 filas, exactamente las 14 de la plantilla sembrada por trigger.
- `media_tecnica`: 0 filas.
- `progreso_alumno_tecnica`: 14 filas, todas en el estado por defecto
  (`bloqueada`) y todas con `marcado_por = NULL`.

Es decir, ninguna fila creada ni evaluada por una persona: el borrado no
destruyó trabajo de nadie. La operación es irreversible.

`aprobar_academia` se redefinió **antes** de borrar `sembrar_tecnicas_default`,
para que la RPC no quedara en ningún momento apuntando a una función
inexistente. Dos suites pgTAP que antes comprobaban la siembra ahora comprueban
lo contrario: que el módulo sigue eliminado.

Aplicada a producción el 29/07/2026, a la vez que se fusionó el rediseño I+.

## 2026-07-30 — El cambio de modo baja a la barra inferior

El botón para saltar entre **Entrenamiento** y **Gestor** era un botón
flotante. Se ha movido al último sitio de la barra inferior, visible solo para
dueño y profesor.

Motivo: en un móvil de 412 px de ancho no caben dos botones flotantes uno al
lado del otro. El de modo mide 177 px y el de la acción de la pantalla
(«Crear clase») mide 234 px; sumados con los márgenes pasan de 440 px. Estando
centrado tapaba «Reservar plaza» y la última fila de Perfil; llevándolo a la
izquierda seguía solapándose 31 px con «Crear clase». No era un problema de
colocación sino de sitio: sobra un botón flotante.

Lo global va a la barra; el aire se reserva a la acción principal de cada
pantalla. Como efecto lateral, el cambio de modo pasa a estar siempre visible y
con su nombre escrito, en vez de depender de un icono y de una pulsación larga
para ver el rótulo.

Reglas que quedan y están cubiertas por pruebas
(`test/shared/botones_flotantes_test.dart`):

- En modo Entrenamiento no hay ningún botón flotante en Inicio.
- El botón de la pantalla nunca se solapa con la última tarjeta de su lista:
  las listas de pantallas **con** botón flotante llevan
  `espacioBotonesFlotantes` de hueco al final.
- Las pantallas **sin** botón flotante no llevan ese hueco: solo dejaría un
  vacío al final.

Los rectángulos se comparan enteros, no los de sus textos: una primera versión
de la prueba comparaba el texto del botón, que es más pequeño, y daba por bueno
un solape real de 31 px.

## 2026-07-30 — Apuntarse a clase sin tener la cuota pagada

`reservar_clase` rechazaba a cualquier Alumno sin suscripción activa y
cobrada. Pasa a ser un ajuste por academia, `exigir_cuota_para_reservar`, y
**por defecto no se exige**.

Motivo, en palabras de Cipri: prefiere que la gente se pueda apuntar aunque
no haya pagado y verlo marcado en la lista de la clase, para cobrarles en
mano cuando aparezcan por el gimnasio. Es como funciona hoy el negocio: la
gente entrena y paga cuando pasa por recepción.

Se hace con un interruptor y no quitando la comprobación, para poder volver
atrás desde la propia app sin tocar la base de datos. El ajuste vive en
Academia → Ajustes de reservas y solo lo cambia el Dueño.

Lo que **no** cambia: sigue haciendo falta cuenta activa, pertenecer a la
academia, que la clase sea futura, el aforo y la lista de espera.

En la lista de la clase, quien no tiene la cuota al día sale con una pastilla
roja «Sin cuota», hay un recuento arriba, y tocar su fila abre directamente
el cobro en efectivo. Las condiciones que decide esa marca son **las mismas**
que comprueba el servidor (activa, cobrada y dentro de fechas): si aquí se
relajaran, la app diría «al corriente» de alguien a quien el servidor
considera moroso.

Cubierto por `supabase/tests/reservar_sin_cuota_test.sql` (12 comprobaciones).
Lo que se protege ahí es que abrir esta puerta no abra ninguna otra: un
alumno no puede tocar el ajuste, ni quitarlo en la academia de al lado, ni
colarse en una clase que no es suya, y el Dueño sigue sin poder cambiar el
estado de su academia por la misma vía.

## 2026-07-30 — Los botones de la app son de ancho completo, y eso se nota

Causa raíz de tres fallos que Cipri fue encontrando por separado: el nombre
de la tarifa en vertical en «Mi cuota», lo mismo en Préstamos, y el nombre
del alumno estrujado en la lista de una clase.

El tema fija `minimumSize: Size.fromHeight(52)` en los botones, y
`Size.fromHeight` deja el **ancho en infinito**. Un botón así, puesto en el
hueco lateral de un `ListTile`, se queda todo el ancho disponible y al título
le deja una columna de un carácter. Dentro de un `Row` directamente revienta
con «BoxConstraints forces an infinite width».

Norma: la acción va **debajo del texto, a lo ancho** (`TarjetaFila`), y si de
verdad hace falta en línea, se acota con un `SizedBox`. `ListTile` tampoco
admite una pastilla de estado en `subtitle`: no llega ni a medirse.

## 2026-07-31 — Las tarifas pasan a llevar clases por ciclo

Hasta ahora una tarifa era nombre, precio y periodicidad: cuota plana, sin
límite de clases. **No era como funciona el negocio.** Cipri lo describió así:
«2 días por semana son 8 al mes, 3 por semana son 12; si la tarifa empieza el
5 de mayo, hasta el 5 de junio puede gastar las que tiene».

Decisiones tomadas con él el 30 y 31 de julio de 2026:

- **El ciclo es mensual y va de fecha a fecha**, no por mes natural. Del 5 de
  mayo al 5 de junio. `clases_incluidas` es **por mes**, no por periodo de
  cobro: una tarifa trimestral no da 24 clases de golpe, da 8 cada mes y se
  cobra cada tres. La periodicidad es de **facturación**; las clases van por
  mes.
- **Lo que sobra se pierde** al renovar. No se acumula.
- **`clases_incluidas` a NULL significa ilimitada.**
- **Sin clases no se puede reservar.** La app lo rechaza y le dice que renueve
  o compre sueltas.
- **Descuenta el profesor al confirmar la clase**, no el alumno al reservar. Y
  confirma a todos los apuntados, **vengan o no**: quien reserva y no aparece
  pierde la clase igual. Puede cancelar hasta 1 hora antes. Es deliberado:
  sin eso, la gente reservaría toda la semana y vendría cuando quisiera.
- **Pasar lista no es marcar ausentes**, es comprobar que todo el que está en
  el tatami está apuntado — o sea, que ha pagado.

**El agujero que esto deja, y cómo se tapa.** Si la clase solo se descuenta al
confirmar, alguien con 1 clase suelta puede reservar las 8 de la semana: al
reservar, el contador todavía no ha bajado. Por eso el número que decide si
puede reservar descuenta **también lo que ya tiene reservado en este ciclo**.
El descuento de verdad sigue siendo el del profesor; lo reservado solo
bloquea. Así «te quedan 6» es un número honesto y nadie acapara plazas.

**Se cuenta por la fecha de la clase, no por la de validación.** Si el
profesor pasa lista dos días tarde, la clase cuenta en el ciclo en el que se
dio, no en el que se apuntó.

**Cobro recurrente con tarjeta: no todavía.** Cipri quiere que las tarifas se
cobren solas cada mes hasta que él dé de baja. Eso es Stripe, y Stripe sigue
sin conectar a cobros reales. Se construye primero todo el mecanismo
funcionando con **cobro en mano**, que es lo que permite probarlo con gente de
verdad en paralelo con MAAT.
