/**
 * Lectura del horario desde Supabase (paso 2) y conversión a los tipos que
 * usan las pantallas. Reservas, asistencia y cobros siguen siendo locales
 * hasta los pasos 3–6.
 */
import { COACHES } from './data'
import { ymd } from './dates'
import { isNetworkError, type QueuedOp, type SendResult } from './offlineQueue'
import { supabase } from './supabase'
import type { Booking, ClassTemplate, Coach, Discipline, Plan, PlanStatus, Session } from './types'

export interface DbDiscipline {
  id: string
  name: string
  kind: 'gi' | 'nogi' | 'kids' | 'openmat' | 'other'
  sort: number
}

export interface DbTemplate {
  id: string
  gym_id: string
  discipline_id: string
  name: string
  level: string
  weekdays: number[]
  start_time: string // "HH:MM:SS"
  duration_min: number
  capacity: number
  coach_profile_id: string | null
  place: string
  active: boolean
  /** Primer día (YYYY-MM-DD) */
  valid_from: string
  /** Último día; null = todos los meses, sin fecha de fin */
  valid_until: string | null
}

export interface DbClosure {
  id: string
  date_from: string
  date_to: string
  reason: string
}

export interface DbSession {
  id: string
  template_id: string | null
  discipline_id: string
  name: string
  level: string
  starts_at: string
  ends_at: string
  capacity: number
  coach_profile_id: string | null
  substitute_coach_profile_id: string | null
  place: string
  status: 'scheduled' | 'cancelled' | 'done'
  cancel_reason: string | null
  booked_count: number
  waitlist_count: number
}

export interface RemoteSchedule {
  gymId: string
  templates: ClassTemplate[]
  sessions: Session[]
  coaches: Coach[]
  /** Mis reservas activas (y las de mis menores) */
  myBookings: Booking[]
  myProfileId: string | null
  plans: Plan[]
}

const KIND_TO_DISCIPLINE: Record<DbDiscipline['kind'], Discipline> = {
  gi: 'gi',
  nogi: 'nogi',
  kids: 'infantil',
  openmat: 'openmat',
  other: 'gi',
}

function toTemplate(t: DbTemplate, disc: Map<string, DbDiscipline>): ClassTemplate {
  const kind = disc.get(t.discipline_id)?.kind ?? 'other'
  return {
    id: t.id,
    name: t.name,
    level: t.level,
    discipline: KIND_TO_DISCIPLINE[kind],
    weekdays: t.weekdays,
    start: t.start_time.slice(0, 5),
    durationMin: t.duration_min,
    capacity: t.capacity,
    coachId: t.coach_profile_id,
    place: t.place,
    kidsOnly: kind === 'kids',
    active: t.active,
  }
}

/** Plantilla sintética para una clase puntual (sin plantilla) */
function oneOffTemplate(s: DbSession, disc: Map<string, DbDiscipline>): ClassTemplate {
  const start = new Date(s.starts_at)
  const kind = disc.get(s.discipline_id)?.kind ?? 'other'
  return {
    id: `puntual:${s.id}`,
    name: s.name,
    level: s.level,
    discipline: KIND_TO_DISCIPLINE[kind],
    weekdays: [],
    start: `${String(start.getHours()).padStart(2, '0')}:${String(start.getMinutes()).padStart(2, '0')}`,
    durationMin: Math.round((new Date(s.ends_at).getTime() - start.getTime()) / 60000),
    capacity: s.capacity,
    coachId: s.coach_profile_id,
    place: s.place,
    kidsOnly: kind === 'kids',
  }
}

