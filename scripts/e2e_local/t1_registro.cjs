const L = require("./lib.cjs");
const ACAD = "11111111-1111-4111-8111-111111111111";
const CORREO = process.env.CORREO;
const CLAVE = process.env.CLAVE;
(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  try {
    await L.ir(p, `/#/registro?academia=${ACAD}`);
    await L.espera(p, "Crear cuenta");
    await L.escribir(p, "Nombre", "Nuria");
    await L.escribir(p, "Apellidos", "Nueva");
    await L.escribir(p, "Email", CORREO);
    await L.escribir(p, "Contraseña", CLAVE);
    await L.foto(p, "10_registro_relleno");
    console.log("texto registro:", (await L.textos(p)).join(" | ").slice(0, 600));
    await L.pulsar(p, "Crear cuenta", { exacto: true, n: 1 }).catch(async () => L.pulsar(p, "Crear cuenta"));
    await p.waitForTimeout(2500);
    await L.foto(p, "11_registro_enviado");
    console.log("tras enviar:", (await L.textos(p)).join(" | ").slice(0, 600));
  } catch (e) { console.log("ERROR", e.message.slice(0, 800)); await L.foto(p, "10_error"); }
  console.log("errores:", p.errores.slice(0, 5));
  await b.close();
})();
