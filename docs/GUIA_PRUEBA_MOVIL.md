# Guía corta para probar en el móvil

> Solo sirve cuando exista el enlace privado de prueba (ver
> `ENTREGA_PRUEBA.md`, «Depende de Cipri»). Todo es ficticio: no uses tarjetas
> reales.

**Cuentas de prueba** (la contraseña te la pasamos aparte, nunca por chat):
`dueno@`, `profe@`, `alumno1@`, `alumno2@`, `tutor@` + `prueba.itaca.test`.

**Tarjetas de prueba de Stripe:** correcta `4242 4242 4242 4242` · rechazada
`4000 0000 0000 0002`. Cualquier fecha futura y cualquier CVC.

## Recorrido principal (≈10 minutos)

1. **Alta.** Abre el enlace en el móvil → *Crear cuenta* con un correo tuyo de
   prueba → debe decir «Revisa tu correo». Confirma el correo → verás «Tu alta
   está pendiente de aprobación» y **nada más**.
2. **Aprobar.** Entra como `dueno@` → Modo Gestor → **Miembros** → «1 alta
   pendiente» → **Aprobar**.
3. **Pagar con tarjeta.** Entra como la alumna nueva → **Tarifas** → *Pagar con
   tarjeta* → tarjeta `4242…` → vuelves a «Pago recibido, tu cuota ya está
   activa». (Cierra la página justo después de pagar: la cuota debe activarse
   igual.)
4. **Reservar.** Inicio → elige una clase de mañana → *Reservar plaza* → «Inscrito».
5. **Asistencia.** Entra como `profe@` → Modo Gestor → Hoy → la clase →
   *Confirmar todos*.
6. **Comprobar el saldo.** De nuevo como la alumna: **exactamente una clase
   gastada**.

## Casos que conviene probar

- Pagar con la tarjeta rechazada → el pago **no** activa cuota, y el Dueño lo ve
  en Academia → Cobros → «Pagos con problema».
- Cobrar en mano desde la ficha de un alumno → mismos derechos que con tarjeta.
- Alumno nuevo sin aprobar: no ve a nadie más, no puede reservar.
- Profesor: no ve importes, tarifas ni certificados médicos.
- Tutora (`tutor@`): ve a su hijo Hugo y solo a él.
- Recuperar contraseña desde «¿Has olvidado tu contraseña?»: llega el correo y
  el enlace abre la pantalla de nueva contraseña.

## Si algo falla

Haz una captura, apunta la hora y qué cuenta usabas, y pásamelo: con eso se
localiza en los registros.
