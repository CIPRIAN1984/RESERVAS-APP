enum Rol { administrador, dueno, profesor, alumno }

extension RolX on Rol {
  String get value => switch (this) {
    Rol.administrador => 'administrador',
    Rol.dueno => 'dueño',
    Rol.profesor => 'profesor',
    Rol.alumno => 'alumno',
  };

  static Rol fromValue(String value) => switch (value) {
    'administrador' => Rol.administrador,
    'dueño' || 'dueno' => Rol.dueno,
    'profesor' => Rol.profesor,
    'alumno' => Rol.alumno,
    _ => throw ArgumentError('Rol desconocido: $value'),
  };
}
