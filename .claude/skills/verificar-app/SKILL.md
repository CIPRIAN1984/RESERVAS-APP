---
name: verificar-app
description: Cómo comprobar de verdad que un cambio funciona en esta app Flutter — compilar, levantarla en el navegador, hacer capturas y probar el recorrido. Úsala antes de decir que algo está hecho, sobre todo en cambios visuales.
---

# Verificar la app — I+

**Que compile no significa que funcione, y menos aún que se vea bien.** Un cambio visual sin captura no está verificado.

---

## 1. Preparar el entorno (sesión nueva)

Flutter no viene instalado. Clónalo una vez por sesión:

```bash
git clone -b stable --depth 1 https://github.com/flutter/flutter.git /opt/flutter
export PATH=/opt/flutter/bin:$PATH
flutter --version
```

Tarda unos minutos: lánzalo en segundo plano y sigue con otra cosa mientras.

---

## 2. Comprobaciones mínimas (siempre)

```bash
export PATH=/opt/flutter/bin:$PATH
flutter pub get
flutter analyze          # debe decir "No issues found!"
flutter test             # todo en verde
```

Si tocaste modelos o providers anotados:
```bash
dart run build_runner build --delete-conflicting-outputs
git diff --stat          # si hay cambios, commitéalos: el CI falla si el codegen se desvía
```

Formato (el CI lo exige):
```bash
dart format $(find lib test -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' ! -path '*/l10n/app_localizations*')
```

---

## 3. Verlo de verdad (obligatorio en cambios visuales)

La app arranca sin claves reales: muestra su pantalla de "falta configuración", que **no sirve** para revisar diseño. Para ver pantallas reales hay dos caminos:

### Opción A — Build web y capturas con navegador

```bash
export PATH=/opt/flutter/bin:$PATH
flutter build web --release
cd build/web && python3 -m http.server 8080 &
```

Luego, con Playwright (Chromium ya está en `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`):

```js
const { chromium } = require("playwright-core");
const b = await chromium.launch({
  executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
  args: ["--no-sandbox"],
});
const p = await b.newPage({ viewport: { width: 412, height: 900 } });  // tamaño móvil
await p.goto("http://localhost:8080/", { waitUntil: "networkidle" });
await p.screenshot({ path: "captura.png" });
```

⚠️ **Desactiva el proxy** para llegar a localhost: `NO_PROXY='*' HTTPS_PROXY= node script.js`.

### Opción B — Test de widget con captura

Para una pantalla concreta sin backend, móntala en un `testWidgets` con los providers sobreescritos por datos falsos. Es más rápido que levantar toda la app y sirve para revisar el diseño de un componente.

**Mira la captura tú mismo con la herramienta Read.** No la generes y la des por buena.

---

## 4. Qué comprobar en una captura

- ¿Se lee todo? (contraste sobre fondo claro)
- ¿Hay algún resto del tema oscuro? (texto gris claro invisible, tarjetas negras)
- ¿Las esquinas, espaciados y pesos siguen la skill `diseno-i-plus`?
- ¿Cabe en 412 px de ancho sin desbordar en horizontal?
- ¿Los estados vacíos y de error también están cuidados?

---

## 5. Base de datos

Las pruebas de permisos son pgTAP, en `supabase/tests/`. **No hay Supabase CLI ni Docker en la sesión**, así que se ejecutan en CI. Al tocar SQL:

1. Escribe o actualiza la suite pgTAP correspondiente.
2. Revisa el SQL a mano con especial cuidado en políticas RLS.
3. Deja que el CI del PR lo ejecute y **mira el resultado** antes de decir que está bien.

---

## 6. Cómo informar

- Si lo verificaste: di **qué** ejecutaste y **qué salió**.
- Si no pudiste: **dilo**, y dale a Cipri los pasos exactos para probarlo él.
- Nunca "debería funcionar". O lo comprobaste o no.
