import { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { BrandMark } from '../../components/BrandMark'
import { Btn, Chip } from '../../components/ui'
import { IconPeople, IconPerson, IconQr, IconShareNodes } from '../../components/icons'
import { classTitle } from '../../lib/data'
import { hhmm, mediumDay } from '../../lib/dates'
import { checkInWindow } from '../../lib/logic'
import { useApp } from '../../lib/store'
import type { Session } from '../../lib/types'
import { useBook, useSessionView } from './session'

/** Logo del gimnasio en círculo (marca propia de ITACA) */
export function GymLogo({ size = 40 }: { size?: number }) {
  return (
    <span aria-hidden="true" className="flex shrink-0 items-center justify-center rounded-full bg-brand-black" style={{ width: size, height: size }}>
      <BrandMark size={Math.round(size * 0.66)} className="text-brand-cream" />
    </span>
  )
}

/** Compartir una clase: menú del sistema o copiar el enlace */
export function useShareClass() {
  const app = useApp()
  return async (s: Session) => {
    const t = app.template(s.templateId)
    const url = `${window.location.origin}/clase/${encodeURIComponent(s.id)}`
    const text = `${classTitle(t)} · ${mediumDay(s.start)} ${hhmm(s.start)}–${hhmm(s.end)} en ITACA Jiu Jitsu`
    try {
      if (navigator.share) {
        await navigator.share({ title: classTitle(t), text, url })
        return
      }
      await navigator.clipboard.writeText(`${text}\n${url}`)
      app.toast('Enlace de la clase copiado')
    } catch {
      /* compartir cancelado */
    }
  }
}

/**
 * Tarjeta de clase del Inicio: logo, nombre, hora, compartir, asistentes,
 * profesor y la acción que toque (reservar, check-in, lista de espera…).
 */
export function ClassCard({ session: s, onCheckIn }: { session: Session; onCheckIn: (s: Session) => void }) {
  const app = useApp()
  const view = useSessionView()
  const book = useBook()
  const share = useShareClass()
  const v = view(s)
  const checkInOpen = v.status === 'booked' && checkInWindow(s, app.now) === 'open'
  const busy = book.busy === s.id
  // Tras reservar: el botón pasa a amarillo con "¡A entrenar!" y después salen check-in y cancelar
  const [training, setTraining] = useState(false)
  useEffect(() => {
    if (!training) return
    const t = setTimeout(() => setTraining(false), 1600)
    return () => clearTimeout(t)
  }, [training])
  const reserve = async () => {
    if ((await book(s)) === 'booked') setTraining(true)
  }

  return (
    <article className="flex flex-col gap-4 rounded-[18px] bg-surface p-4">
      <div className="flex items-start gap-3">
        <Link to={`/clase/${encodeURIComponent(s.id)}`} className="flex min-w-0 flex-1 items-center gap-3 text-ink no-underline">
          <GymLogo />
          <span className="flex min-w-0 flex-col">
            <span className="truncate text-[16px] font-bold tracking-[-0.01em]">{classTitle(v.t)}</span>
            <span className="text-[14px] text-ink-2">
              {hhmm(s.start)} – {hhmm(s.end)}
            </span>
          </span>
        </Link>
        <div className="flex items-center gap-1">
          {v.status === 'booked' && <Chip tone="ok" small>Reservada</Chip>}
          {v.status === 'waitlist' && <Chip tone="warn" small>En espera · {v.position}</Chip>}
          {v.status === 'cancelled' && <Chip tone="err" small>Cancelada</Chip>}
          <button
            type="button"
            aria-label={`Compartir ${classTitle(v.t)}`}
            onClick={() => void share(s)}
            className="hy -mr-2 -mt-1 flex h-10 w-10 items-center justify-center rounded-full border-0 bg-transparent text-ink-2"
          >
            <IconShareNodes size={20} />
          </button>
        </div>
      </div>

      <div className="flex items-center gap-4 text-[14px] text-ink-2">
        <span className="flex min-w-0 flex-1 items-center gap-2">
          <IconPeople size={18} />
          <span className="truncate">
            {v.booked}/{s.capacity} asistentes{v.waiting > 0 ? ` · ${v.waiting} en espera` : ''}
          </span>
        </span>
        <span className="flex min-w-0 items-center gap-2">
          <IconPerson size={18} />
          <span className="truncate">{v.coach ? v.coach.name : v.t.discipline === 'openmat' ? 'Sin entrenador' : 'Por asignar'}</span>
        </span>
      </div>

      {s.status === 'cancelled' ? (
        <p className="m-0 text-[13px] text-err-fg">{s.cancelReason ?? 'Clase cancelada'}</p>
      ) : v.status === 'ended' ? (
        <Btn variant="soft" block disabled>
          Clase terminada
        </Btn>
      ) : v.status === 'restricted' ? (
        <Btn variant="soft" block disabled>
          Clase infantil
        </Btn>
      ) : training ? (
        <Btn variant="highlight" block className="itaca-train" aria-live="polite">
          ¡A entrenar!
        </Btn>
      ) : v.status === 'booked' ? (
        <div className="itaca-fade-in flex gap-2">
          {checkInOpen ? (
            <Btn block className="hover:bg-accent hover:text-on-accent" onClick={() => onCheckIn(s)}>
              <IconQr size={18} /> Check-in
            </Btn>
          ) : (
            <Btn variant="soft" block className="hover:bg-accent hover:text-on-accent" onClick={() => onCheckIn(s)}>
              <IconQr size={18} /> Check-in
            </Btn>
          )}
          <Btn variant="coral" className="shrink-0" onClick={() => void app.cancel(s)}>
            Cancelar
          </Btn>
        </div>
      ) : v.status === 'waitlist' ? (
        <Btn variant="outline" block onClick={() => void app.cancel(s)}>
          Salir de la lista de espera
        </Btn>
      ) : v.status === 'full' ? (
        <Btn variant="soft" block disabled={busy} onClick={() => void book(s)}>
          {busy ? 'Apuntando…' : 'Unirme a la lista de espera'}
        </Btn>
      ) : (
        <Btn block disabled={busy} className="hover:bg-accent hover:text-on-accent" onClick={() => void reserve()}>
          {busy ? 'Reservando…' : 'Reservar clase'}
        </Btn>
      )}
    </article>
  )
}
