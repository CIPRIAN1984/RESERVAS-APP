import 'package:freezed_annotation/freezed_annotation.dart';

part 'plantilla_clase.freezed.dart';
part 'plantilla_clase.g.dart';

/// Un hueco fijo del horario semanal: «BJJ Fundamentals, lunes 19:00».
///
/// El motor que convierte esto en clases de verdad ya existe en el
/// servidor (`generar_mis_clases_recurrentes`, corre solo cada lunes de
/// madrugada): esta pantalla es la que faltaba para poder crear la fila que
/// ese motor necesita, en vez de tener que recrear el calendario a mano
/// cada pocas semanas.
@freezed
abstract class PlantillaClase with _$PlantillaClase {
  const factory PlantillaClase({
    required String id,
    @JsonKey(name: 'academia_id') required String academiaId,
    @JsonKey(name: 'profesor_id') required String profesorId,
    @JsonKey(name: 'profesor_nombre') required String profesorNombre,
    required String titulo,
    String? descripcion,

    /// 0 = domingo … 6 = sábado, igual que `extract(dow from …)` en
    /// Postgres — así se guarda tal cual, sin traducir en ningún sitio.
    @JsonKey(name: 'dia_semana') required int diaSemana,

    /// 'HH:mm', hora local de la academia.
    @JsonKey(name: 'hora_inicio') required String horaInicio,
    @JsonKey(name: 'duracion_min') required int duracionMin,
    @JsonKey(name: 'aforo_maximo') required int aforoMaximo,
    required bool activo,
  }) = _PlantillaClase;

  factory PlantillaClase.fromJson(Map<String, dynamic> json) =>
      _$PlantillaClaseFromJson(json);
}

/// Lunes primero: así se lee un horario semanal, no como devuelve Postgres
/// (que empieza en domingo).
const diasSemana = <int>[1, 2, 3, 4, 5, 6, 0];

const nombresDias = <int, String>{
  0: 'Domingo',
  1: 'Lunes',
  2: 'Martes',
  3: 'Miércoles',
  4: 'Jueves',
  5: 'Viernes',
  6: 'Sábado',
};

const nombresDiasCortos = <int, String>{
  0: 'DO',
  1: 'LU',
  2: 'MA',
  3: 'MI',
  4: 'JU',
  5: 'VI',
  6: 'SA',
};

/// «19:00–20:00», para no repetir esta cuenta en cada sitio que la enseña.
String rangoHorario(String horaInicio, int duracionMin) {
  final partes = horaInicio.split(':');
  final horas = int.parse(partes[0]);
  final minutos = int.parse(partes[1]);
  final inicioEnMinutos = horas * 60 + minutos;
  final finEnMinutos = inicioEnMinutos + duracionMin;
  String formatear(int totalMinutos) {
    final h = (totalMinutos ~/ 60) % 24;
    final m = totalMinutos % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  return '${formatear(inicioEnMinutos)}–${formatear(finEnMinutos)}';
}
