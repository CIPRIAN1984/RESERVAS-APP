// Recorrido en el navegador: la app en modo claro, cambio a oscuro desde
// Perfil → Apariencia, y capturas de las pantallas principales en oscuro.
const L = require("./lib.cjs");
(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  try {
    await L.entrar(p, "alumno1@prueba.itaca.test", process.env.CLAVE);
    await L.espera(p, "Reservar plaza", 20000);
    await L.foto(p, "40_claro_inicio");
    await L.pulsar(p, "Perfil", { exacto: true });
    await p.waitForTimeout(1500);
    await L.espera(p, "Oscuro", 10000);
    await L.pulsar(p, "Oscuro", { exacto: true });
    await p.waitForTimeout(800);
    await L.foto(p, "41_oscuro_perfil");
    await L.pulsar(p, "Inicio", { exacto: true });
    await p.waitForTimeout(1500);
    await L.foto(p, "42_oscuro_inicio");
    await L.ir(p, "/#/tarifas");
    await p.waitForTimeout(2000);
    await L.foto(p, "43_oscuro_tarifas");
    // Recarga: debe recordar el modo.
    await p.reload();
    await p.waitForTimeout(3000);
    await L.foto(p, "44_oscuro_tras_recargar");
    console.log("fondo tras recargar:", await p.evaluate(() => getComputedStyle(document.body).backgroundColor));
  } catch (e) { console.log("ERROR", e.message.slice(0, 600)); await L.foto(p, "40_error"); }
  console.log("errores:", p.errores.slice(0, 3));
  await b.close();
})();
