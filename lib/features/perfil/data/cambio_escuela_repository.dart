import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/academia.dart';
import 'solicitud_cambio_escuela.dart';

class CambioEscuelaRepository {
  CambioEscuelaRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<AcademiaOption>> listarAcademiasAprobadas() async {
    final rows = await _client.rpc('listar_academias_aprobadas') as List;
    return rows
        .map((r) => (id: r['id'] as String, nombre: r['nombre'] as String))
        .toList();
  }

  Future<void> crearSolicitud({required String alumnoId, required String academiaDestinoId}) async {
    await _client.from('solicitudes_cambio_escuela').insert({
      'alumno_id': alumnoId,
      'academia_destino_id': academiaDestinoId,
    });
  }

  Future<List<MiSolicitudCambio>> misSolicitudes() async {
    final rows = await _client.rpc('listar_mis_solicitudes_cambio') as List;
    return rows.map((r) => MiSolicitudCambio.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<SolicitudPendiente>> listarPendientes() async {
    final rows = await _client.rpc('listar_solicitudes_pendientes_destino') as List;
    return rows.map((r) => SolicitudPendiente.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> resolver({required String solicitudId, required bool aprobar}) async {
    await _client.rpc('resolver_cambio_escuela', params: {
      'p_solicitud_id': solicitudId,
      'p_aprobar': aprobar,
    });
  }
}
