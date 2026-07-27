import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y datos')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información de privacidad',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('Última actualización: 27 de julio de 2026'),
                  SizedBox(height: 24),
                  _PrivacySection(
                    title: 'Quién gestiona tus datos',
                    body:
                        'La academia en la que estás registrado gestiona los '
                        'datos de sus miembros mediante ITACA. Para ejercer '
                        'tus derechos o resolver una consulta, contacta con '
                        'la persona responsable de tu academia.',
                  ),
                  _PrivacySection(
                    title: 'Datos utilizados',
                    body:
                        'ITACA trata los datos necesarios para identificar tu '
                        'cuenta y operar la academia: perfil, rol, reservas, '
                        'asistencias, progreso, suscripciones, pedidos y, si '
                        'aceptas notificaciones, el identificador técnico del '
                        'dispositivo. Los pagos con tarjeta los procesa '
                        'Stripe; ITACA no almacena los datos completos de la '
                        'tarjeta.',
                  ),
                  _PrivacySection(
                    title: 'Finalidades',
                    body:
                        'Los datos se usan para prestar el servicio, controlar '
                        'el acceso según el rol, gestionar reservas y cobros, '
                        'enviar avisos solicitados, proteger las cuentas y '
                        'resolver incidencias. No se venden ni se usan para '
                        'publicidad personalizada.',
                  ),
                  _PrivacySection(
                    title: 'Proveedores',
                    body:
                        'La plataforma utiliza Supabase para autenticación, '
                        'base de datos y archivos; Stripe para pagos; Firebase '
                        'para notificaciones; Vercel para la aplicación web; y '
                        'Sentry, solo cuando está configurado, para errores '
                        'técnicos. Sentry recibe un identificador interno, no '
                        'el nombre ni el correo, y la captura de PII y de '
                        'pantallas está desactivada.',
                  ),
                  _PrivacySection(
                    title: 'Conservación y seguridad',
                    body:
                        'Los datos se conservan mientras la cuenta y la '
                        'relación con la academia estén activas, y después solo '
                        'durante los plazos legales o contractuales aplicables. '
                        'El acceso se limita por academia y rol. Las '
                        'credenciales y claves privadas no se incluyen en la '
                        'aplicación.',
                  ),
                  _PrivacySection(
                    title: 'Tus derechos',
                    body:
                        'Puedes solicitar acceso, rectificación, supresión, '
                        'portabilidad, limitación u oposición a través de tu '
                        'academia. Antes de entregar o eliminar información se '
                        'verificará tu identidad. Algunos registros de cobro '
                        'pueden conservarse cuando exista una obligación legal.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
