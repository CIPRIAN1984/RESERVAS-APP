import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class PagosRepository {
  PagosRepository(this._client);

  final sb.SupabaseClient _client;

  /// Calls the `stripe-connect-onboarding` edge function and returns the
  /// Stripe-hosted onboarding URL to open externally. Throws
  /// `sb.FunctionException` on a non-2xx response (e.g. not a Dueño).
  Future<String> obtenerUrlOnboarding() async {
    final res = await _client.functions.invoke('stripe-connect-onboarding');
    final data = res.data as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Calls `stripe-connect-status` to refresh onboarding status immediately
  /// (rather than waiting for the webhook), returning the updated status.
  Future<({String estado, bool cobrosHabilitados})> refrescarEstado() async {
    final res = await _client.functions.invoke('stripe-connect-status');
    final data = res.data as Map<String, dynamic>;
    return (
      estado: data['stripe_onboarding_status'] as String,
      cobrosHabilitados: data['stripe_charges_enabled'] as bool,
    );
  }
}
