import { describe, expect, it } from 'vitest'
import { MEMBERS, TEMPLATES } from './data'
import {
  bookSession,
  bookedCount,
  cancelBooking,
  checkInWindow,
  recordAttendance,
  sessionsForDate,
  waitlist,
  type BookContext,
} from './logic'
import type { Booking, Member, Session } from './types'

const friday = new Date(2026, 10, 13, 10, 0) // vie 13 nov 2026, 10:00
const gi = TEMPLATES.find((t) => t.id === 't-adv-gi-v')! // Avanzado Gi, viernes 18:30–20:00
const kids = TEMPLATES.find((t) => t.id === 't-kids710-v')!
const session = (cap = 2): Session => {
  const s = sessionsForDate(TEMPLATES, friday).find((x) => x.templateId === 't-adv-gi-v')!
  return { ...s, capacity: cap }
}
const adult = (id: string, extra: Partial<Member> = {}): Member => ({ id, name: id, belt: 'blanco', stripes: 0, plan: 'black', ...extra })

let n = 0
const ctx = (s: Session, member: Member, now = friday): BookContext => ({ session: s, template: gi, member, now, newId: () => `b${n++}` })

describe('sessionsForDate (generate_sessions)', () => {
  it('genera las clases del viernes del horario real, ordenadas por hora', () => {
    const ids = sessionsForDate(TEMPLATES, friday).map((s) => s.templateId)
    expect(ids).toEqual(['t-sparring', 't-kids710-v', 't-adv-gi-v'])
  })
  it('salta los días de cierre', () => {
    expect(sessionsForDate(TEMPLATES, friday, ['2026-11-13'])).toEqual([])
  })
  it('calcula el fin con la duración', () => {
    const s = session()
    expect(s.end.getTime() - s.start.getTime()).toBe(90 * 60000)
  })
})

describe('bookSession (book_session)', () => {
  it('da plaza mientras hay aforo y lista de espera al llenarse', () => {
    const s = session(2)
    let b: Booking[] = []
    const r1 = bookSession(b, ctx(s, adult('a')))
    b = r1.bookings
    const r2 = bookSession(b, ctx(s, adult('b')))
    b = r2.bookings
    const r3 = bookSession(b, ctx(s, adult('c')))
    expect(r1.ok && r1.status).toBe('booked')
    expect(r2.ok && r2.status).toBe('booked')
    expect(r3.ok && r3.status).toBe('waitlist')
    expect(r3.ok && r3.position).toBe(1)
  })

  it('dos reservas a la última plaza dan una plaza y una espera', () => {
    const s = session(1)
    const r1 = bookSession([], ctx(s, adult('a')))
    const r2 = bookSession(r1.bookings, ctx(s, adult('b')))
    expect(bookedCount(r2.bookings, s.id)).toBe(1)
    expect(waitlist(r2.bookings, s.id)).toHaveLength(1)
  })

  it('no duplica la reserva del mismo alumno', () => {
    const s = session()
    const r1 = bookSession([], ctx(s, adult('a')))
    const r2 = bookSession(r1.bookings, ctx(s, adult('a')))
    expect(r2.ok).toBe(false)
    expect(!r2.ok && r2.reason).toBe('already')
    expect(r2.bookings).toHaveLength(1)
  })

  it('bloquea con deuda, clase terminada o plan que no la incluye', () => {
    const s = session()
    expect(bookSession([], ctx(s, adult('a', { debt: true }))).ok).toBe(false)
    expect(bookSession([], ctx(s, adult('a'), new Date(2026, 10, 13, 23, 0))).ok).toBe(false)
    const kidSession = sessionsForDate(TEMPLATES, friday).find((x) => x.templateId === 't-kids710-v')!
    const r = bookSession([], { ...ctx(kidSession, adult('a')), template: kids })
    expect(!r.ok && r.reason).toBe('not_allowed')
  })
})

describe('cancelBooking (cancel_booking)', () => {
  it('al cancelar una plaza promueve al primero de la lista de espera', () => {
    const s = session(1)
    let b = bookSession([], ctx(s, adult('a'))).bookings
    b = bookSession(b, ctx(s, adult('b'), new Date(friday.getTime() + 1000))).bookings
    b = bookSession(b, ctx(s, adult('c'), new Date(friday.getTime() + 2000))).bookings
    const target = b.find((x) => x.profileId === 'a')!
    const r = cancelBooking(b, target.id, s, friday)
    expect(r.promotedProfileId).toBe('b')
    expect(r.late).toBe(false)
    expect(bookedCount(r.bookings, s.id)).toBe(1)
    expect(waitlist(r.bookings, s.id).map((x) => x.profileId)).toEqual(['c'])
  })

  it('marca la cancelación tardía dentro del plazo de 2 horas', () => {
    const s = session()
    const b = bookSession([], ctx(s, adult('a'))).bookings
    const r = cancelBooking(b, b[0].id, s, new Date(2026, 10, 13, 17, 0))
    expect(r.late).toBe(true)
  })

  it('salir de la lista de espera no promueve a nadie', () => {
    const s = session(1)
    let b = bookSession([], ctx(s, adult('a'))).bookings
    b = bookSession(b, ctx(s, adult('b'))).bookings
    const w = b.find((x) => x.profileId === 'b')!
    const r = cancelBooking(b, w.id, s, friday)
    expect(r.promotedProfileId).toBeUndefined()
    expect(bookedCount(r.bookings, s.id)).toBe(1)
  })
})

describe('check-in', () => {
  const s = session()
  it('abre 30 minutos antes y cierra 15 después del inicio', () => {
    expect(checkInWindow(s, new Date(2026, 10, 13, 17, 59))).toBe('too_early')
    expect(checkInWindow(s, new Date(2026, 10, 13, 18, 0))).toBe('open')
    expect(checkInWindow(s, new Date(2026, 10, 13, 18, 45))).toBe('open')
    expect(checkInWindow(s, new Date(2026, 10, 13, 18, 46))).toBe('too_late')
  })

  it('es idempotente: reenviar el mismo check-in no duplica', () => {
    const a = { sessionId: s.id, profileId: 'a', method: 'qr' as const, clientId: 'x1', at: 1 }
    let list = recordAttendance([], a)
    list = recordAttendance(list, a)
    list = recordAttendance(list, { ...a, clientId: 'x2' })
    expect(list).toHaveLength(1)
  })
})

describe('datos de ejemplo', () => {
  it('los nombres de alumnos no se repiten', () => {
    const names = MEMBERS.map((m) => m.name)
    expect(new Set(names).size).toBe(names.length)
  })
})
