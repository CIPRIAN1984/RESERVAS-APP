class ConfiguracionReservas {
  const ConfiguracionReservas({
    required this.listaEsperaActiva,
    required this.cancelacionLimiteMinutos,
    required this.zonaHoraria,
    required this.exigirCuotaParaReservar,
  });

  factory ConfiguracionReservas.fromJson(Map<String, dynamic> json) {
    return ConfiguracionReservas(
      listaEsperaActiva: json['lista_espera_activa'] as bool? ?? true,
      cancelacionLimiteMinutos:
          json['cancelacion_limite_minutos'] as int? ?? 240,
      zonaHoraria: json['zona_horaria'] as String? ?? 'Europe/Madrid',
      exigirCuotaParaReservar:
          json['exigir_cuota_para_reservar'] as bool? ?? false,
    );
  }

  final bool listaEsperaActiva;
  final int cancelacionLimiteMinutos;
  final String zonaHoraria;

  /// Si está activo, solo reserva quien tiene la cuota al corriente. Apagado
  /// —que es lo normal— cualquiera se apunta y el Dueño lo ve marcado como
  /// «sin cuota» en la lista de la clase.
  final bool exigirCuotaParaReservar;

  int get cancelacionLimiteHoras => cancelacionLimiteMinutos ~/ 60;
}
