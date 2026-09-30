import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';
import 'package:itaca/features/perfil/data/familia_repository.dart';

/// Auditoría del 30/09/2026: los hijos se quedaban guardados en memoria al
/// cerrar sesión. Si otra persona entraba en el mismo móvil o navegador sin
/// cerrar la app, veía los hijos de la cuenta anterior.
///
/// Regla: todo dato que no se descarta al salir de su pantalla (sin
/// `autoDispose`) tiene que depender del usuario conectado.

/// El usuario conectado, cambiable desde la prueba.
class _Usuario extends Notifier<String?> {
  @override
  String? build() => 'padre-a';

  void cambiar(String? id) => state = id;
}

final _usuarioProvider = NotifierProvider<_Usuario, String?>(_Usuario.new);

/// Como el servidor: devuelve los hijos de quien esté conectado en ese
/// momento (RLS), no de quien pidió la lista la primera vez.
class _RepoFalso implements FamiliaRepository {
  _RepoFalso(this.usuarioActual);

  final String? Function() usuarioActual;

  @override
  Future<List<Profile>> listarHijos() async => [
    Profile(
      id: 'hijo-de-${usuarioActual()}',
      academiaId: 'a1',
      rol: 'alumno',
      nombre: 'Hijo de ${usuarioActual()}',
      estado: 'activo',
    ),
  ];

  @override
  Future<Set<String>> hijosBorrables() async => {'hijo-de-${usuarioActual()}'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _contenedor() {
  late final ProviderContainer c;
  c = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_usuarioProvider)),
      familiaRepositoryProvider.overrideWithValue(
        _RepoFalso(() => c.read(_usuarioProvider)),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('al entrar otra persona, la lista de hijos es la suya', () async {
    final c = _contenedor();
    // Mantener vivo el proveedor, como lo hace la pantalla.
    c.listen(hijosProvider, (_, _) {});

    expect((await c.read(hijosProvider.future)).single.id, 'hijo-de-padre-a');

    c.read(_usuarioProvider.notifier).cambiar('padre-b');

    expect((await c.read(hijosProvider.future)).single.id, 'hijo-de-padre-b');
  });

  test(
    'los hijos que se pueden borrar también son los del nuevo usuario',
    () async {
      final c = _contenedor();
      c.listen(hijosBorrablesProvider, (_, _) {});

      expect(await c.read(hijosBorrablesProvider.future), {'hijo-de-padre-a'});

      c.read(_usuarioProvider.notifier).cambiar('padre-b');

      expect(await c.read(hijosBorrablesProvider.future), {'hijo-de-padre-b'});
    },
  );

  test('el modo vuelve a Entrenamiento al cambiar de usuario', () {
    final c = _contenedor();
    c.listen(appModeProvider, (_, _) {});

    c.read(appModeProvider.notifier).alternar();
    expect(c.read(appModeProvider), AppMode.gestor);

    c.read(_usuarioProvider.notifier).cambiar('alumno-b');

    expect(c.read(appModeProvider), AppMode.entrenamiento);
  });

  test('todo dato que vive toda la sesión depende del usuario conectado', () {
    // Un proveedor sin `autoDispose` no se descarta al salir de su
    // pantalla: si guarda datos de alguien, tiene que rehacerse cuando
    // cambia quién está conectado.
    final declaracion = RegExp(
      r'^final (\w+) =\s*(FutureProvider|StreamProvider|NotifierProvider|'
      r'AsyncNotifierProvider)\b(?!\.autoDispose)',
    );
    final depende = RegExp(
      r'currentUserIdProvider|currentProfileProvider|authStateChangesProvider',
    );
    final sinUsuario = <String>[];

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
        continue;
      }
      final texto = f.readAsStringSync();
      final lineas = texto.split('\n');
      for (var i = 0; i < lineas.length; i++) {
        final m = declaracion.firstMatch(lineas[i]);
        if (m == null) continue;
        // El cuerpo del proveedor, o de su Notifier si lo usa.
        final nombre = m.group(1)!;
        final fin = lineas.indexWhere(
          (l) => l.startsWith('});') || l.startsWith(');'),
          i,
        );
        var cuerpo = lineas
            .sublist(i, fin == -1 ? lineas.length : fin + 1)
            .join('\n');
        final notifier = RegExp(r'(\w+)\.new').firstMatch(cuerpo)?.group(1);
        if (notifier != null) {
          final clase = RegExp(
            'class $notifier extends[\\s\\S]*?\\n}',
          ).firstMatch(texto);
          cuerpo += clase?.group(0) ?? '';
        }
        if (!depende.hasMatch(cuerpo)) sinUsuario.add('${f.path}: $nombre');
      }
    }

    expect(sinUsuario, isEmpty, reason: sinUsuario.join('\n'));
  });
}
