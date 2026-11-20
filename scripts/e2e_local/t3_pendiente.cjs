const L = require("./lib.cjs");
(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  try {
    await L.entrar(p, process.env.CORREO, process.env.CLAVE);
    await L.espera(p, "pendiente", 20000);
    await L.foto(p, "13_pendiente");
    console.log("pantalla:", (await L.textos(p)).join(" | ").slice(0, 400));
    // ¿Puede ver algo de la academia por la API con su propia sesión?
    const r = await p.evaluate(async () => {
      const k = Object.keys(localStorage).find((x) => x.includes("auth-token"));
      const s = JSON.parse(localStorage.getItem(k));
      const h = { apikey: window.__anon, Authorization: "Bearer " + s.access_token };
      return s.access_token ? "sesion ok" : "sin sesion";
    });
    console.log(r);
  } catch (e) { console.log("ERROR", e.message.slice(0, 500)); await L.foto(p, "13_error"); }
  console.log("errores:", p.errores.slice(0, 3));
  await b.close();
})();
