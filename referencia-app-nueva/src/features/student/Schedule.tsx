import { useState } from 'react'
import { useNavigate } from 'react-router'
import { Screen } from '../../components/Layout'
import { Btn, Chip, FilterChip, Title, cx } from '../../components/ui'
import { addDays, hhmm, monthYear, WEEKDAY_LETTER, weekdayName, ymd } from '../../lib/dates'
import { useApp } from '../../lib/store'
import type { Discipline, Session } from '../../lib/types'
import { useBook, useSessionView } from './session'
import { useAuth } from '../auth/AuthProvider'
import { DeleteSessionSheet, OneOffFromSchedule, SessionAdminSheet } from '../staff/SessionAdmin'
import { TrashButton } from '../staff/ScheduleEditor'
import { IconBack, IconCalendar, IconChevron, IconSettings } from '../../components/icons'
import { monthGrid } from '../../lib/stats'

const FILTERS: { id: 'all' | Discipline; label: string }[] = [
  { id: 'all', label: 'Todas' },
  { id: 'gi', label: 'Gi' },
  { id: 'nogi', label: 'No-Gi' },
  { id: 'infantil', label: 'Infantil' },
  { id: 'openmat', label: 'Open Mat' },
]

/** Horario semanal. En modo personal, tocar una clase abre su lista. */
export function Schedule({ staff }: { staff?: boolean }) {
  const app = useApp()
  const auth = useAuth()
  const nav = useNavigate()
  const canEdit = staff && auth.mode === 'live' && auth.memberships.some((m) => m.role === 'owner' || m.role === 'admin')
  const view = useSessionView()
  const book = useBook()
  const [weekOffset, setWeekOffset] = useState(0)
  const [selected, setSelected] = useState(() => ymd(app.now))
  const [filter, setFilter] = useState<'all' | Discipline>('all')
  const [managing, setManaging] = useState<Session | null>(null)
  const [deleting, setDeleting] = useState<Session | null>(null)
  const [oneOff, setOneOff] = useState(false)
  const [monthOpen, setMonthOpen] = useState(false)
  const [viewMonth, setViewMonth] = useState(() => new Date(app.now.getFullYear(), app.now.getMonth(), 1))
  // El horario llega a tres meses vista (12 semanas)
  const maxWeeks = staff ? 12 : 2

  // Siete días a partir de hoy, para que el domingo no muestre una semana ya pasada
  const today = new Date(app.now.getFullYear(), app.now.getMonth(), app.now.getDate())
  const first = addDays(today, weekOffset * 7)
  const days = Array.from({ length: 7 }, (_, i) => addDays(first, i))
  const selectedDate = days.find((d) => ymd(d) === selected) ?? days[0]
  const sessions = app
    .sessionsOn(selectedDate)
    .filter((s) => filter === 'all' || app.template(s.templateId).discipline === filter || false)

  const pickDay = (d: Date) => {
    const diff = Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() - today.getTime()) / 86400000)
    setWeekOffset(Math.max(0, Math.floor(diff / 7)))
    setSelected(ymd(d))
    setMonthOpen(false)
  }

  const changeWeek = (delta: number) => {
    const w = weekOffset + delta
    setWeekOffset(w)
    setSelected(ymd(addDays(app.now, w * 7)))
  }

  const open = (s: Session) => nav(staff ? `/staff?sesion=${encodeURIComponent(s.id)}` : `/clase/${encodeURIComponent(s.id)}`)

  return (
    <Screen top={60} gap={14}>
      <div className="flex items-end justify-between">
        <Title>Horario</Title>
        <div className="flex items-center gap-1 pb-1">
          <button aria-label="Semana anterior" disabled={weekOffset <= 0} onClick={() => changeWeek(-1)} className="hy h-11 w-9 border-0 bg-transparent text-[18px] text-ink disabled:opacity-30">
            ‹
          </button>
          <span className="whitespace-nowrap text-[14px] text-muted">{monthYear(selectedDate)}</span>
          <button aria-label="Semana siguiente" disabled={weekOffset >= maxWeeks} onClick={() => changeWeek(1)} className="hy h-11 w-9 border-0 bg-transparent text-[18px] text-ink disabled:opacity-30">
            ›
          </button>
          {staff && (
            <button
              type="button"
              aria-label={monthOpen ? 'Cerrar el mes' : 'Ver el mes completo'}
              aria-expanded={monthOpen}
              onClick={() => {
                setViewMonth(new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1))
                setMonthOpen((o) => !o)
              }}
              className={cx('hy ml-1 flex h-11 w-11 items-center justify-center rounded-full border-0', monthOpen ? 'bg-surface-2 text-accent' : 'bg-transparent text-ink')}
            >
              <IconCalendar size={22} />
            </button>
          )}
        </div>
      </div>

      {canEdit && (
        <div className="flex flex-wrap gap-2">
          <Btn size="sm" variant="accent" onClick={() => setOneOff(true)}>
            Añadir clase este día
          </Btn>
          <Btn size="sm" variant="outline" onClick={() => nav('/staff/horario/editor')}>
            Clases y cierres
          </Btn>
        </div>
      )}
      {app.scheduleError && (
        <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
          No se pudo cargar el horario del servidor. Se muestran datos de ejemplo.
        </p>
      )}

      {monthOpen && (
        <MonthPicker
          month={viewMonth}
          selected={selected}
          today={today}
          last={addDays(today, maxWeeks * 7 + 6)}
          hasClasses={(d) => app.sessionsOn(d).some((x) => x.status !== 'cancelled')}
          onMonth={setViewMonth}
          onPick={pickDay}
        />
      )}

      <div className="flex gap-[6px]">
        {days.map((d) => {
          const active = ymd(d) === ymd(selectedDate)
          const isToday = ymd(d) === ymd(app.now)
          return (
            <button
              key={ymd(d)}
              aria-label={`${weekdayName(d)} ${d.getDate()}${active ? ', seleccionado' : ''}`}
              aria-pressed={active}
              onClick={() => setSelected(ymd(d))}
              className={cx(
                'hy flex h-[60px] flex-1 flex-col items-center justify-center gap-[2px] rounded-2xl border-0',
                active ? 'bg-ink text-on-ink' : 'bg-surface text-ink',
              )}
            >
              <span className={cx('text-[11px]', active ? 'text-muted-on-ink' : 'text-muted')}>{WEEKDAY_LETTER[d.getDay()]}</span>
              <span className={cx('text-[16px]', active ? 'font-bold' : 'font-semibold', isToday && !active && 'underline underline-offset-4')}>{d.getDate()}</span>
            </button>
          )
        })}
      </div>

      <div className="no-scrollbar -mx-5 flex gap-2 overflow-x-auto px-5">
        {FILTERS.map((f) => (
          <FilterChip key={f.id} active={filter === f.id} onClick={() => setFilter(f.id)}>
            {f.label}
          </FilterChip>
        ))}
      </div>

      <div className="flex flex-col gap-[10px]">
        {sessions.length === 0 && <p className="m-0 py-6 text-center text-[14px] text-muted">No hay clases este día con este filtro.</p>}
        {sessions.map((s) => {
          const v = view(s)
          const highlight = !staff && v.status === 'booked'
          const sub =
            s.status === 'cancelled'
              ? s.cancelReason ?? 'Clase cancelada'
              : v.t.discipline === 'openmat'
              ? `${v.booked} de ${s.capacity} · Sin instructor`
              : v.status === 'full' && !staff
                ? null
                : `${v.booked} de ${s.capacity} · ${v.coachLabel}`
          return (
            <div
              key={s.id}
              className={cx(
                'flex items-center gap-3 rounded-[20px]',
                highlight ? 'border-2 border-ink bg-bg px-[14px] py-3' : 'bg-surface px-4 py-[14px]',
              )}
            >
              <button onClick={() => open(s)} className="flex min-w-0 flex-1 items-center gap-3 border-0 bg-transparent p-0 text-left text-ink">
                <span className="w-[66px] shrink-0 text-[22px] font-bold tabular-nums tracking-[-0.02em]">{hhmm(s.start)}</span>
                <span className="flex min-w-0 flex-1 flex-col gap-[2px]">
                  <span className="text-[15px] font-semibold leading-tight">{v.title}</span>
                  {sub ? (
                    <span className="truncate text-[13px] text-muted">{sub}</span>
                  ) : (
                    <span className="truncate text-[13px] text-warn-text">Completa · {v.waiting} en espera</span>
                  )}
                </span>
              </button>
              {staff ? (
                <span className="flex items-center gap-2">
                  <span className="text-[13px] text-muted">{v.booked} reservas{v.waiting ? ` · ${v.waiting} en espera` : ''}</span>
                  {canEdit && (
                    <button
                      type="button"
                      aria-label={`Gestionar ${v.title} de las ${hhmm(s.start)}`}
                      onClick={() => setManaging(s)}
                      className="hy flex h-10 w-10 items-center justify-center rounded-full border-0 bg-surface-2 text-ink"
                    >
                      <IconSettings size={18} />
                    </button>
                  )}
                  {canEdit && s.status !== 'cancelled' && s.end > app.now && <TrashButton label={`Eliminar ${v.title} de las ${hhmm(s.start)}`} onClick={() => setDeleting(s)} />}
                </span>
              ) : (
                <StatusAction status={v.status} position={v.position} busy={book.busy === s.id} onBook={() => book(s)} />
              )}
            </div>
          )
        })}
      </div>
      {managing && <SessionAdminSheet session={managing} onClose={() => setManaging(null)} />}
      {deleting && <DeleteSessionSheet session={deleting} onClose={() => setDeleting(null)} />}
      {oneOff && <OneOffFromSchedule date={ymd(selectedDate)} onClose={() => setOneOff(false)} />}
    </Screen>
  )
}