export async function loadSchedule(gymId: string, from: Date, to: Date): Promise<RemoteSchedule> {
  if (!supabase) throw new Error('Supabase no configurado')
  const [disc, tpl, ses, staff] = await Promise.all([
    supabase.from('disciplines').select('id, name, kind, sort').eq('gym_id', gymId),
    supabase.from('class_templates').select('*').eq('gym_id', gymId),
    supabase
      .from('class_sessions')
      .select('id, template_id, discipline_id, name, level, starts_at, ends_at, capacity, coach_profile_id, substitute_coach_profile_id, place, status, cancel_reason, booked_count, waitlist_count')
      .eq('gym_id', gymId)
      .gte('starts_at', from.toISOString())
      .lt('starts_at', to.toISOString())
      .order('starts_at'),
    supabase.from('staff_directory').select('profile_id, full_name, role').eq('gym_id', gymId).eq('teaches', true),
  ])
  for (const r of [disc, tpl, ses, staff]) if (r.error) throw r.error

  const dmap = new Map((disc.data as DbDiscipline[]).map((d) => [d.id, d]))
  const templates = (tpl.data as DbTemplate[]).map((t) => toTemplate(t, dmap))
  const tids = new Set(templates.map((t) => t.id))

  const sessions: Session[] = []
  for (const s of ses.data as DbSession[]) {
    let templateId = s.template_id
    if (!templateId || !tids.has(templateId)) {
      const one = oneOffTemplate(s, dmap)
      templates.push(one)
      tids.add(one.id)
      templateId = one.id
    }
    const start = new Date(s.starts_at)
    sessions.push({
      id: s.id,
      templateId,
      date: ymd(start),
      start,
      end: new Date(s.ends_at),
      capacity: s.capacity,
      coachId: s.substitute_coach_profile_id ?? s.coach_profile_id,
      status: s.status,
      cancelReason: s.cancel_reason ?? undefined,
      bookedCount: s.booked_count,
      waitlistCount: s.waitlist_count,
    })
  }

  // Cinturón y cargo vienen de los datos públicos de la web mientras no haya rangos (paso 5)
  const coaches: Coach[] = (staff.data as { profile_id: string; full_name: string }[]).map((c) => {
    const known = COACHES.find((k) => k.name.toLowerCase() === c.full_name.toLowerCase())
    return {
      id: c.profile_id,
      name: c.full_name,
      belt: known?.belt,
      title: known?.title,
      hoursThisMonth: 0,
      avgAttendance: 0,
      unregisteredSessions: 0,
    }
  })

  const [myBookings, myProfileId, plans] = await Promise.all([loadMyBookings(from, to), currentProfileId(), loadPlans(gymId)])
  return { gymId, templates, sessions, coaches, myBookings, myProfileId, plans }
}

export function sessionFromRow(s: Pick<DbSession, 'booked_count' | 'waitlist_count' | 'status' | 'cancel_reason'>) {
  return { bookedCount: s.booked_count, waitlistCount: s.waitlist_count, status: s.status, cancelReason: s.cancel_reason ?? undefined }
}

async function currentProfileId(): Promise<string | null> {
  const { data } = await supabase!.rpc('current_profile_id')
  return (data as string | null) ?? null
}

export async function loadMyBookings(from: Date, to: Date): Promise<Booking[]> {
  const { data, error } = await supabase!.rpc('my_bookings', { p_from: from.toISOString(), p_to: to.toISOString() })
  if (error) throw error
  return (data as { id: string; session_id: string; profile_id: string; status: 'booked' | 'waitlist'; late_cancel: boolean; waitlist_position: number | null; created_at: string }[]).map((b) => ({
    id: b.id,
    sessionId: b.session_id,
    profileId: b.profile_id,
    status: b.status,
    createdAt: new Date(b.created_at).getTime(),
    late: b.late_cancel,
    position: b.waitlist_position ?? undefined,
  }))
}

// ---------- Reservas (funciones del servidor) ----------

export type BookOutcome =
  | { ok: true; status: 'booked' | 'waitlist'; position?: number; already?: boolean }
  | { ok: false; reason: 'already' | 'ended' | 'not_allowed' | 'limit' | 'debt' | 'cancelled' | 'forbidden' | 'error'; message?: string }

