// La barra inferior del modo Gestor a 412 px: «Herramientas» en una línea.
const L = require("./lib.cjs");
(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  try {
    await L.entrar(p, "dueno@prueba.itaca.test", process.env.CLAVE);
    await L.espera(p, "Reservar plaza", 20000);
    console.log("barra:", (await L.textos(p)).slice(-12).join(" | ")); await L.pulsar(p, "Gestor");
    await p.waitForTimeout(2500);
    await L.foto(p, "60_barra_gestor");
    console.log("textos:", (await L.textos(p)).filter((t) => /Herramienta|Miembros|Academia|Novedades|Entrenar|Hoy/.test(t)).join(" | "));
  } catch (e) { console.log("ERROR", e.message.slice(0, 400)); await L.foto(p, "60_error"); }
  await b.close();
})();
