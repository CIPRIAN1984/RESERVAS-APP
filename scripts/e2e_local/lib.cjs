// Utilidades para manejar la app Flutter web con Playwright (semántica activada).
const fs = require("fs");
const path = require("path");
const { chromium } = require(process.env.PW);

const BASE = process.env.BASE || "http://127.0.0.1:3000";
const SHOTS = path.join(__dirname, "shots");
fs.mkdirSync(SHOTS, { recursive: true });

async function abrir() {
  const browser = await chromium.launch({
    executablePath: "/opt/pw-browsers/chromium",
    args: ["--no-sandbox", "--force-renderer-accessibility"],
  });
  return browser;
}

async function sesion(browser) {
  const ctx = await browser.newContext({
    viewport: { width: 412, height: 915 },
    deviceScaleFactor: 2,
    locale: "es-ES",
    timezoneId: "Europe/Madrid",
  });
  const page = await ctx.newPage();
  page.errores = [];
  page.on("pageerror", (e) => page.errores.push(String(e).slice(0, 300)));
  page.on("console", (m) => {
    if (m.type() === "error" && !/fonts\.gstatic|Failed to load resource/.test(m.text()))
      page.errores.push(m.text().slice(0, 300));
  });
  return page;
}

async function ir(page, ruta = "/#/login") {
  await page.goto(BASE + ruta, { waitUntil: "networkidle" });
  await semantica(page);
}

// Flutter no crea el árbol accesible hasta que se pulsa su botón oculto.
async function semantica(page) {
  await page.waitForSelector("flt-glass-pane, flutter-view", { timeout: 60000 });
  await page.evaluate(() => {
    const b = document.querySelector("flt-semantics-placeholder");
    if (b) b.click();
  });
  await page.waitForSelector("flt-semantics", { timeout: 30000 });
}

async function foto(page, nombre) {
  await page.waitForTimeout(700);
  await page.screenshot({ path: path.join(SHOTS, nombre + ".png") });
}

// Texto visible de la pantalla (lo que leería un lector de pantalla).
async function textos(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll("flt-semantics")]
      .map((e) => (e.getAttribute("aria-label") || (e.children.length ? "" : e.textContent) || "").trim())
      .filter(Boolean)
  );
}

async function ve(page, texto, ms = 15000) {
  const fin = Date.now() + ms;
  while (Date.now() < fin) {
    const t = await textos(page);
    if (t.some((x) => x.includes(texto))) return true;
    await page.waitForTimeout(300);
  }
  return false;
}

async function espera(page, texto, ms = 15000) {
  if (!(await ve(page, texto, ms))) {
    await foto(page, "FALLO_" + texto.replace(/[^a-z0-9]+/gi, "_").slice(0, 40));
    throw new Error(`No aparece «${texto}». En pantalla: ${(await textos(page)).slice(0, 40).join(" | ")}`);
  }
}

async function pulsar(page, texto, { exacto = false, n = 0 } = {}) {
  await espera(page, texto);
  const h = await page.evaluateHandle(
    ([texto, exacto, n]) => {
      const c = [...document.querySelectorAll("flt-semantics")].filter((e) => {
        const l = (e.getAttribute("aria-label") || (e.children.length ? "" : e.textContent) || "").trim();
        return exacto ? l === texto : l.includes(texto);
      });
      // El más interno primero.
      const hojas = c.filter((e) => !c.some((o) => o !== e && e.contains(o)));
      return hojas[n] || c[n] || null;
    },
    [texto, exacto, n]
  );
  const el = h.asElement();
  if (!el) throw new Error(`No encuentro «${texto}» para pulsar`);
  await el.scrollIntoViewIfNeeded().catch(() => {});
  const box = await el.boundingBox();
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await page.waitForTimeout(600);
}

// Escribe en el campo cuya etiqueta contiene `etiqueta`.
async function escribir(page, etiqueta, valor) {
  const h = await page.evaluateHandle((etiqueta) => {
    const campos = [...document.querySelectorAll("flt-semantics input, flt-semantics textarea, input, textarea")];
    return (
      campos.find((c) => (c.getAttribute("aria-label") || "").includes(etiqueta)) ||
      [...document.querySelectorAll("flt-semantics")].find(
        (e) => (e.getAttribute("aria-label") || "").includes(etiqueta) && e.querySelector("input,textarea")
      ) ||
      null
    );
  }, etiqueta);
  const el = h.asElement();
  if (!el) throw new Error(`No encuentro el campo «${etiqueta}». Campos: ${await page.evaluate(() => [...document.querySelectorAll("input,textarea")].map((c) => c.getAttribute("aria-label")).join(" | "))}`);
  const box = await el.boundingBox();
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await page.waitForTimeout(300);
  await page.keyboard.press("Control+A");
  await page.keyboard.type(valor, { delay: 15 });
  await page.waitForTimeout(200);
}

async function entrar(page, correo, clave) {
  await ir(page, "/#/login");
  await escribir(page, "Email", correo);
  await escribir(page, "Contraseña", clave);
  await pulsar(page, "Iniciar sesión", { exacto: true });
}

module.exports = { abrir, sesion, ir, semantica, foto, textos, ve, espera, pulsar, escribir, entrar, BASE, SHOTS };

// Navega dentro de la app sin recargar (go_router con # en la URL).
async function hash(page, ruta) {
  await page.evaluate((r) => { location.hash = r; }, ruta);
  await page.waitForTimeout(1200);
}
module.exports.hash = hash;
