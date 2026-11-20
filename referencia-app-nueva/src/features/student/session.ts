import { useState } from 'react'
import { activeBookings, waitlist } from '../../lib/logic'
import { isKidsPlan } from '../../lib/data'
import { useApp } from '../../lib/store'
import type { Session } from '../../lib/types'

export type SessionStatus = 'cancelled' | 'ended' | 'restricted' | 'booked' | 'waitlist' | 'full' | 'open'

/** Lo que una pantalla necesita saber de una sesión para el alumno */
export function useSessionView() {
  const app = useApp()
  const live = app.scheduleSource === 'live'
  return (s: Session) => {
    const t = app.template(s.templateId)
    const { booked, waiting } = app.occupancy(s)
    const mine = app.myBooking(s.id)
    const coach = app.coachFor(s)
    // En modo real la edad la comprueba el servidor; aquí solo se avisa en las infantiles
    const restricted = live ? !!t.kidsOnly : (t.kidsOnly && !isKidsPlan(app.me.plan)) || (!t.kidsOnly && isKidsPlan(app.me.plan))
    let status: SessionStatus
    if (s.status === 'cancelled') status = 'cancelled'
    else if (s.end <= app.now) status = 'ended'
    else if (mine?.status === 'booked') status = 'booked'
    else if (mine?.status === 'waitlist') status = 'waitlist'
    else if (restricted) status = 'restricted'
    else if (booked >= s.capacity) status = 'full'
    else status = 'open'
    const position =
      mine?.status === 'waitlist'
        ? (mine.position ?? waitlist(app.state.bookings, s.id).findIndex((b) => b.id === mine.id) + 1)
        : 0
    return {
      t,
      title: t.level ? `${t.name} · ${t.level}` : t.name,
      booked,
      waiting,
      position,
      left: Math.max(0, s.capacity - booked),
      /** Asistentes conocidos (solo en modo demo: un alumno no ve las reservas de otros) */
      attendees: live ? [] : activeBookings(app.state.bookings, s.id).filter((b) => b.status === 'booked'),
      coach,
      coachLabel: coach ? `Prof. ${coach.name}` : t.discipline === 'openmat' ? 'Sin instructor' : 'Prof. por asignar',
      status,
      mine,
    }
  }
}

/** Reserva con mensajes para el alumno. `busy` evita dobles toques mientras responde el servidor. */
export function useBook() {
  const app = useApp()
  const [busy, setBusy] = useState<string | null>(null)
  /** Devuelve 'booked' si ha conseguido plaza (para la animación del botón) */
  const book = async (s: Session): Promise<'booked' | 'waitlist' | null> => {
    if (busy) return null
    setBusy(s.id)
    try {
      const r = await app.book(s)
      if (r.ok) {
        app.toast(r.status === 'booked' ? 'Plaza reservada' : `Estás en la lista de espera (puesto ${r.position ?? '—'})`)
        return r.status
      } else {
        const msg: Record<typeof r.reason, string> = {
          already: 'Ya tienes esta clase reservada',
          ended: 'Esta clase ya ha terminado',
          not_allowed: r.message ?? 'Esta clase no es para tu edad o tu tarifa',
          limit: r.message ?? 'No te quedan clases con tu tarifa. Pásate por recepción',
          debt: 'Tienes una cuota pendiente: habla con recepción para reservar',
          cancelled: 'La clase está cancelada',
          forbidden: 'No tienes permiso para reservar esta clase',
          error: 'No se pudo reservar. Comprueba la conexión y vuelve a intentarlo',
        }
        app.toast(msg[r.reason])
      }
      return null
    } finally {
      setBusy(null)
    }
  }
  return Object.assign(book, { busy })
}
