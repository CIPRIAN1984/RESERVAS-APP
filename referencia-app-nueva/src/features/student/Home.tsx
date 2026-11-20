import { useState } from 'react'
import { Link } from 'react-router'
import { Screen } from '../../components/Layout'
import { EmptyState, cx } from '../../components/ui'
import { IconBack, IconCalendar, IconChevron, IconPlay } from '../../components/icons'
import { addDays, startOfWeek, ymd } from '../../lib/dates'
import { planUsageText } from '../../lib/data'
import { monthGrid } from '../../lib/stats'
import { useApp } from '../../lib/store'
import { ClassCard } from './ClassCard'
import { useCheckIn } from './CheckIn'

const DAY_LABELS = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM']
const MONTHS = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const WEEKDAYS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

/**
 * Inicio: mes y semana (desplegable a mes completo) y las clases del día
 * elegido. Es también el horario: se reserva desde aquí.
 */
export function Home() {
  const app = useApp()
  const checkIn = useCheckIn()
  const todayKey = ymd(app.now)
  const [selected, setSelected] = useState(() => new Date(app.now.getFullYear(), app.now.getMonth(), app.now.getDate()))
  const [expanded, setExpanded] = useState(false)
  const [viewMonth, setViewMonth] = useState(() => new Date(app.now.getFullYear(), app.now.getMonth(), 1))
  const selKey = ymd(selected)
  const isToday = selKey === todayKey

  const monday = startOfWeek(selected)
  const week = Array.from({ length: 7 }, (_, i) => addDays(monday, i))
  const shownMonth = expanded ? viewMonth : selected
  const all = app.sessionsOn(selected)
  const sessions = isToday ? all.filter((s) => s.end > app.now) : all
  const ended = isToday ? all.length - sessions.length : 0
  // El horario se crea con tres meses (12 semanas) de antelación
  const beyond = selected > addDays(app.now, 84)
  const usage = planUsageText(app.planStatus)
  const noneLeft = !!app.planStatus?.limit && (app.planStatus.used ?? 0) >= app.planStatus.limit

  const pick = (d: Date) => {
    setSelected(new Date(d.getFullYear(), d.getMonth(), d.getDate()))
    setViewMonth(new Date(d.getFullYear(), d.getMonth(), 1))
  }

  const dayButton = (d: Date, compact = false) => {
    const k = ymd(d)
    const sel = k === selKey
    const past = k < todayKey
    const hasClasses = app.sessionsOn(d).some((s) => s.status !== 'cancelled')
    return (
      <button
        key={k}
        type="button"
        onClick={() => pick(d)}
        aria-pressed={sel}
        aria-label={`${cap(WEEKDAYS[d.getDay()])} ${d.getDate()} de ${MONTHS[d.getMonth()]}${k === todayKey ? ', hoy' : ''}${hasClasses ? '' : ', sin clases'}`}
        className={cx(
          'hy mx-auto flex items-center justify-center rounded-full border-0 text-[15px] tabular-nums',
          compact ? 'h-9 w-9' : 'h-9 w-9 md:h-10 md:w-10',
          sel ? 'bg-accent font-bold text-on-accent' : past ? 'bg-transparent text-off' : 'bg-transparent text-ink',
          !sel && k === todayKey && 'font-bold underline underline-offset-4',
          !sel && !hasClasses && !past && 'text-muted',
        )}
      >
        {d.getDate()}
      </button>
    )
  }

  return (
    <Screen top={24} gap={18}>
      <header className="flex items-center justify-between gap-2">
        <h1 className="m-0 min-w-0 truncate whitespace-nowrap text-[22px] font-bold tracking-[-0.02em]">
          {cap(MONTHS[shownMonth.getMonth()])} de {shownMonth.getFullYear()}
        </h1>
        <div className="flex shrink-0 items-center gap-1">
          {!isToday && (
            <button
              type="button"
              onClick={() => pick(app.now)}
              className="hy h-9 rounded-full border-0 bg-surface-2 px-3 text-[13px] font-semibold text-ink"
            >
              Hoy
            </button>
          )}
          <button
            type="button"
            aria-label={expanded ? 'Ver solo la semana' : 'Ver el mes completo'}
            aria-expanded={expanded}
            onClick={() => {
              setViewMonth(new Date(selected.getFullYear(), selected.getMonth(), 1))
              setExpanded((e) => !e)
            }}
            className={cx('hy -mr-1 flex h-10 w-10 items-center justify-center rounded-full border-0', expanded ? 'bg-surface-2 text-accent' : 'bg-transparent text-ink')}
          >
            <IconCalendar size={22} />
          </button>
        </div>
      </header>

      <div className="flex flex-col gap-1">
        {expanded && (
          <div className="mb-1 flex items-center justify-between">
            <button
              type="button"
              onClick={() => setViewMonth(new Date(viewMonth.getFullYear(), viewMonth.getMonth() - 1, 1))}
              className="hy -ml-2 flex h-9 items-center gap-1 rounded-full border-0 bg-transparent px-2 text-[14px] font-medium text-ink-2"
            >
              <IconBack size={16} /> {MONTHS[(viewMonth.getMonth() + 11) % 12]}
            </button>
            <button
              type="button"
              onClick={() => setViewMonth(new Date(viewMonth.getFullYear(), viewMonth.getMonth() + 1, 1))}
              className="hy -mr-2 flex h-9 items-center gap-1 rounded-full border-0 bg-transparent px-2 text-[14px] font-medium text-ink-2"
            >
              {MONTHS[(viewMonth.getMonth() + 1) % 12]} <IconChevron size={16} />
            </button>
          </div>
        )}
        <div className="grid grid-cols-7">
          {DAY_LABELS.map((l) => (
            <span key={l} aria-hidden="true" className="text-center font-mono text-[11px] text-muted">
              {l}
            </span>
          ))}
        </div>
        {expanded ? (
          <div className="grid grid-cols-7 gap-y-1">
            {monthGrid(viewMonth.getFullYear(), viewMonth.getMonth()).map((d, i) => (d ? dayButton(d, true) : <span key={`x${i}`} />))}
          </div>
        ) : (
          <div className="grid grid-cols-7">{week.map((d) => dayButton(d))}</div>
        )}
      </div>

      {usage && (
        <Link
          to="/tarifas"
          className={cx(
            'flex items-center justify-between gap-3 rounded-[14px] px-4 py-3 text-[14px] font-medium no-underline',
            noneLeft ? 'bg-warn-bg text-warn-fg' : 'bg-surface text-ink-2',
          )}
        >
          <span>
            {usage}
            {app.planStatus ? <span className="text-muted"> · {app.planStatus.planName}</span> : null}
          </span>
          <IconChevron size={16} className="shrink-0 text-muted" />
        </Link>
      )}

      <section className="flex flex-col gap-3" aria-labelledby="clases-titulo">
        <h2 id="clases-titulo" className="m-0 text-[18px] font-bold tracking-[-0.01em]">
          {isToday ? 'Próximas clases' : `Clases del ${WEEKDAYS[selected.getDay()]} ${selected.getDate()}`}
        </h2>

        {beyond ? (
          <EmptyState title="Todavía no hay horario" text="El horario se publica con tres meses de antelación." />
        ) : sessions.length === 0 ? (
          <EmptyState
            title={isToday && ended > 0 ? 'Por hoy ya está' : 'No hay clases este día'}
            text={isToday && ended > 0 ? `Hoy había ${ended} ${ended === 1 ? 'clase' : 'clases'}. Elige otro día para reservar.` : 'Elige otro día en el calendario.'}
          />
        ) : (
          <div className="grid gap-3 lg:grid-cols-2">
            {sessions.map((s) => (
              <ClassCard key={s.id} session={s} onCheckIn={checkIn.start} />
            ))}
          </div>
        )}
      </section>

      <Link to="/itaca" className="hy-text flex items-center gap-3 rounded-[18px] bg-surface p-4 text-ink no-underline">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-accent text-on-accent">
          <IconPlay size={20} />
        </span>
        <span className="flex flex-1 flex-col">
          <span className="text-[15px] font-semibold">ITACA+</span>
          <span className="text-[13px] text-muted">Vídeos de las clases y currículos</span>
        </span>
        <IconChevron size={18} className="text-muted" />
      </Link>

      {checkIn.element}
    </Screen>
  )
}
