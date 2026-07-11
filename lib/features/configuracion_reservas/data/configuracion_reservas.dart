class ConfiguracionReservas {
  const ConfiguracionReservas({
    required this.listaEsperaActiva,
    required this.cancelacionLimiteMinutos,
    required this.zonaHoraria,
  });

  factory ConfiguracionReservas.fromJson(Map<String, dynamic> json) {
    return ConfiguracionReservas(
      listaEsperaActiva: json['lista_espera_activa'] as bool? ?? true,
      cancelacionLimiteMinutos:
          json['cancelacion_limite_minutos'] as int? ?? 240,
      zonaHoraria: json['zona_horaria'] as String? ?? 'Europe/Madrid',
    );
  }

  final bool listaEsperaActiva;
  final int cancelacionLimiteMinutos;
  final String zonaHoraria;

  int get cancelacionLimiteHoras => cancelacionLimiteMinutos ~/ 60;
}