function StatusAction({ status, position, busy, onBook }: { status: string; position: number; busy: boolean; onBook: () => void }) {
  switch (status) {
    case 'cancelled':
      return <Chip tone="err">Cancelada</Chip>
    case 'ended':
      return <span className="text-[13px] text-muted">Terminada</span>
    case 'restricted':
      return <Chip tone="neutral">Solo plan infantil</Chip>
    case 'booked':
      return <Chip tone="ok">Reservada</Chip>
    case 'waitlist':
      return <Chip tone="warn">En espera · {position}</Chip>
    case 'full':
      return (
        <Btn size="sm" variant="outline" className="px-[14px] text-[13px]" disabled={busy} onClick={onBook}>
          En espera
        </Btn>
      )
    default:
      return (
        <Btn size="sm" variant="accent" className="px-[14px]" disabled={busy} onClick={onBook}>
          Reservar
        </Btn>
      )
  }
}

const MONTHS = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']

/** Mes completo para saltar a cualquier día (vista del personal) */
function MonthPicker({
  month,
  selected,
  today,
  last,
  hasClasses,
  onMonth,
  onPick,
}: {
  month: Date
  selected: string
  today: Date
  last: Date
  hasClasses: (d: Date) => boolean
  onMonth: (d: Date) => void
  onPick: (d: Date) => void
}) {
  const y = month.getFullYear()
  const m = month.getMonth()
  const canPrev = new Date(y, m, 1) > new Date(today.getFullYear(), today.getMonth(), 1)
  const canNext = new Date(y, m + 1, 1) <= last
  return (
    <div className="flex flex-col gap-2 rounded-[18px] bg-surface p-3">
      <div className="flex items-center justify-between">
        <button type="button" disabled={!canPrev} onClick={() => onMonth(new Date(y, m - 1, 1))} aria-label="Mes anterior" className="hy flex h-10 w-10 items-center justify-center rounded-full border-0 bg-transparent text-ink disabled:opacity-30">
          <IconBack size={18} />
        </button>
        <span className="text-[16px] font-bold">
          {MONTHS[m].charAt(0).toUpperCase() + MONTHS[m].slice(1)} de {y}
        </span>
        <button type="button" disabled={!canNext} onClick={() => onMonth(new Date(y, m + 1, 1))} aria-label="Mes siguiente" className="hy flex h-10 w-10 items-center justify-center rounded-full border-0 bg-transparent text-ink disabled:opacity-30">
          <IconChevron size={18} />
        </button>
      </div>
      <div className="grid grid-cols-7 gap-1">
        {['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((l) => (
          <span key={l} aria-hidden="true" className="text-center font-mono text-[11px] text-muted">
            {l}
          </span>
        ))}
        {monthGrid(y, m).map((d, i) => {
          if (!d) return <span key={`x${i}`} />
          const k = ymd(d)
          const out = d < today || d > last
          const sel = k === selected
          const has = !out && hasClasses(d)
          return (
            <button
              key={k}
              type="button"
              disabled={out}
              onClick={() => onPick(d)}
              aria-pressed={sel}
              aria-label={`${d.getDate()} de ${MONTHS[m]}${has ? '' : ', sin clases'}`}
              className={cx(
                'hy relative mx-auto flex h-10 w-10 items-center justify-center rounded-full border-0 text-[14px] tabular-nums',
                sel ? 'bg-accent font-bold text-on-accent' : out ? 'bg-transparent text-off' : 'bg-transparent text-ink',
                k === ymd(today) && !sel && 'font-bold underline underline-offset-4',
              )}
            >
              {d.getDate()}
              {has && !sel && <span aria-hidden="true" className="absolute bottom-1 h-1 w-1 rounded-full bg-muted" />}
            </button>
          )
        })}
      </div>
    </div>
  )
}
