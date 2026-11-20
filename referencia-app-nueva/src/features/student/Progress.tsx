import { useState } from 'react'
import { Link, useSearchParams } from 'react-router'
import { Screen } from '../../components/Layout'
import { Avatar, BeltBar, Card, EmptyState, ProgressBar, Title, cx } from '../../components/ui'
import { IconCheck, IconCircle, IconCrown } from '../../components/icons'
import { useAvatarUrls } from '../../lib/avatars'
import { BELT_COLOR, BELT_LABEL, MY_PROGRESS } from '../../lib/data'
import { WEEKDAY_LETTER, ymd } from '../../lib/dates'
import { initials } from '../../lib/logic'
import { countBetween, daysTrained, monthGrid, periodRange, samePointInPrev, weeklyTrend, type PeriodKind, type PeriodRange } from '../../lib/stats'
import { useApp } from '../../lib/store'
import { useAuth } from '../auth/AuthProvider'
import { useMyAvatar } from '../auth/useMyAvatar'
import { useMyStats, type MyStats } from './useMyStats'
import { useRanking, useRecentClasses, type RankRow } from './useRanking'

const MONTH_LETTERS = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D']
const MONTH_NAMES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)
const PERIODS: { id: PeriodKind; label: string }[] = [
  { id: 'week', label: 'Semana' },
  { id: 'month', label: 'Mes' },
  { id: 'year', label: 'Año' },
]
const clases = (n: number) => `${n} ${n === 1 ? 'clase' : 'clases'}`

/** Estadísticas: ranking de la sede y mi actividad, por semana, mes o año */
export function Progress() {
  const app = useApp()
  const [params, setParams] = useSearchParams()
  const tab = params.get('vista') === 'actividad' ? 'actividad' : 'ranking'
  const [kind, setKind] = useState<PeriodKind>('month')
  const range = periodRange(kind, app.now)

  return (
    <Screen top={24} gap={16}>
      <Title size={44}>Estadísticas</Title>

      <div role="tablist" aria-label="Vista" className="grid grid-cols-2 gap-1 rounded-[14px] bg-surface-2 p-1">
        {(['ranking', 'actividad'] as const).map((t) => (
          <button
            key={t}
            type="button"
            role="tab"
            aria-selected={tab === t}
            onClick={() => setParams(t === 'ranking' ? {} : { vista: t }, { replace: true })}
            className={cx('hy h-10 rounded-[10px] border-0 text-[15px]', tab === t ? 'bg-ink font-semibold text-on-ink' : 'bg-transparent font-medium text-ink-2')}
          >
            {t === 'ranking' ? 'Ranking' : 'Actividad'}
          </button>
        ))}
      </div>

      <div className="flex items-center justify-between gap-3">
        <div role="radiogroup" aria-label="Periodo" className="flex gap-2">
          {PERIODS.map((p) => (
            <button
              key={p.id}
              type="button"
              role="radio"
              aria-checked={kind === p.id}
              onClick={() => setKind(p.id)}
              className={cx('hy h-9 rounded-full border-0 px-4 text-[14px]', kind === p.id ? 'bg-accent font-semibold text-on-accent' : 'bg-surface-2 font-medium text-muted')}
            >
              {p.label}
            </button>
          ))}
        </div>
        <span className="truncate text-[13px] text-muted">{cap(range.label)}</span>
      </div>

      {tab === 'ranking' ? <RankingTab range={range} /> : <ActivityTab range={range} kind={kind} />}
    </Screen>
  )
}

// ---------------------------------------------------------------- Ranking

