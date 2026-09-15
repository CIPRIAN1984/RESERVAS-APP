/// Una llave de solo lectura entregada al agente personal del Dueño.
///
/// Deliberadamente **no** guarda la clave: el servidor solo la enseña una vez,
/// al crearla, y después conserva su huella. Aquí solo llegan los últimos
/// cuatro caracteres ([pista]), lo justo para distinguir una de otra en la
/// lista.
class ClaveAgente {
  const ClaveAgente({
    required this.id,
    required this.nombre,
    required this.pista,
    required this.incluyeContacto,
    required this.creada,
    this.ultimoUso,
    this.revocada,
    this.consultas = 0,
  });

  factory ClaveAgente.fromJson(Map<String, dynamic> json) => ClaveAgente(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    pista: json['pista'] as String,
    incluyeContacto: json['incluye_contacto'] as bool? ?? false,
    creada: DateTime.parse(json['creada_at'] as String),
    ultimoUso: json['ultimo_uso_at'] == null
        ? null
        : DateTime.parse(json['ultimo_uso_at'] as String),
    revocada: json['revocada_at'] == null
        ? null
        : DateTime.parse(json['revocada_at'] as String),
    consultas: (json['consultas'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String nombre;
  final String pista;
  final bool incluyeContacto;
  final DateTime creada;
  final DateTime? ultimoUso;
  final DateTime? revocada;
  final int consultas;

  bool get activa => revocada == null;
}

/// Una consulta que el agente ya ha hecho — el registro que puede mirar el
/// Dueño para saber qué ha estado leyendo.
class ConsultaAgente {
  const ConsultaAgente({
    required this.cuando,
    required this.clave,
    required this.consulta,
  });

  factory ConsultaAgente.fromJson(Map<String, dynamic> json) => ConsultaAgente(
    cuando: DateTime.parse(json['at'] as String),
    clave: json['clave'] as String? ?? '',
    consulta: json['consulta'] as String,
  );

  final DateTime cuando;
  final String clave;
  final String consulta;
}
