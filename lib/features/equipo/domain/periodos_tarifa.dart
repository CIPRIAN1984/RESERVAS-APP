/// Cómo se cobra cada tipo de tarifa en mano.
///
/// Auditoría del 09/10/2026: la hoja de cobro trataba todas las tarifas como
/// mensuales. El bono trimestral de 80 € cobrado «3 meses» proponía 240 €, y
/// cobrado «1 mes» duraba un mes con las sesiones de un trimestre. Cada
/// opción es ahora un número entero de periodos de la tarifa; [meses] es lo
/// que dura, que es lo que se manda al servidor (y él lo vuelve a comprobar).
typedef OpcionCobro = ({int periodos, int meses, String etiqueta});

List<OpcionCobro> opcionesDeCobro(String periodicidad) =>
    switch (periodicidad) {
      'trimestral' => const [
        (periodos: 1, meses: 3, etiqueta: '1 trimestre'),
        (periodos: 2, meses: 6, etiqueta: '2 trimestres'),
        (periodos: 4, meses: 12, etiqueta: '1 año'),
      ],
      'anual' => const [(periodos: 1, meses: 12, etiqueta: '1 año')],
      // Una clase, que se puede usar durante un mes.
      'suelta' => const [(periodos: 1, meses: 1, etiqueta: '1 clase')],
      _ => const [
        (periodos: 1, meses: 1, etiqueta: '1 mes'),
        (periodos: 3, meses: 3, etiqueta: '3 meses'),
        (periodos: 6, meses: 6, etiqueta: '6 meses'),
        (periodos: 12, meses: 12, etiqueta: '1 año'),
      ],
    };
