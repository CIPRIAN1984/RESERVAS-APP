import { Link } from 'react-router'
import { Screen } from '../../components/Layout'
import { BackButton, Btn, Chip, EmptyState, Title } from '../../components/ui'
import { cancelDeadline } from '../../lib/logic'
import { hhmm, shortDay } from '../../lib/dates'
import { useApp } from '../../lib/store'

/** Mis reservas: próximas clases reservadas o en lista de espera */
export function MyBookings() {
  const app = useApp()
  const items = app.myUpcoming()

  return (
    <Screen gap={14}>
      <div className="flex items-center gap-3">
        <BackButton label="Volver" />
        <Title size={40}>Mis reservas</Title>
      </div>
      {items.length === 0 ? (
        <EmptyState
          title="No tienes reservas"
          text="Reserva desde el horario y aquí verás tus próximas clases."
          action={
            <Link to="/" className="inline-flex h-11 items-center rounded-[12px] bg-ink px-4 text-[14px] font-semibold text-on-ink no-underline">
              Ver horario
            </Link>
          }
        />
      ) : (
        <div className="flex flex-col gap-[10px]">
          {items.map(({ booking, session }) => {
            const t = app.template(session.templateId)
            const late = app.now > cancelDeadline(session) && booking.status === 'booked'
            return (
              <div key={booking.id} className="flex flex-col gap-3 rounded-[20px] bg-surface px-4 py-[14px]">
                <Link to={`/clase/${encodeURIComponent(session.id)}`} className="flex items-center gap-3 text-ink no-underline">
                  <span className="flex w-[64px] shrink-0 flex-col">
                    <span className="font-display text-[26px] font-bold leading-none">{hhmm(session.start)}</span>
                    <span className="whitespace-nowrap text-[11px] text-muted">{shortDay(session.start)}</span>
                  </span>
                  <span className="flex min-w-0 flex-1 flex-col gap-[2px]">
                    <span className="truncate text-[15px] font-semibold">{t.level ? `${t.name} · ${t.level}` : t.name}</span>
                    <span className="text-[13px] text-muted">{session.status === 'cancelled' ? session.cancelReason ?? 'Clase cancelada' : t.place}</span>
                  </span>
                  {session.status === 'cancelled' ? (
                    <Chip tone="err">Cancelada</Chip>
                  ) : booking.status === 'booked' ? (
                    <Chip tone="ok">Reservada</Chip>
                  ) : (
                    <Chip tone="warn">En espera · {booking.position ?? '—'}</Chip>
                  )}
                </Link>
                {session.status !== 'cancelled' && (
                  <div className="flex items-center justify-between gap-3">
                    <span className="text-[12px] text-muted">
                      {booking.status === 'waitlist'
                        ? 'Si alguien cancela, pasas a tener plaza'
                        : late
                          ? 'Fuera de plazo: cancelar contará como no presentado'
                          : `Sin penalización hasta las ${hhmm(cancelDeadline(session))}`}
                    </span>
                    <Btn size="sm" variant={booking.status === 'waitlist' ? 'outline' : 'coral'} onClick={() => app.cancel(session)}>
                      {booking.status === 'waitlist' ? 'Salir' : 'Cancelar'}
                    </Btn>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </Screen>
  )
}
