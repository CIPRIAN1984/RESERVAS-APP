const L = require("./lib.cjs");
(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  try {
    await L.entrar(p, "dueno@prueba.itaca.test", process.env.CLAVE);
    await L.espera(p, "Reservar plaza", 20000);
    await L.hash(p, "#/miembros");
    await L.espera(p, "Nuria", 15000);
    await L.pulsar(p, "Registrar cobro en efectivo", { n: 1 });
    await L.pulsar(p, "Bono 10 sesiones");
    await L.foto(p, "18_bono_elegido");
    await L.pulsar(p, "Registrar cobro", { exacto: true });
    await p.waitForTimeout(2000);
    await L.foto(p, "19_cobro_hecho");
    console.log("pantalla:", (await L.textos(p)).filter(t => /Cuota registrada|Al día|AL DÍA|cuota/i.test(t)).join(" | "));
  } catch (e) { console.log("ERROR", e.message.slice(0, 600)); await L.foto(p, "18_error"); }
  console.log("errores:", p.errores.slice(0, 3));
  await b.close();
})();
