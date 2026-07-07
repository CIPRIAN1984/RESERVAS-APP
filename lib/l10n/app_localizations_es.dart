// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'ITACA';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionCreateAccount => 'Crear cuenta';

  @override
  String get commonRequired => 'Obligatorio';

  @override
  String get commonLoading => 'Cargando…';

  @override
  String get commonEmpty => 'No hay nada por aquí todavía.';

  @override
  String get errorNetwork =>
      'Sin conexión a internet. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get errorGeneric => 'Ha ocurrido un error. Inténtalo de nuevo.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authEmailInvalid => 'Introduce un email válido';

  @override
  String get authPasswordTooShort => 'Mínimo 6 caracteres';

  @override
  String get registerName => 'Nombre';

  @override
  String get registerLastName => 'Apellidos';

  @override
  String get registerYourAcademy => 'Tu academia';

  @override
  String get registerSelectAcademy => 'Selecciona tu academia.';

  @override
  String get registerAcademiesLoadError =>
      'No se pudieron cargar las academias.';

  @override
  String get registerOwnerCta =>
      '¿Eres dueño de un gimnasio? Registra tu academia';

  @override
  String get navHome => 'Inicio';

  @override
  String get navStats => 'Estadísticas';

  @override
  String get navNews => 'Novedades';

  @override
  String get navProgress => 'Progreso';

  @override
  String get navShop => 'Tienda';

  @override
  String get navPricing => 'Tarifas';

  @override
  String get navProfile => 'Perfil';
}
