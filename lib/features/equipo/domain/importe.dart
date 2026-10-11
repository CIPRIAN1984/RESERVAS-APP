/// Lo que se propone cobrar por [periodos] de una tarifa de [precio] cada
/// periodo (un mes, un trimestre, un año o una clase suelta): el Dueño lo
/// puede cambiar si hace descuento. En formato español, con coma decimal,
/// que es como se escribe en la academia.
String importeSugerido(num precio, int periodos) =>
    (precio * periodos).toStringAsFixed(2).replaceAll('.', ',');

/// El importe que ha escrito el Dueño, con coma o con punto. `null` si no
/// es un número o es negativo: así no se puede registrar el cobro.
double? leerImporte(String texto) {
  final valor = double.tryParse(texto.trim().replaceAll(',', '.'));
  if (valor == null || valor < 0) return null;
  return valor;
}
