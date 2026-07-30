---
name: diseno-i-plus
description: Sistema de diseño de la app I+ — colores, tipografías, componentes y reglas visuales. Invócala SIEMPRE antes de crear o modificar cualquier pantalla, widget o token de color, y antes de decidir cómo se ve algo.
---

# Sistema de diseño — I+

Identidad aprobada por Cipri en julio de 2026, a partir del prototipo React y de MAAT (el software que usan a diario). Comparte ADN con **ITACA OS** (monocromo, botones invertidos, mono para etiquetas) pero **en claro en vez de oscuro**.

---

## 1. La regla que gobierna todo

> **Toda la interfaz es blanco, negro y gris. El color solo aparece donde significa algo.**

Solo hay tres excepciones legítimas al monocromo:

| Excepción | Dónde | Por qué |
|---|---|---|
| **Cinturones** | Avatares, ranking, graduación | El azul, morado y marrón **son el dato**, no decoración. En gris no se distinguen. |
| **Estados** | Pastillas de pago, publicado, fijado | Verde/rojo/azul comunican de un vistazo lo que hay que atender. |
| **Amarillo eléctrico** | Día seleccionado, alertas críticas | Único acento de marca. Se usa con cuentagotas. |

Si vas a meter color por cualquier otro motivo, **no lo metas**. Un sistema monocromo es más fuerte, no más pobre, cuando las excepciones son pocas y deliberadas.

---

## 2. Tokens

```
Fondo de pantalla      #FFFFFF   blanco puro
Superficie de tarjeta  #F4F4F5   gris muy claro
Línea / borde          #E7E7EA
Tinta (texto, botones) #0A0A0A
Texto secundario       #71717A
Amarillo eléctrico     #E9FF3D
```

**Semánticos (pastel, siempre con texto oscuro encima):**

```
Verde   fondo #D1FAE5  texto #065F46   → Activa, Pagando, Publicado
Rojo    fondo #FEE2E2  texto #B91C1C   → Impagado, Cancelar
Azul    fondo #E0F2FE  texto #075985   → Prueba
Gris    fondo #E4E4E7  texto #3F3F46   → Sin membresía
Ámbar   fondo #FEF3C7  texto #92400E   → Pausada, Fijado
Rosa    fondo #FAE8FF  texto #A21CAF   → Fechas de compra/renovación
```

**Cinturones** (mantener exactamente estos; los mixtos de niños llevan franja):

```
Adultos: blanco #FFFFFF · azul #1D8FEF · morado #8B2FE0 · marrón #8A4B22 · negro #111111
Niños:   gris #9CA3AF · amarillo #F5C518 · naranja #F97316 · verde #16A34A
         Los mixtos (Gris-Blanco, Amarillo-Negro…) = color base + franja inferior.
```

El blanco necesita un borde `#D4D4D8` para verse sobre fondo claro.

---

## 3. Tipografía

- **Inter Tight** — todo el texto. Variable 100–900.
- **JetBrains Mono** — etiquetas pequeñas, fechas, cifras en columnas, identificadores.

**Van incrustadas en la app como assets.** Nunca `google_fonts` ni carga por red: en redes con DNS filtrado falla y el texto cambia de fuente. Ya pasó en producción.

**Escala:**

| Uso | Tamaño | Peso | Espaciado |
|---|---|---|---|
| Título de pantalla | 34 | 800 | −0.03em |
| Título de sección | 19 | 800 | −0.02em |
| Título de tarjeta | 17 | 800 | −0.01em |
| Cuerpo | 15–16 | 400 | normal |
| Etiqueta mono | 11 | 400–500 | +0.10em, MAYÚSCULAS |

Las cifras que se comparan en columna llevan `FontFeature.tabularFigures()`.

---

## 4. Componentes

**Tarjeta** — fondo `#F4F4F5`, esquinas **20 px**, sin sombra ni borde. La sombra solo en elementos flotantes (modales, botón flotante).

**Botón principal** — fondo negro, texto blanco, esquinas 16 px, ancho completo, alto ~52 px.