export async function rpcBook(sessionId: string, profileId?: string): Promise<BookOutcome> {
  const { data, error } = await supabase!.rpc('book_session', { p_session: sessionId, ...(profileId ? { p_profile: profileId } : {}) })
  if (error) {
    const hint = (error.hint ?? '') as string
    if (hint === 'ended' || hint === 'not_allowed' || hint === 'cancelled') return { ok: false, reason: hint, message: error.message }
    if (hint === 'plan_limit' || hint === 'no_plan') return { ok: false, reason: 'limit', message: error.message }
    if (error.code === '42501') return { ok: false, reason: 'forbidden', message: error.message }
    return { ok: false, reason: 'error', message: error.message }
  }
  const r = data as { status: 'booked' | 'waitlist'; position: number | null; already: boolean }
  if (r.already) return { ok: false, reason: 'already' }
  return { ok: true, status: r.status, position: r.position ?? undefined }
}

export async function rpcCancel(bookingId: string): Promise<{ ok: boolean; late?: boolean; promoted?: boolean; wasWaitlist?: boolean; message?: string }> {
  const { data, error } = await supabase!.rpc('cancel_booking', { p_booking: bookingId })
  if (error) return { ok: false, message: error.message }
  const r = data as { late: boolean; promoted_profile_id: string | null }
  return { ok: true, late: r.late, promoted: !!r.promoted_profile_id }
}

/** Lista de la clase para el profesor (RLS: solo personal de la sede) */
export async function loadRoster(sessionId: string): Promise<{ profileId: string; name: string; birthDate: string | null; avatarPath: string | null }[]> {
  const { data, error } = await supabase!
    .from('bookings')
    .select('profile_id, created_at, profile:profiles(full_name, birth_date, avatar_path)')
    .eq('session_id', sessionId)
    .eq('status', 'booked')
    .order('created_at')
  if (error) throw error
  return (data ?? []).map((r) => {
    const p = (Array.isArray(r.profile) ? r.profile[0] : r.profile) as { full_name: string; birth_date: string | null; avatar_path: string | null } | null
    return { profileId: r.profile_id as string, name: p?.full_name ?? '—', birthDate: p?.birth_date ?? null, avatarPath: p?.avatar_path ?? null }
  })
}

/** Escucha cambios de ocupación de la sede y de mis reservas */
export function subscribeSchedule(gymId: string, onSession: (row: DbSession) => void, onMyBookings: () => void) {
  const ch = supabase!
    .channel(`horario-${gymId}`)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'class_sessions', filter: `gym_id=eq.${gymId}` }, (p) =>
      onSession(p.new as DbSession),
    )
    .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings', filter: `gym_id=eq.${gymId}` }, () => onMyBookings())
    .subscribe()
  return () => {
    void supabase!.removeChannel(ch)
  }
}

/** Quién va a una clase: nombre y foto (cualquier miembro de la sede) */
export async function loadAttendees(sessionId: string): Promise<{ profileId: string; name: string; avatarPath: string | null; isMe: boolean }[]> {
  const { data, error } = await supabase!.rpc('session_attendees', { p_session: sessionId })
  if (error) throw error
  return (data as { profile_id: string; display_name: string; avatar_path: string | null; is_me: boolean }[]).map((r) => ({
    profileId: r.profile_id,
    name: r.display_name,
    avatarPath: r.avatar_path,
    isMe: r.is_me,
  }))
}

/** Mi tarifa vigente (o la de un menor a mi cargo) y las clases usadas en el periodo */
export async function loadPlanStatus(profileId?: string): Promise<PlanStatus | null> {
  const { data, error } = await supabase!.rpc('my_plan_status', profileId ? { p_profile: profileId } : {})
  if (error) throw error
  const r = data as { plan: string | null; plan_id?: string; member_plan_id?: string; starts_on?: string; ends_on?: string | null; period?: PlanStatus['period']; limit?: number | null; used?: number | null }
  if (!r?.plan) return null
  return {
    memberPlanId: r.member_plan_id!,
    planId: r.plan_id!,
    planName: r.plan,
    startsOn: r.starts_on!,
    endsOn: r.ends_on ?? null,
    period: r.period ?? 'none',
    limit: r.limit ?? null,
    used: r.used ?? null,
  }
}

