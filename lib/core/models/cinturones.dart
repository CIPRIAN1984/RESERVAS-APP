/// Nombres de los cinturones para enseñar en pantalla.
///
/// Vivían dentro de `miembros_screen.dart`, que era su único usuario. Al
/// llegar la pantalla de familias hicieron falta en otro sitio, y una
/// pantalla importando de otra pantalla es el principio de una madeja: se
/// suben aquí, que es de donde puede tirar cualquiera.
///
/// El color de cada cinturón NO está aquí: eso es `AppColors.belt`, con el
/// resto de los tokens de diseño.
library;

const _etiquetas = {
  'blanco': 'Blanco',
  'azul': 'Azul',
  'morado': 'Morado',
  'marron': 'Marrón',
  'negro': 'Negro',
  'gris_blanco': 'Gris-Blanco',
  'gris': 'Gris',
  'gris_negro': 'Gris-Negro',
  'amarillo_blanco': 'Amarillo-Blanco',
  'amarillo': 'Amarillo',
  'amarillo_negro': 'Amarillo-Negro',
  'naranja_blanco': 'Naranja-Blanco',
  'naranja': 'Naranja',
  'naranja_negro': 'Naranja-Negro',
  'verde_blanco': 'Verde-Blanco',
  'verde': 'Verde',
  'verde_negro': 'Verde-Negro',
};

/// Cómo se llama un cinturón de cara al usuario.
///
/// Un cinturón desconocido se devuelve tal cual en vez de romper: si algún
/// día la base de datos gana un grado nuevo, la lista sigue funcionando
/// aunque salga con su nombre interno hasta que se añada aquí.
String etiquetaCinturon(String cinturon) => _etiquetas[cinturon] ?? cinturon;

/// Los cinco de adulto, en orden de progresión.
const cinturonesAdultos = ['blanco', 'azul', 'morado', 'marron', 'negro'];

/// Los doce de niño (sistema IBJJF), en orden.
///
/// El blanco de niño es el mismo color que el de adulto y no tiene entrada
/// separada: filtrar por «Blanco» ya trae a todos, niños incluidos.
const cinturonesNinos = [
  'gris_blanco',
  'gris',
  'gris_negro',
  'amarillo_blanco',
  'amarillo',
  'amarillo_negro',
  'naranja_blanco',
  'naranja',
  'naranja_negro',
  'verde_blanco',
  'verde',
  'verde_negro',
];
