import { useEffect, useState } from 'react'
import { useParams } from 'react-router'
import { ActionBar, Screen } from '../../components/Layout'
import { BackButton, Btn, Card, Chip, EmptyState, Eyebrow, ProgressBar, Row } from '../../components/ui'
import { IconQr } from '../../components/icons'
import { coachSubtitle, planSessions } from '../../lib/data'
import { hhmm, mediumDay } from '../../lib/dates'
import { cancelDeadline } from '../../lib/logic'
import { useApp } from '../../lib/store'
import { useCheckIn } from './CheckIn'
import { useBook, useSessionView } from './session'
import { Attendees } from './Attendees'

export function ClassDetail() {
  const { id = '' } = useParams()
  const app = useApp()
  const view = useSessionView()
  const book = useBook()
  const [training, setTraining] = useState(false)
  useEffect(() => {
    if (!training) return
    const t = setTimeout(() => setTraining(false), 1600)
    return () => clearTimeout(t)
  }, [training])
  const checkIn = useCheckIn()
  const s = app.sessionById(decodeURIComponent(id))

  if (!s) {
    return (
      <Screen>
        <BackButton label="Volver al inicio" to="/" />
        <EmptyState title="Clase no encontrada" text="Puede que el enlace sea de una semana que ya no está en el horario." />
      </Screen>
    )
  }

  const v = view(s)
  const cur = app.curriculumFor(s.templateId)
  const plan = app.myPlan
  const deadline = cancelDeadline(s)
  const note = app.state.sessionNotes[s.id]

  const chip = {
    booked: <Chip tone="ok">Reservada</Chip>,
    waitlist: <Chip tone="warn">En espera · puesto {v.position}</Chip>,
    full: <Chip tone="warn">Completa</Chip>,
    ended: <Chip tone="neutral">Terminada</Chip>,
    cancelled: <Chip tone="err">Cancelada</Chip>,
    restricted: <Chip tone="neutral">Solo plan infantil</Chip>,
    open: <Chip tone="surface">Plazas libres</Chip>,
  }[v.status]

  return (
    <>
      <Screen gap={16}>
        <div className="flex items-center justify-between">
          <BackButton label="Volver al horario" />
          {chip}
        </div>
        <div className="flex flex-col gap-[6px]">
          <Eyebrow>{v.t.level || { gi: 'BJJ Gi', nogi: 'No Gi', infantil: 'Infantil', mma: 'MMA', openmat: 'Tatami abierto' }[v.t.discipline]}</Eyebrow>
          <h1 className="m-0 text-[28px] font-bold leading-[1.1] tracking-[-0.02em] break-words">{v.t.name}</h1>
          <p className="m-0 text-[16px] text-ink-2">
            {mediumDay(s.start)} · {hhmm(s.start)} – {hhmm(s.end)}
          </p>
        </div>

        <Card radius={24} className="gap-3 px-5 py-[18px]">
          <div className="flex items-end justify-between">
            <div className="flex items-baseline gap-[6px]">
              <span className="font-display text-[44px] font-extrabold leading-none">{v.booked}</span>
              <span className="text-[16px] text-muted">de {s.capacity} plazas</span>
            </div>
            {app.scheduleSource === 'live' ? (
              <span className="flex items-center gap-[6px] text-[12px] font-semibold text-ok-fg">
                <span aria-hidden="true" className="h-2 w-2 rounded-full bg-ok-dot" />
                En vivo
              </span>
            ) : (
              v.waiting > 0 && <span className="text-[12px] font-semibold text-warn-text">{v.waiting} en espera</span>
            )}
          </div>
          <ProgressBar value={(v.booked / s.capacity) * 100} />
          <Attendees session={s} waiting={v.waiting} />
        </Card>

        <div className="flex flex-col">
          <Row label="Profesor" value={v.coach ? `${v.coach.name} · ${coachSubtitle(v.coach).toLowerCase()}` : v.coachLabel} />
          <Row label="Lugar" value={v.t.place} />
          <Row label="Tu tarifa" value={plan ? `${plan.name} · ${planSessions(plan)}` : 'Sin tarifa en la app'} last />
        </div>

        {(cur.curriculum || note) && (
          <Card className="gap-[6px] p-4">
            <Eyebrow>{note ? 'Qué se dio' : 'Qué se trabaja hoy'}</Eyebrow>
            <span className="text-[15px] font-semibold leading-[1.35]">{note ?? cur.unit}</span>
            {cur.curriculum && (
              <span className="text-[13px] text-muted">
                Semana {cur.week} de {cur.curriculum.weeks} del bloque de {cur.curriculum.name.toLowerCase()}
              </span>
            )}
          </Card>
        )}

        {s.status === 'cancelled' && (
          <p role="status" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">Clase cancelada{s.cancelReason ? `: ${s.cancelReason}` : ''}.</p>
        )}
        {v.status !== 'ended' && v.status !== 'cancelled' && (
          <p className="m-0 text-[13px] text-muted">Cancelación sin penalización hasta las {hhmm(deadline)}{deadline.toDateString() !== s.start.toDateString() ? ` del ${mediumDay(deadline)}` : ''}.</p>
        )}
      </Screen>

      {v.status !== 'ended' && v.status !== 'restricted' && v.status !== 'cancelled' && (
        <ActionBar>
          {training && (
            <Btn variant="highlight" size="lg" block className="itaca-train" aria-live="polite">
              ¡A entrenar!
            </Btn>
          )}
          {v.status === 'booked' && !training && (
            <>
              <Btn variant="accent" size="lg" block className="hover:bg-accent hover:text-on-accent" onClick={() => checkIn.start(s)}>
                <IconQr size={20} /> Check-in con QR
              </Btn>
              <Btn variant="coral" block onClick={() => app.cancel(s)}>
                Cancelar reserva
              </Btn>
            </>
          )}
          {v.status === 'waitlist' && (
            <Btn variant="outline" block onClick={() => app.cancel(s)}>
              Salir de la lista de espera
            </Btn>
          )}
          {v.status === 'open' && (
            <Btn
              variant="accent"
              size="lg"
              block
              className="hover:bg-accent hover:text-on-accent"
              disabled={!!book.busy}
              onClick={async () => {
                if ((await book(s)) === 'booked') setTraining(true)
              }}
            >
              {book.busy ? 'Reservando…' : 'Reservar plaza'}
            </Btn>
          )}
          {v.status === 'full' && (
            <Btn variant="ink" size="lg" block disabled={!!book.busy} onClick={() => book(s)}>
              {book.busy ? 'Apuntando…' : 'Apuntarme a la lista de espera'}
            </Btn>
          )}
        </ActionBar>
      )}
      {checkIn.element}
    </>
  )
}
