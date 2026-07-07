enum AcademiaEstado { pending, approved, rejected }

extension AcademiaEstadoX on AcademiaEstado {
  String get value => switch (this) {
    AcademiaEstado.pending => 'pending',
    AcademiaEstado.approved => 'approved',
    AcademiaEstado.rejected => 'rejected',
  };

  static AcademiaEstado fromValue(String value) => switch (value) {
    'pending' => AcademiaEstado.pending,
    'approved' => AcademiaEstado.approved,
    'rejected' => AcademiaEstado.rejected,
    _ => throw ArgumentError('Estado de academia desconocido: $value'),
  };
}
