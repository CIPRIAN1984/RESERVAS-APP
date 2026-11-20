const L = require("./lib.cjs");
(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  try {
    await L.entrar(p, "profe@prueba.itaca.test", process.env.CLAVE);
    await L.espera(p, "Cambiar a Gestor", 20000);
    await L.pulsar(p, "Cambiar a Gestor");
    await L.espera(p, "Confirmar 1 alumno");
    await L.pulsar(p, "Confirmar 1 alumno"); await L.pulsar(p, "Confirmar todos", { exacto: true });
    await p.waitForTimeout(2500);
    await L.foto(p, "23_asistencia_confirmada");
    console.log("pantalla:", (await L.textos(p)).slice(0, 14).join(" | ").slice(0, 500));
  } catch (e) { console.log("ERROR", e.message.slice(0, 600)); await L.foto(p, "23_error"); }
  console.log("errores:", p.errores.slice(0, 3));
  await b.close();
})();