function RankingTab({ range }: { range: PeriodRange }) {
  const auth = useAuth()
  const { rows, error } = useRanking(range)
  const myAvatar = useMyAvatar()
  const urls = useAvatarUrls((rows ?? []).map((r) => r.avatarPath))
  const avatarOf = (r: RankRow) => (r.isMe ? myAvatar : r.avatarPath ? urls[r.avatarPath] ?? null : null)

  if (rows === null) return <p className="m-0 text-[14px] text-muted">Cargando ranking…</p>
  if (error) return <EmptyState title="No se pudo cargar el ranking" text="Comprueba la conexión y vuelve a intentarlo." />

  const me = rows.find((r) => r.isMe)
  const top = rows.filter((r) => !r.isMe || r.position <= 50)
  const podium = top.slice(0, 3)
  const rest = top.slice(3)
  const iAmHidden = auth.mode === 'live' && !me

  if (rows.length === 0) {
    return <EmptyState title="Aún no hay clases en este periodo" text="Cuando el gimnasio pase lista, aquí verás quién ha entrenado más." />
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Podio: 2.º · 1.º · 3.º */}
      <div className="grid grid-cols-3 items-end gap-2 pt-4">
        {[podium[1], podium[0], podium[2]].map((r, i) =>
          r ? (
            <div key={r.profileId} className="flex flex-col items-center gap-2">
              <div className="relative">
                {r.position === 1 && <IconCrown size={26} className="absolute -top-6 left-1/2 -translate-x-1/2 text-accent" />}
                <Avatar text={initials(r.name)} src={avatarOf(r)} size={i === 1 ? 76 : 60} tone="grey" className={cx(r.isMe && 'ring-2 ring-accent')} />
                <span
                  className={cx(
                    'absolute -bottom-2 left-1/2 flex h-6 min-w-6 -translate-x-1/2 items-center justify-center rounded-full px-1 text-[12px] font-bold',
                    r.position === 1 ? 'bg-accent text-on-accent' : 'bg-ink text-on-ink',
                  )}
                >
                  {r.position}
                </span>
              </div>
              <span className="mt-1 w-full truncate text-center text-[14px] font-semibold">{r.isMe ? 'Tú' : r.name.split(' ')[0]}</span>
              <div
                className={cx('flex w-full flex-col items-center justify-start rounded-t-[14px] pt-2', r.position === 1 ? 'bg-surface-2' : 'bg-surface')}
                style={{ height: i === 1 ? 72 : i === 0 ? 52 : 40 }}
              >
                <span className="text-[18px] font-bold leading-none">{r.classes}</span>
                <span className="text-[11px] text-muted">clases</span>
              </div>
            </div>
          ) : (
            <span key={`vacío${i}`} />
          ),
        )}
      </div>

      {rest.length > 0 && (
        <ol className="m-0 flex list-none flex-col rounded-[18px] bg-surface p-0 px-4 py-1">
          {rest.map((r) => (
            <RankLine key={r.profileId} r={r} avatar={avatarOf(r)} />
          ))}
        </ol>
      )}

      {/* Mi fila, fija abajo si no estoy en el podio */}
      {me && me.position > 3 && (
        <div className="sticky bottom-[84px] z-10 md:bottom-4">
          <div className="flex items-center gap-3 rounded-[16px] bg-accent px-4 py-3 text-on-accent shadow-lg">
            <span className="w-7 text-[15px] font-bold tabular-nums">{me.position}</span>
            <Avatar text={initials(me.name)} src={myAvatar} size={36} tone="ink" />
            <span className="flex-1 text-[15px] font-semibold">Tú</span>
            <span className="text-[15px] font-bold">{clases(me.classes)}</span>
          </div>
        </div>
      )}

      {iAmHidden && (
        <p className="m-0 rounded-[14px] bg-surface px-4 py-3 text-[13px] text-muted">
          No apareces en este ranking: o no tienes clases en este periodo o te has ocultado en{' '}
          <Link to="/ajustes" className="font-semibold text-ink">
            Ajustes de la app
          </Link>
          .
        </p>
      )}
      <p className="m-0 text-[12px] text-muted">Cuentan las clases con asistencia. Los menores no aparecen. Puedes ocultarte en Ajustes de la app → Privacidad.</p>
    </div>
  )
}

function RankLine({ r, avatar }: { r: RankRow; avatar: string | null }) {
  return (
    <li className={cx('flex min-h-[56px] items-center gap-3 border-b border-line py-2 last:border-0', r.isMe && 'font-semibold')}>
      <span className="w-7 text-[14px] font-bold tabular-nums text-muted">{r.position}</span>
      <Avatar text={initials(r.name)} src={avatar} size={36} tone="grey" />
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="truncate text-[15px] font-medium">{r.isMe ? 'Tú' : r.name}</span>
        {r.belt && (
          <span className="flex items-center gap-1 text-[12px] text-muted">
            <span aria-hidden="true" className="inline-block h-2 w-4 rounded-sm" style={{ background: BELT_COLOR[r.belt], boxShadow: 'inset 0 0 0 1px var(--border)' }} />
            {BELT_LABEL[r.belt]}
          </span>
        )}
      </span>
      <span className="text-[15px] font-semibold tabular-nums">{r.classes}</span>
    </li>
  )
}