/** Catálogo de tarifas activas de la sede */
export async function loadPlans(gymId: string): Promise<Plan[]> {
  const { data, error } = await supabase!.from('plans').select('*').eq('gym_id', gymId).eq('active', true).order('sort')
  if (error) throw error
  return (data as {
    id: string; slug: string; name: string; description: string; kind: Plan['kind']; price_cents: number; billing_period: Plan['period']
    sessions: number | null; sessions_per_month: boolean; weekly_sessions: number | null; is_addon: boolean; validity_months: number | null; auto_renew: boolean; audience: Plan['audience']
  }[]).map((p) => ({
    id: p.slug,
    dbId: p.id,
    weeklySessions: p.weekly_sessions,
    isAddon: p.is_addon,
    name: p.name,
    description: p.description,
    kind: p.kind,
    priceCents: p.price_cents,
    period: p.billing_period,
    sessions: p.sessions,
    sessionsPerMonth: p.sessions_per_month,
    validityMonths: p.validity_months,
    autoRenew: p.auto_renew,
    audience: p.audience,
  }))
}

// ---------- Asistencia (paso 4) ----------

/** Envía una operación de la cola sin conexión al servidor */
export async function sendQueuedOp(op: QueuedOp): Promise<SendResult> {
  const call =
    op.kind === 'mark'
      ? supabase!.rpc('check_in', { p_session: op.sessionId, p_client_id: op.clientId, p_profile: op.profileId, p_method: op.method, p_at: op.at })
      : op.kind === 'unmark'
        ? supabase!.rpc('uncheck', { p_session: op.sessionId, p_profile: op.profileId, p_client_id: op.clientId })
        : supabase!.rpc('check_in_by_code', { p_code: op.code, p_client_id: op.clientId, p_at: op.at })
  try {
    const { error } = await call
    if (!error) return { status: 'ok' }
    return isNetworkError(error) ? { status: 'retry' } : { status: 'drop', message: error.message }
  } catch (e) {
    return isNetworkError(e) ? { status: 'retry' } : { status: 'drop', message: e instanceof Error ? e.message : 'Error' }
  }
}

export interface AttendeeRow {
  profileId: string
  name: string
  avatarPath: string | null
}

/** Asistencias activas de una sesión, con nombre (solo personal, por RLS) */
export async function loadSessionAttendance(sessionId: string): Promise<AttendeeRow[]> {
  const { data, error } = await supabase!
    .from('attendances')
    .select('profile_id, checked_in_at, profile:profiles(full_name, avatar_path)')
    .eq('session_id', sessionId)
    .is('voided_at', null)
    .order('checked_in_at')
  if (error) throw error
  return (data ?? []).map((r) => {
    const p = (Array.isArray(r.profile) ? r.profile[0] : r.profile) as { full_name: string; avatar_path: string | null } | null
    return { profileId: r.profile_id as string, name: p?.full_name ?? '—', avatarPath: p?.avatar_path ?? null }
  })
}

/** Avisa cuando cambian las asistencias de una sesión */
export function subscribeAttendance(sessionId: string, onChange: () => void) {
  const ch = supabase!
    .channel(`asistencia-${sessionId}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'attendances', filter: `session_id=eq.${sessionId}` }, () => onChange())
    .subscribe()
  return () => {
    void supabase!.removeChannel(ch)
  }
}

export async function gymCheckinCode(gymId: string): Promise<string | null> {
  const { data, error } = await supabase!.rpc('gym_checkin_code', { p_gym: gymId })
  if (error) throw error
  return (data as string | null) ?? null
}

export type CodeCheckIn =
  | { ok: true; sessionId: string; queued?: false }
  | { ok: true; queued: true }
  | { ok: false; message: string }

/** Check-in del alumno con el código del QR de la entrada */
export async function checkInByCode(code: string, clientId: string, at: string): Promise<CodeCheckIn | 'network'> {
  try {
    const { data, error } = await supabase!.rpc('check_in_by_code', { p_code: code, p_client_id: clientId, p_at: at })
    if (error) return isNetworkError(error) ? 'network' : { ok: false, message: error.message }
    return { ok: true, sessionId: (data as { session_id: string }).session_id }
  } catch (e) {
    return isNetworkError(e) ? 'network' : { ok: false, message: 'No se pudo fichar' }
  }
}
