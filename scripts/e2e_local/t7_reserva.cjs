const L = require("./lib.cjs");
(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  try {
    await L.entrar(p, "nuria@prueba.itaca.test", process.env.CLAVE);
    await L.espera(p, "Reservar plaza", 20000);
    await L.foto(p, "20_nuria_inicio");
    console.log("inicio:", (await L.textos(p)).filter(t=>/Prueba|Fundament|cuota|clases/i.test(t)).slice(0,8).join(" | "));
    await L.pulsar(p, "Reservar plaza", { n: 0 });
    await p.waitForTimeout(2000);
    await L.foto(p, "21_nuria_reservada");
    console.log("tras reservar:", (await L.textos(p)).slice(0, 25).join(" | ").slice(0, 700));
  } catch (e) { console.log("ERROR", e.message.slice(0, 600)); await L.foto(p, "20_error"); }
  console.log("errores:", p.errores.slice(0, 3));
  await b.close();
})();
