// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ITACA';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionCreateAccount => 'Create account';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonEmpty => 'Nothing here yet.';

  @override
  String get errorNetwork =>
      'No internet connection. Check your connection and try again.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authEmailInvalid => 'Enter a valid email';

  @override
  String get authPasswordTooShort => 'At least 6 characters';

  @override
  String get registerName => 'First name';

  @override
  String get registerLastName => 'Last name';

  @override
  String get registerYourAcademy => 'Your academy';

  @override
  String get registerSelectAcademy => 'Select your academy.';

  @override
  String get registerAcademiesLoadError => 'Couldn\'t load academies.';

  @override
  String get registerOwnerCta => 'Own a gym? Register your academy';

  @override
  String get navHome => 'Home';

  @override
  String get navStats => 'Stats';

  @override
  String get navNews => 'News';

  @override
  String get navShop => 'Shop';

  @override
  String get navPricing => 'Pricing';

  @override
  String get navProfile => 'Profile';
}
