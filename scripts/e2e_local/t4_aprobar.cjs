const L = require("./lib.cjs");
(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  try {
    await L.entrar(p, "dueno@prueba.itaca.test", process.env.CLAVE);
    await L.espera(p, "Reservar plaza", 20000);
    await L.hash(p, "#/miembros");
    await L.espera(p, "alta pendiente", 15000);
    await L.foto(p, "14_miembros_aviso");
    await L.pulsar(p, "alta pendiente");
    await L.espera(p, "Aprobar a Nuria");
    await L.foto(p, "15_altas_pendientes");
    await L.pulsar(p, "Aprobar a Nuria");
    await p.waitForTimeout(1500);
    await L.foto(p, "16_tras_aprobar");
    console.log("pantalla:", (await L.textos(p)).join(" | ").slice(0, 500));
  } catch (e) { console.log("ERROR", e.message.slice(0, 600)); await L.foto(p, "14_error"); }
  console.log("errores:", p.errores.slice(0, 3));
  await b.close();
})();
