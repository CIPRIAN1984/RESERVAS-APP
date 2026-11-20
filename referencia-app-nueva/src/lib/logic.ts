/**
 * Reglas de negocio puras (sin React ni almacenamiento).
 *
 * En producción estas reglas viven en funciones SQL transaccionales
 * (`book_session`, `cancel_booking`, `check_in`, `generate_sessions`):
 * "la base de datos manda". Aquí se implementan igual para el prototipo
 * y sirven de especificación ejecutable para esas funciones.
 */
import { GYM, isKidsPlan } from './data'
import { addDays, atTime, isoWeekday, ymd } from './dates'
import type { Attendance, Booking, ClassTemplate, Member, Session } from './types'

// ---------- Sesiones ----------

export function sessionId(templateId: string, date: string): string {
  return `${templateId}@${date}`
}

/** Equivale a `generate_sessions`: crea las sesiones de un día a partir de las plantillas */
export function sessionsForDate(templates: ClassTemplate[], date: Date, closures: string[] = []): Session[] {
  const day = ymd(date)
  if (closures.includes(day)) return []
  const wd = isoWeekday(date)
  return templates
    .filter((t) => t.weekdays.includes(wd))
    .map((t) => {
      const start = atTime(day, t.start)
      return {
        id: sessionId(t.id, day),
        templateId: t.id,
        date: day,
        start,
        end: new Date(start.getTime() + t.durationMin * 60000),
        capacity: t.capacity,
        coachId: t.coachId,
      }
    })
    .sort((a, b) => a.start.getTime() - b.start.getTime())
}

export function sessionsForRange(templates: ClassTemplate[], from: Date, days: number, closures: string[] = []): Session[] {
  const out: Session[] = []
  for (let i = 0; i < days; i++) out.push(...sessionsForDate(templates, addDays(from, i), closures))
  return out
}

export function parseSessionId(id: string): { templateId: string; date: string } {
  const [templateId, date] = id.split('@')
  return { templateId, date }
}

// ---------- Reservas ----------

export function activeBookings(bookings: Booking[], sid: string): Booking[] {
  return bookings.filter((b) => b.sessionId === sid && b.status !== 'cancelled')
}

export function bookedCount(bookings: Booking[], sid: string): number {
  return bookings.filter((b) => b.sessionId === sid && b.status === 'booked').length
}

/** Lista de espera ordenada por llegada */
export function waitlist(bookings: Booking[], sid: string): Booking[] {
  return bookings
    .filter((b) => b.sessionId === sid && b.status === 'waitlist')
    .sort((a, b) => a.createdAt - b.createdAt)
}

export function findBooking(bookings: Booking[], sid: string, profileId: string): Booking | undefined {
  return bookings.find((b) => b.sessionId === sid && b.profileId === profileId && b.status !== 'cancelled')
}

export type BookResult =
  | { ok: true; status: 'booked' | 'waitlist'; position?: number; bookings: Booking[] }
  | { ok: false; reason: 'already' | 'ended' | 'not_allowed' | 'debt'; bookings: Booking[] }

export interface BookContext {
  session: Session
  template: ClassTemplate
  member: Member
  now: Date
  newId: () => string
}

/** Equivale a `book_session`: valida plan, deuda y aforo; devuelve plaza o puesto en espera */
export function bookSession(bookings: Booking[], ctx: BookContext): BookResult {
  const { session, template, member, now } = ctx
  if (findBooking(bookings, session.id, member.id)) return { ok: false, reason: 'already', bookings }
  if (session.end.getTime() <= now.getTime()) return { ok: false, reason: 'ended', bookings }
  if (template.kidsOnly && !isKidsPlan(member.plan)) return { ok: false, reason: 'not_allowed', bookings }
  if (!template.kidsOnly && isKidsPlan(member.plan)) return { ok: false, reason: 'not_allowed', bookings }
  if (member.debt) return { ok: false, reason: 'debt', bookings }

  const full = bookedCount(bookings, session.id) >= session.capacity
  const booking: Booking = {
    id: ctx.newId(),
    sessionId: session.id,
    profileId: member.id,
    status: full ? 'waitlist' : 'booked',
    createdAt: now.getTime(),
  }
  const next = [...bookings, booking]
  if (full) return { ok: true, status: 'waitlist', position: waitlist(next, session.id).length, bookings: next }
  return { ok: true, status: 'booked', bookings: next }
}