// ---------------------------------------------------------------- Actividad

function ActivityTab({ range, kind }: { range: PeriodRange; kind: PeriodKind }) {
  const app = useApp()
  const stats = useMyStats()
  const recent = useRecentClasses()
  const now = app.now
  const count = countBetween(stats.days, range.from, range.to)
  const prevUntil = samePointInPrev(range, now)
  const partial = ymd(prevUntil) !== ymd(range.prevTo)
  const prev = countBetween(stats.days, range.prevFrom, prevUntil)
  const prevName = partial ? `${range.prevLabel} a estas alturas` : range.prevLabel
  const trained = daysTrained(stats.days, range.from, range.to)
  const diff = count - prev
  const trend = weeklyTrend(stats.days, now, 8)
  const maxTrend = Math.max(1, ...trend.map((w) => w.count))

  return (
    <div className="flex flex-col gap-4">
      {/* Resumen */}
      <div className="grid grid-cols-3 gap-2">
        <SummaryStat value={count} label={`clases ${kind === 'week' ? 'esta semana' : kind === 'month' ? 'este mes' : 'este año'}`} />
        <SummaryStat value={trained} label={trained === 1 ? 'día entrenado' : 'días entrenados'} />
        <SummaryStat value={stats.streak} label={stats.streak === 1 ? 'semana de racha' : 'semanas de racha'} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        {/* Rendimiento frente al periodo anterior */}
        <Card className="gap-3 p-4">
          <h2 className="m-0 text-[16px] font-bold">Rendimiento</h2>
          <p className="m-0 text-[14px] text-ink-2">
            {diff > 0 ? `${clases(diff)} más que ${prevName}` : diff < 0 ? `${clases(-diff)} menos que ${prevName}` : `Igual que ${prevName}`}
          </p>
          {[
            { label: cap(range.label), n: count, accent: true },
            { label: partial ? `${cap(range.prevLabel)} (hasta el ${prevUntil.getDate()}${kind === 'year' ? ` de ${MONTH_NAMES[prevUntil.getMonth()]}` : ''})` : cap(range.prevLabel), n: prev, accent: false },
          ].map((b) => (
            <div key={b.label} className="flex flex-col gap-1">
              <div className="flex justify-between text-[13px]">
                <span className="text-muted">{b.label}</span>
                <span className="font-semibold">{clases(b.n)}</span>
              </div>
              <ProgressBar value={(b.n / Math.max(1, count, prev)) * 100} height={10} accent={b.accent} label={`${b.label}: ${clases(b.n)}`} />
            </div>
          ))}
        </Card>

        {/* Tendencia por semanas */}
        <Card className="gap-3 p-4">
          <div className="flex items-baseline justify-between">
            <h2 className="m-0 text-[16px] font-bold">Tendencia</h2>
            <span className="text-[12px] text-muted">últimas 8 semanas</span>
          </div>
          <div className="flex h-24 items-end gap-2" role="img" aria-label={`Clases por semana: ${trend.map((w) => w.count).join(', ')}`}>
            {trend.map((w, i) => (
              <div key={ymd(w.monday)} className="flex h-full flex-1 flex-col items-center justify-end gap-1">
                <span className="text-[11px] font-semibold tabular-nums text-muted">{w.count || ''}</span>
                <span
                  className={cx('block w-full rounded', i === trend.length - 1 ? 'bg-accent' : 'bg-ink')}
                  style={{ height: w.count === 0 ? 3 : Math.max(6, Math.round((w.count / maxTrend) * 72)) }}
                />
              </div>
            ))}
          </div>
          <div aria-hidden="true" className="flex gap-2 text-center text-[10px] text-muted">
            {trend.map((w, i) => (
              <span key={ymd(w.monday)} className="flex-1">
                {i === trend.length - 1 ? 'Esta' : `${w.monday.getDate()}/${w.monday.getMonth() + 1}`}
              </span>
            ))}
          </div>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <BeltProgress stats={stats} />
        <MonthDetail stats={stats} />
      </div>

      {/* Actividad reciente */}
      <section aria-labelledby="reciente" className="flex flex-col gap-2">
        <h2 id="reciente" className="m-0 text-[16px] font-bold">
          Actividad reciente
        </h2>
        {recent === null ? (
          <p className="m-0 text-[14px] text-muted">Cargando…</p>
        ) : recent.length === 0 ? (
          <p className="m-0 text-[14px] text-muted">Aún no hay clases con asistencia.</p>
        ) : (
          <ul className="m-0 flex list-none flex-col rounded-[18px] bg-surface p-0 px-4 py-1">
            {recent.map((c) => (
              <li key={c.id} className="hy-text flex min-h-[52px] items-center justify-between gap-3 border-b border-line py-2 last:border-0">
                <span className="flex items-center gap-3">
                  <span className="flex h-8 w-8 items-center justify-center rounded-full bg-ok-bg text-ok-fg">
                    <IconCheck size={16} />
                  </span>
                  <span className="text-[15px] font-medium">{c.name}</span>
                </span>
                <span className="text-[13px] text-muted">
                  {c.at.toLocaleDateString('es-ES', { weekday: 'short', day: 'numeric', month: 'short' })}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  )
}

function SummaryStat({ value, label }: { value: number; label: string }) {
  return (
    <div className="flex flex-col gap-1 rounded-[18px] bg-surface p-4">
      <span className="text-[28px] font-bold leading-none tracking-[-0.02em]">{value}</span>
      <span className="text-[12px] text-muted">{label}</span>
    </div>
  )
}

/** Cinturón actual y progreso hacia el siguiente grado */
function BeltProgress({ stats }: { stats: MyStats }) {
  const app = useApp()
  const auth = useAuth()
  const { me, now } = app
  const live = auth.mode === 'live'
  const req = stats.required
  const missing = Math.max(0, req - stats.sinceRank)
  const monthsInRank = stats.rankSince
    ? Math.max(0, (now.getFullYear() - Number(stats.rankSince.slice(0, 4))) * 12 + now.getMonth() - (Number(stats.rankSince.slice(5, 7)) - 1))
    : MY_PROGRESS.monthsInRank
  const criteria = [
    { ok: monthsInRank >= MY_PROGRESS.monthsRequired, text: `Tiempo mínimo: ${monthsInRank} de ${MY_PROGRESS.monthsRequired} meses` },
    { ok: missing === 0, text: missing === 0 ? 'Clases: completadas' : `Clases: faltan ${missing}` },
    { ok: false, text: 'Visto bueno del profesor' },
  ]

  if (live && !auth.rank) {
    return (
      <Card radius={24} className="gap-2 p-5">
        <h2 className="m-0 text-[18px] font-bold">Cinturón sin indicar</h2>
        <p className="m-0 text-[14px] text-muted">Indica tu cinturón actual para ver tu progreso hacia el siguiente grado.</p>
        <Link to="/perfil/editar" className="self-start rounded-[12px] bg-ink px-4 py-3 text-[14px] font-semibold text-on-ink no-underline">
          Indicar mi cinturón
        </Link>
      </Card>
    )
  }

  return (
    <Card radius={24} className="gap-[14px] p-5">
      <BeltBar belt={me.belt} stripes={me.stripes} height={28} />
      <div className="flex flex-col gap-[2px]">
        <h2 className="m-0 text-[18px] font-bold">
          Cinturón {BELT_LABEL[me.belt].toLowerCase()} · {me.stripes} {me.stripes === 1 ? 'grado' : 'grados'}
        </h2>
        <Link to="/perfil/promociones" className="text-[13px] text-muted">
          {stats.rankSince
            ? `Desde el ${new Date(stats.rankSince + 'T12:00:00').toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })}`
            : `${BELT_LABEL[me.belt]} desde ${MY_PROGRESS.rankSince}`}
          {' · ver historial'}
        </Link>
      </div>
      <div className="flex flex-col gap-[6px]">
        <div className="flex justify-between text-[13px]">
          <span className="font-semibold">Hacia el siguiente grado</span>
          <span className="text-muted">
            {Math.min(stats.sinceRank, req)} de {req} clases
          </span>
        </div>
        <ProgressBar value={(stats.sinceRank / req) * 100} height={10} accent label={`${Math.round((Math.min(stats.sinceRank, req) / req) * 100)} por ciento de las clases`} />
      </div>
      <ul className="m-0 flex list-none flex-col gap-2 p-0 text-[13px]">
        {criteria.map((c) => (
          <li key={c.text} className="flex items-center gap-2">
            {c.ok ? (
              <span className="flex h-[18px] w-[18px] items-center justify-center rounded-full bg-ok-bg text-ok-fg">
                <IconCheck size={12} />
              </span>
            ) : (
              <IconCircle size={18} className="text-off" />
            )}
            <span>
              {c.text}
              <span className="sr-only">{c.ok ? ' (cumplido)' : ' (pendiente)'}</span>
            </span>
          </li>
        ))}
      </ul>
      <p className="m-0 text-[11px] text-muted">Objetivo orientativo hasta que el gimnasio fije sus reglas de graduación.</p>
    </Card>
  )
}

/** Clases por mes (pulsables) y el calendario del mes elegido */
function MonthDetail({ stats }: { stats: MyStats }) {
  const app = useApp()
  const current = app.now.getMonth()
  const [selected, setSelected] = useState(current)
  const max = Math.max(1, ...stats.monthly)
  const grid = monthGrid(stats.year, selected)
  const monthDays = grid.filter((d): d is Date => !!d)
  const attendedDays = monthDays.filter((d) => (stats.days[ymd(d)] ?? 0) > 0).length
  const todayKey = ymd(app.now)

  return (
    <Card className="gap-3 p-4">
      <div className="flex items-baseline justify-between gap-2">
        <h2 className="m-0 text-[16px] font-bold">Clases por mes</h2>
        <span className="text-[12px] text-muted">{stats.year}</span>
      </div>
      <div className="flex h-16 items-end gap-[6px]" role="group" aria-label="Clases por mes. Pulsa un mes para ver sus días">
        {stats.monthly.map((n, i) => {
          const future = i > current
          return (
            <button
              key={i}
              type="button"
              disabled={future}
              aria-pressed={i === selected}
              aria-label={`${cap(MONTH_NAMES[i])}: ${clases(n)}`}
              onClick={() => setSelected(i)}
              className="flex h-full flex-1 items-end border-0 bg-transparent p-0 disabled:cursor-default"
            >
              <span
                className={cx('block w-full rounded', future ? 'bg-avatar' : i === selected ? 'bg-accent' : 'bg-ink')}
                style={{ height: future || n === 0 ? 3 : Math.max(4, Math.round((n / max) * 64)) }}
              />
            </button>
          )
        })}
      </div>
      <div aria-hidden="true" className="flex gap-[6px] text-center text-[10px] text-muted">
        {MONTH_LETTERS.map((l, i) => (
          <span key={i} className={cx('flex-1', i === selected && 'font-bold text-ink')}>
            {l}
          </span>
        ))}
      </div>

      <div className="mt-1 flex items-baseline justify-between gap-2">
        <span className="text-[15px] font-semibold">{cap(MONTH_NAMES[selected])}</span>
        <span className="text-[13px] text-muted">
          {clases(stats.monthly[selected])} en {attendedDays} {attendedDays === 1 ? 'día' : 'días'}
        </span>
      </div>
      <div className="grid w-full max-w-[420px] grid-cols-7 gap-[6px] self-center">
        {[1, 2, 3, 4, 5, 6, 0].map((wd) => (
          <span key={wd} aria-hidden="true" className="text-center text-[11px] font-semibold text-muted">
            {WEEKDAY_LETTER[wd]}
          </span>
        ))}
        {grid.map((d, i) => {
          if (!d) return <span key={`x${i}`} />
          const key = ymd(d)
          const n = stats.days[key] ?? 0
          const future = key > todayKey
          return (
            <span
              key={key}
              aria-label={`${d.getDate()} de ${MONTH_NAMES[selected]}: ${future ? 'todavía no' : n === 0 ? 'sin clase' : clases(n)}`}
              className={cx(
                'relative flex aspect-square items-center justify-center rounded-xl text-[13px] font-semibold',
                n > 0 ? 'bg-ink text-on-ink' : future ? 'bg-transparent text-off' : 'bg-surface-2 text-muted',
                key === todayKey && 'ring-2 ring-accent ring-offset-1 ring-offset-surface',
              )}
            >
              {d.getDate()}
              {n > 1 && (
                <span className="absolute -top-1 -right-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-accent px-1 text-[10px] font-bold text-on-accent">
                  {n}
                </span>
              )}
            </span>
          )
        })}
      </div>
      {stats.loading && <p className="m-0 text-[12px] text-muted">Cargando tu asistencia…</p>}
    </Card>
  )
}
