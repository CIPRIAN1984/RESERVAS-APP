// PWA: comprueba con el propio Chrome que la web es instalable (manifiesto,
// iconos, service worker), que el script de instalación carga bajo la política
// de seguridad de producción y que la tarjeta «Instala la app» aparece cuando el
// navegador ofrece instalar.
const L = require("./lib.cjs");
(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  const cdp = await p.context().newCDPSession(p);
  try {
    await L.ir(p, "/#/login");
    await p.waitForTimeout(4000);
    const man = await p.evaluate(async () => { const r = await fetch("manifest.json"); return r.ok ? await r.json() : null; });
    console.log("manifiesto:", man && `${man.name} id=${man.id} start=${man.start_url} display=${man.display} iconos=${man.icons.length}`);
    console.log("api instalación:", await p.evaluate(() => typeof window.itacaInstalar));
    const sw = await p.evaluate(async () => { const r = await navigator.serviceWorker.getRegistration(); return r ? (r.active ? "activo" : "registrado") : "no"; });
    console.log("service worker:", sw);
    await cdp.send("Page.enable");
    const inst = await cdp.send("Page.getInstallabilityErrors");
    console.log("errores de instalabilidad:", JSON.stringify(inst.installabilityErrors));
    // Entra y simula el aviso del navegador antes de abrir Perfil.
    await L.entrar(p, "alumno1@prueba.itaca.test", process.env.CLAVE);
    await L.espera(p, "Reservar plaza", 20000);
    await p.evaluate(() => window.dispatchEvent(new Event("beforeinstallprompt", { cancelable: true })));
    console.log("botón disponible:", await p.evaluate(() => window.itacaInstalar.disponible()));
    await L.pulsar(p, "Perfil", { exacto: true });
    await p.waitForTimeout(1500);
    await L.espera(p, "Instala la app", 10000);
    await L.foto(p, "50_pwa_tarjeta");
    await p.mouse.move(200, 500);
    for (let i = 0; i < 6; i++) { await p.mouse.wheel(0, 500); await p.waitForTimeout(300); }
    await L.foto(p, "51_pwa_tarjeta_abajo");
    console.log("tarjeta visible: true");
  } catch (e) { console.log("ERROR", e.message.slice(0, 500)); await L.foto(p, "50_error"); }
  console.log("errores de consola:", p.errores.slice(0, 4));
  await b.close();
})();