export interface CancelResult {
  bookings: Booking[]
  late: boolean
  promotedProfileId?: string
}

export function cancelDeadline(session: Session): Date {
  return new Date(session.start.getTime() - GYM.cancelWindowHours * 3600000)
}

/** Equivale a `cancel_booking`: aplica el plazo y promueve al primero de la lista de espera */
export function cancelBooking(bookings: Booking[], bookingId: string, session: Session, now: Date): CancelResult {
  const target = bookings.find((b) => b.id === bookingId)
  if (!target || target.status === 'cancelled') return { bookings, late: false }
  const late = target.status === 'booked' && now.getTime() > cancelDeadline(session).getTime()
  let next = bookings.map((b) => (b.id === bookingId ? { ...b, status: 'cancelled' as const, late } : b))

  let promotedProfileId: string | undefined
  if (target.status === 'booked' && bookedCount(next, session.id) < session.capacity) {
    const first = waitlist(next, session.id)[0]
    if (first) {
      promotedProfileId = first.profileId
      next = next.map((b) => (b.id === first.id ? { ...b, status: 'booked' as const } : b))
    }
  }
  return { bookings: next, late, promotedProfileId }
}

// ---------- Check-in y asistencia ----------

export type CheckInWindow = 'open' | 'too_early' | 'too_late'

export function checkInWindow(session: Session, now: Date): CheckInWindow {
  const opens = checkInOpensAt(session).getTime()
  const closes = session.start.getTime() + GYM.checkInAfterMin * 60000
  if (now.getTime() < opens) return 'too_early'
  if (now.getTime() > closes) return 'too_late'
  return 'open'
}

export function checkInOpensAt(session: Session): Date {
  return new Date(session.start.getTime() - GYM.checkInBeforeMin * 60000)
}

/** Equivale a `check_in`: idempotente por (sesión, alumno) y por clientId */
export function recordAttendance(list: Attendance[], a: Attendance): Attendance[] {
  const dup = list.some(
    (x) => x.clientId === a.clientId || (x.sessionId === a.sessionId && x.profileId === a.profileId),
  )
  return dup ? list : [...list, a]
}

export function removeAttendance(list: Attendance[], sessionId: string, profileId: string): Attendance[] {
  return list.filter((x) => !(x.sessionId === sessionId && x.profileId === profileId))
}

export function isPresent(list: Attendance[], sessionId: string, profileId: string): boolean {
  return list.some((x) => x.sessionId === sessionId && x.profileId === profileId)
}

// ---------- Datos de ejemplo deterministas ----------

/** Hash estable para generar ocupaciones de ejemplo reproducibles */
export function hash(s: string): number {
  let h = 2166136261
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

/**
 * Reservas de ejemplo de otros alumnos para una sesión.
 * La clase de MMA sale completa con dos en espera, como en el diseño.
 */
export function seedBookingsFor(session: Session, template: ClassTemplate, members: Member[], meId: string): Booking[] {
  const pool = members.filter(
    (m) => m.id !== meId && (template.kidsOnly ? isKidsPlan(m.plan) : !isKidsPlan(m.plan)),
  )
  const h = hash(session.id)
  let booked: number
  let waiting = 0
  if (template.name === 'Avanzados No Gi') {
    // Una clase llena con lista de espera, para ver ese estado
    booked = session.capacity
    waiting = 2
  } else if (template.discipline === 'openmat') {
    booked = 3 + (h % 5)
  } else {
    booked = Math.min(session.capacity - 3, 8 + (h % 14))
  }
  const total = Math.min(pool.length, booked + waiting)
  const start = h % pool.length
  const out: Booking[] = []
  for (let i = 0; i < total; i++) {
    const m = pool[(start + i) % pool.length]
    out.push({
      id: `seed-${session.id}-${m.id}`,
      sessionId: session.id,
      profileId: m.id,
      status: i < booked ? 'booked' : 'waitlist',
      // Las reservas de ejemplo son anteriores a cualquier acción del usuario
      createdAt: i,
    })
  }
  return out
}

export function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]!.toUpperCase())
    .join('')
}

export function euros(n: number): string {
  return `${n.toLocaleString('es-ES', { maximumFractionDigits: 1, useGrouping: 'always' } as Intl.NumberFormatOptions)} €`
}