> ⚠️ **Los botones son de ancho completo por tema** (`minimumSize: Size.fromHeight(52)`, que deja el ancho en infinito). Nunca pongas un botón al lado de un texto: dentro de un `ListTile` se queda todo el hueco lateral y el título sale en vertical, una letra por línea; dentro de un `Row` revienta con «BoxConstraints forces an infinite width». Si hace falta uno en línea, acótalo con un `SizedBox(width: …)`. Lo normal es ponerlo debajo, a lo ancho — que es lo que hace `TarjetaFila`.

**Botón secundario** — transparente con borde fino `#0A0A0A` al 25 %.
**Botón destructivo** — rojo sólido `#DC2626`, solo para cancelar suscripción o borrar.

**Pestañas** — pastillas redondeadas completas. Activa: fondo negro, texto blanco. Inactiva: fondo `#F4F4F5`, texto gris.

**Pastilla de estado** — esquinas 8 px, tipografía mono 11 px en mayúsculas, colores semánticos de §2.

**Calendario semanal** — siete pastillas. El día seleccionado en **amarillo eléctrico** con texto negro. Nunca en negro: el amarillo es la firma visual de la app.

**Avatar** — círculo con iniciales sobre color propio, y un **punto del cinturón** abajo a la derecha con borde blanco.

**Anillo de progreso** (graduación) — círculo con el arco en negro sobre pista `#E7E7EA`, extremos redondeados, porcentaje grande en el centro.

**Gráfico de barras** — barras negras con esquinas redondeadas, etiquetas mono debajo, escala numérica a la derecha.

**Podio del ranking** — el primero más alto y con corona ámbar; los tres con avatar, nombre, cinturón en mono y número de clases.

**Fila de lista** — usa `TarjetaFila`: título, una línea de detalle, y debajo la pastilla de estado o el botón a ancho completo. **No uses `ListTile` con un botón o una etiqueta larga en `trailing`**, por lo dicho arriba. `ListTile` tampoco admite una pastilla en `subtitle`: no llega ni a medirse.

**Estados vacíos** — icono gris de 48 px, mensaje centrado en gris y, si procede, un botón de acción.

---

## 5. Navegación

**Barra inferior fija**, no cajón lateral. Iconos de línea (estilo Lucide); el activo en negro con trazo más grueso y etiqueta debajo de 10 px.

Cuando un destino no aplica al rol (p. ej. Herramientas para un alumno), **no se muestra** — nunca se enseña deshabilitado.

**Como mucho un botón flotante por pantalla, y el de la acción principal.** En un móvil de 412 px dos botones flotantes no caben uno al lado del otro: se pisan entre ellos y tapan lo que haya debajo. El cambio de modo estuvo flotando y se llevó por delante «Reservar plaza», el final de Perfil y el propio «Crear clase»; ahora es el último sitio de la barra inferior. Lo que sea global va a la barra, no al aire.

Toda lista de una pantalla **con** botón flotante lleva `espacioBotonesFlotantes` de hueco al final. Sin él, el último elemento queda debajo del botón y no se puede pulsar ninguno de los dos. En las pantallas sin botón flotante no se pone: solo dejaría un vacío.

---

## 6. Escritura de textos

- En castellano, tuteando, sin jerga técnica.
- Los botones dicen exactamente lo que pasa: "Unirse a la clase", no "Aceptar".
- Los errores explican qué ha fallado y qué hacer, sin disculpas ni tecnicismos.
- Nunca se muestra el texto crudo de una excepción al usuario (usa `mensajeErrorAmigable`).

---

## 7. Accesibilidad

- Zona táctil mínima 44 × 44 px.
- Todo icono sin texto lleva su etiqueta para lectores de pantalla.
- Contraste mínimo 4.5:1 en texto normal — comprobar los pastel sobre blanco.
- Respetar `MediaQuery.disableAnimations` para quien reduce el movimiento.

---

## 8. Al tocar una pantalla existente

1. **Nunca escribas un color a mano.** Todo sale de los tokens. Si falta un token, créalo.
2. Sustituye cualquier `AppColors.textSecondary` heredado del tema oscuro por el token claro equivalente.
3. Comprueba que no queda ningún `Colors.white` / `Colors.black` suelto que rompa el modo claro.
4. **Míralo renderizado** antes de darlo por hecho: invoca `verificar-app`.
