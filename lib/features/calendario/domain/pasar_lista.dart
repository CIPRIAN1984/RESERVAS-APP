/// Desde cuándo se puede pasar lista de una clase: media hora antes de que
/// empiece, para poder marcar a la gente según va llegando. Antes, nunca: una
/// clase de mañana no se puede confirmar hoy.
///
/// Tiene que coincidir con la política `asistencias_insert` del servidor
/// (20260925100000_pasar_lista_solo_con_la_clase_empezada.sql). Si solo lo
/// comprobara la app, bastaría una llamada directa para saltárselo.
const margenPasarLista = Duration(minutes: 30);

bool sePuedePasarLista(DateTime inicio, {DateTime? ahora}) =>
    !(ahora ?? DateTime.now()).isBefore(inicio.subtract(margenPasarLista));

/// El aviso de «Confirmar todos». Desde el 20/09/2026 una ausencia ya
/// descuenta la clase sola, así que confirmar a todo el mundo ya no hace falta
/// para cobrar: solo sirve para el historial, el ranking y la graduación, y
/// ahí marcar presente a quien no vino es falsearlos.
String avisoConfirmarTodos(int alumnos) {
  final quien = alumnos == 1 ? '1 alumno' : '$alumnos alumnos';
  return 'Se marcará como presente a $quien. Hazlo solo si han venido '
      'todos: a quien no venga ya se le descuenta la clase sin confirmar '
      'nada.';
}
