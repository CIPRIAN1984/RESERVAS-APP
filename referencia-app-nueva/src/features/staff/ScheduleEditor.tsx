import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { useSearchParams } from 'react-router'
import { Screen } from '../../components/Layout'
import { BackButton, Btn, Chip, EmptyState, Eyebrow, FilterChip, Sheet, Title, cx } from '../../components/ui'
import { IconTrash } from '../../components/icons'
import { hhmm, mediumDay, parseYmd, ymd } from '../../lib/dates'
import type { DbClosure, DbDiscipline, DbTemplate } from '../../lib/remote'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../auth/AuthProvider'

const DAYS = [
  { n: 1, short: 'L', name: 'Lun' },
  { n: 2, short: 'M', name: 'Mar' },
  { n: 3, short: 'X', name: 'Mié' },
  { n: 4, short: 'J', name: 'Jue' },
  { n: 5, short: 'V', name: 'Vie' },
  { n: 6, short: 'S', name: 'Sáb' },
  { n: 7, short: 'D', name: 'Dom' },
]

type Draft = Omit<DbTemplate, 'id' | 'gym_id'> & { id?: string }

const endTime = (start: string, mins: number) => {
  const [h, m] = start.split(':').map(Number)
  const t = h * 60 + m + mins
  return `${String(Math.floor(t / 60) % 24).padStart(2, '0')}:${String(t % 60).padStart(2, '0')}`
}

const inputCls = 'h-12 w-full rounded-[14px] border-[1.5px] border-border bg-bg px-3 text-[15px] text-ink'
const labelCls = 'flex flex-col gap-1 text-[12px] font-semibold text-muted'

interface OneOffRow {
  id: string
  name: string
  level: string
  starts_at: string
  ends_at: string
  capacity: number
  booked_count: number
  coach_profile_id: string | null
  discipline_id: string
}

type ToDelete = { kind: 'template'; t: DbTemplate } | { kind: 'session'; s: OneOffRow }

const longDate = (s: string) => parseYmd(s).toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })

/** Clases (semanales y de un día) y cierres. Solo propietario y administración. */
export function ScheduleEditor() {
  const app = useApp()
  const auth = useAuth()
  const gymId = app.gymId
  const canEdit = auth.memberships.some((m) => m.gymId === gymId && (m.role === 'owner' || m.role === 'admin'))

  const [templates, setTemplates] = useState<DbTemplate[]>([])
  const [oneOffs, setOneOffs] = useState<OneOffRow[]>([])
  const [disciplines, setDisciplines] = useState<DbDiscipline[]>([])
  const [closures, setClosures] = useState<DbClosure[]>([])
  const [loading, setLoading] = useState(true)
  const [draft, setDraft] = useState<Draft | null>(null)
  const [closureOpen, setClosureOpen] = useState(false)
  const [toDelete, setToDelete] = useState<ToDelete | null>(null)
  // Filtros de la lista
  const [fDisc, setFDisc] = useState('')
  const [fDay, setFDay] = useState(0)
  const [fQ, setFQ] = useState('')
  const [params, setParams] = useSearchParams()

  const load = useCallback(async () => {
    if (!supabase || !gymId) return
    setLoading(true)
    const [t, d, c, o] = await Promise.all([
      supabase.from('class_templates').select('*').eq('gym_id', gymId),
      supabase.from('disciplines').select('id, name, kind, sort').eq('gym_id', gymId).order('sort'),
      supabase.from('closures').select('id, date_from, date_to, reason').eq('gym_id', gymId).gte('date_to', ymd(new Date())).order('date_from'),
      supabase
        .from('class_sessions')
        .select('id, name, level, starts_at, ends_at, capacity, booked_count, coach_profile_id, discipline_id')
        .eq('gym_id', gymId)
        .is('template_id', null)
        .eq('status', 'scheduled')
        .gt('ends_at', new Date().toISOString())
        .order('starts_at'),
    ])
    setTemplates(((t.data ?? []) as DbTemplate[]).sort((a, b) => a.weekdays[0] - b.weekdays[0] || a.start_time.localeCompare(b.start_time)))
    setDisciplines((d.data ?? []) as DbDiscipline[])
    setClosures((c.data ?? []) as DbClosure[])
    setOneOffs((o.data ?? []) as OneOffRow[])
    setLoading(false)
  }, [gymId])

  useEffect(() => {
    void load()
  }, [load])

  // Desde el horario: ?plantilla=<id> abre esa clase para editarla
  const wanted = params.get('plantilla')
  useEffect(() => {
    if (!wanted || loading) return
    const t = templates.find((x) => x.id === wanted)
    if (t) setDraft({ ...t })
    setParams({}, { replace: true })
  }, [wanted, loading, templates, setParams])

  if (auth.mode === 'demo' || !gymId) {
    return (
      <Screen>
        <BackButton label="Volver al horario" to="/staff/horario" />
        <EmptyState title="Editor no disponible en modo demo" text="El editor de horario guarda en el servidor. Arranca Supabase e inicia sesión como propietario o administración." />
      </Screen>
    )
  }
  if (!canEdit) {
    return (
      <Screen>
        <BackButton label="Volver al horario" to="/staff/horario" />
        <EmptyState title="Sin permiso" text="Solo propietario y administración pueden cambiar el horario." />
      </Screen>
    )
  }

  const after = async (msg: string) => {
    await Promise.all([load(), app.reloadSchedule()])
    app.toast(msg)
  }

  const newDraft = (): Draft => ({
    discipline_id: disciplines[0]?.id ?? '',
    name: '',
    level: '',
    weekdays: [],
    start_time: '19:00',
    duration_min: 60,
    capacity: 50,
    coach_profile_id: null,
    place: 'Tatami',
    active: true,
    valid_from: ymd(new Date()),
    valid_until: null,
  })

  const coachName = (id: string | null) => app.coaches.find((c) => c.id === id)?.name ?? 'profesor por asignar'
  const today = ymd(new Date())
  const nq = fQ.trim().toLowerCase()
  const matchText = (name: string, level: string, coachId: string | null) =>
    !nq || `${name} ${level} ${coachName(coachId)}`.toLowerCase().includes(nq)
  const weekly = templates
    .filter((t) => !t.valid_until || t.valid_until >= today)
    .filter((t) => (!fDisc || t.discipline_id === fDisc) && (!fDay || t.weekdays.includes(fDay)) && matchText(t.name, t.level, t.coach_profile_id))
  const isoDay = (iso: string) => ((new Date(iso).getDay() + 6) % 7) + 1
  const oneOffsShown = oneOffs.filter((s) => (!fDisc || s.discipline_id === fDisc) && (!fDay || isoDay(s.starts_at) === fDay) && matchText(s.name, s.level, s.coach_profile_id))
  const filtering = !!(fDisc || fDay || nq)

  return (
    <>
      <Screen gap={14}>
        <div className="flex items-center gap-3">
          <BackButton label="Volver al horario" to="/staff/horario" />
          <Title size={40}>Clases</Title>
        </div>
        <div className="flex flex-wrap gap-2">
          <Btn variant="accent" size="sm" onClick={() => setDraft(newDraft())}>
            Nueva clase
          </Btn>
          <Btn variant="outline" size="sm" onClick={() => setClosureOpen(true)}>
            Añadir festivo o cierre
          </Btn>
        </div>

        {closures.length > 0 && (
          <div className="flex flex-col gap-2">
            <Eyebrow>Próximos cierres</Eyebrow>
            {closures.map((c) => (
              <div key={c.id} className="flex items-center gap-3 rounded-2xl bg-err-bg px-4 py-3 text-err-fg">
                <div className="flex flex-1 flex-col">
                  <span className="text-[14px] font-semibold">{c.reason}</span>
                  <span className="text-[12px]">
                    {c.date_from === c.date_to ? mediumDay(parseYmd(c.date_from)) : `${mediumDay(parseYmd(c.date_from))} – ${mediumDay(parseYmd(c.date_to))}`}
                  </span>
                </div>
                <button
                  type="button"
                  aria-label={`Quitar el cierre ${c.reason}`}
                  onClick={async () => {
                    const { error } = await supabase!.from('closures').delete().eq('id', c.id)
                    if (error) app.toast('No se pudo quitar el cierre')
                    else await after('Cierre quitado: las clases de esos días vuelven al horario')
                  }}
                  className="flex h-11 w-11 items-center justify-center rounded-full border-0 bg-transparent text-err-fg"
                >
                  <IconTrash size={20} />
                </button>
              </div>
            ))}
          </div>
        )}

        <div className="flex flex-col gap-2 rounded-[18px] bg-surface p-3">
          <input
            type="search"
            aria-label="Buscar clase o profesor"
            placeholder="Buscar clase o profesor"
            value={fQ}
            onChange={(e) => setFQ(e.target.value)}
            className="h-11 rounded-[12px] border border-border bg-bg px-3 text-[15px] text-ink placeholder:text-muted"
          />
          <div className="no-scrollbar flex gap-2 overflow-x-auto">
            <FilterChip active={!fDisc} onClick={() => setFDisc('')}>
              Todas
            </FilterChip>
            {disciplines.map((d) => (
              <FilterChip key={d.id} active={fDisc === d.id} onClick={() => setFDisc(fDisc === d.id ? '' : d.id)}>
                {d.name}
              </FilterChip>
            ))}
          </div>
          <div className="flex gap-[6px]" role="group" aria-label="Día de la semana">
            {DAYS.map((d) => (
              <button
                key={d.n}
                type="button"
                aria-pressed={fDay === d.n}
                aria-label={d.name}
                onClick={() => setFDay(fDay === d.n ? 0 : d.n)}
                className={cx('hy h-10 flex-1 rounded-xl border-0 text-[14px] font-semibold', fDay === d.n ? 'bg-ink text-on-ink' : 'bg-surface-2 text-ink')}
              >
                {d.short}
              </button>
            ))}
          </div>
          {filtering && (
            <div className="flex items-center justify-between text-[13px] text-muted">
              <span>
                {weekly.length + oneOffsShown.length} {weekly.length + oneOffsShown.length === 1 ? 'clase' : 'clases'}
              </span>
              <button
                type="button"
                onClick={() => {
                  setFDisc('')
                  setFDay(0)
                  setFQ('')
                }}
                className="hy-text border-0 bg-transparent p-0 text-[13px] font-semibold text-ink underline"
              >
                Quitar filtros
              </button>
            </div>
          )}
        </div>

        <Eyebrow>Cada semana</Eyebrow>
        {loading && <p className="m-0 text-[14px] text-muted">Cargando…</p>}
        {!loading && weekly.length === 0 && <p className="m-0 text-[14px] text-muted">{filtering ? 'Ninguna clase semanal con estos filtros.' : 'Todavía no hay clases semanales.'}</p>}
        <div className="flex flex-col gap-2">
          {weekly.map((t) => {
            const start = t.start_time.slice(0, 5)
            const range = t.valid_until
              ? `${t.valid_from > today ? `del ${longDate(t.valid_from)} ` : ''}hasta el ${longDate(t.valid_until)}`
              : t.valid_from > today
                ? `desde el ${longDate(t.valid_from)}`
                : 'todos los meses'
            return (
              <div key={t.id} className={cx('flex items-center gap-2 rounded-2xl bg-surface pl-4 pr-2', !t.active && 'opacity-55')}>
                <button type="button" onClick={() => setDraft({ ...t })} className="flex min-w-0 flex-1 items-center gap-3 border-0 bg-transparent py-3 text-left text-ink">
                  <span className="flex w-[58px] shrink-0 flex-col">
                    <span className="text-[20px] font-bold leading-none tabular-nums">{start}</span>
                    <span className="text-[11px] text-muted">{endTime(start, t.duration_min)}</span>
                  </span>
                  <span className="flex min-w-0 flex-1 flex-col gap-[2px]">
                    <span className="truncate text-[15px] font-semibold">
                      {t.name}
                      {t.level ? ` · ${t.level}` : ''}
                    </span>
                    <span className="truncate text-[12px] text-muted">
                      {t.weekdays.map((d) => DAYS[d - 1].name).join(' · ')} · {range}
                    </span>
                    <span className="truncate text-[12px] text-muted">
                      {t.capacity} plazas · {coachName(t.coach_profile_id)}
                    </span>
                  </span>
                  {!t.active && <Chip tone="neutral">Pausada</Chip>}
                </button>
                <TrashButton label={`Eliminar ${t.name}`} onClick={() => setToDelete({ kind: 'template', t })} />
              </div>
            )
          })}
        </div>

        <Eyebrow>Solo un día</Eyebrow>
        {!loading && oneOffsShown.length === 0 && <p className="m-0 text-[14px] text-muted">{filtering ? 'Ninguna clase de un día con estos filtros.' : 'No hay clases sueltas próximas.'}</p>}
        <div className="flex flex-col gap-2">
          {oneOffsShown.map((s) => {
            const st = new Date(s.starts_at)
            const en = new Date(s.ends_at)
            return (
              <div key={s.id} className="flex items-center gap-2 rounded-2xl bg-surface pl-4 pr-2">
                <span className="flex min-w-0 flex-1 items-center gap-3 py-3">
                  <span className="flex w-[58px] shrink-0 flex-col">
                    <span className="text-[20px] font-bold leading-none tabular-nums">{hhmm(st)}</span>
                    <span className="text-[11px] text-muted">{hhmm(en)}</span>
                  </span>
                  <span className="flex min-w-0 flex-1 flex-col gap-[2px]">
                    <span className="truncate text-[15px] font-semibold">
                      {s.name}
                      {s.level ? ` · ${s.level}` : ''}
                    </span>
                    <span className="truncate text-[12px] text-muted">
                      {mediumDay(st)} · {s.booked_count} de {s.capacity} · {coachName(s.coach_profile_id)}
                    </span>
                  </span>
                </span>
                <TrashButton label={`Eliminar ${s.name} del ${mediumDay(st)}`} onClick={() => setToDelete({ kind: 'session', s })} />
              </div>
            )
          })}
        </div>
        <p className="m-0 text-[12px] text-muted">
          Las clases semanales se crean solas en el horario con tres meses de antelación. Para cambiar o cancelar solo un día, usa el engranaje en Horario.
        </p>
      </Screen>

      {draft && (
        <ClassSheet
          draft={draft}
          disciplines={disciplines}
          existing={templates}
          onClose={() => setDraft(null)}
          onSaved={async (msg) => {
            setDraft(null)
            await after(msg)
          }}
        />
      )}
      {toDelete && (
        <DeleteSheet
          item={toDelete}
          onClose={() => setToDelete(null)}
          onDone={async (msg) => {
            setToDelete(null)
            await after(msg)
          }}
        />
      )}
      <ClosureSheet
        open={closureOpen}
        gymId={gymId}
        onClose={() => setClosureOpen(false)}
        onSaved={async (msg) => {
          setClosureOpen(false)
          await after(msg)
        }}
      />
    </>
  )
}

export function TrashButton({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      aria-label={label}
      title="Eliminar"
      onClick={onClick}
      className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border-0 bg-transparent text-muted hover:bg-err-bg hover:text-err-fg"
    >
      <IconTrash size={20} />
    </button>
  )
}

function DeleteSheet({ item, onClose, onDone }: { item: ToDelete; onClose: () => void; onDone: (msg: string) => void }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const name = item.kind === 'template' ? item.t.name : item.s.name

  const go = async () => {
    setBusy(true)
    setError(null)
    if (item.kind === 'template') {
      const { data, error } = await supabase!.rpc('delete_class_template', { p_template: item.t.id })
      setBusy(false)
      if (error) return setError(error.message)
      const n = (data as { cancelled_sessions: number }).cancelled_sessions
      onDone(n ? `Clase eliminada. ${n} ${n === 1 ? 'día con reservas queda cancelado' : 'días con reservas quedan cancelados'}` : `"${name}" eliminada del horario`)
    } else {
      const { data, error } = await supabase!.rpc('delete_session', { p_session: item.s.id })
      setBusy(false)
      if (error) return setError(error.message)
      onDone(data === 'deleted' ? `"${name}" eliminada` : `"${name}" tenía reservas: queda cancelada para que los alumnos lo vean`)
    }
  }

  return (
    <Sheet open onClose={onClose} title="Eliminar clase">
      <p className="m-0 text-[15px]">
        {item.kind === 'template' ? (
          <>
            ¿Eliminar <b>{name}</b> de todas las semanas? Se quitan las próximas clases. Las que ya tienen reservas quedan canceladas para que los alumnos lo vean. El historial se conserva.
          </>
        ) : (
          <>
            ¿Eliminar <b>{name}</b> del {mediumDay(new Date(item.s.starts_at))}?
            {item.s.booked_count > 0 ? ` Tiene ${item.s.booked_count} ${item.s.booked_count === 1 ? 'reserva' : 'reservas'}: quedará cancelada para que lo vean.` : ''}
          </>
        )}
      </p>
      {error && (
        <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
          {error}
        </p>
      )}
      <div className="flex gap-2">
        <button type="button" disabled={busy} onClick={() => void go()} className="h-12 flex-1 rounded-[12px] border-0 bg-err-fg text-[15px] font-semibold text-bg disabled:opacity-50">
          {busy ? 'Eliminando…' : 'Eliminar'}
        </button>
        <Btn variant="soft" onClick={onClose}>
          Cancelar
        </Btn>
      </div>
    </Sheet>
  )
}

/** Nueva clase o editar una semanal: cada semana (todos los meses o hasta una fecha) o solo un día */
function ClassSheet({
  draft: initial,
  disciplines,
  existing,
  onClose,
  onSaved,
}: {
  draft: Draft
  disciplines: DbDiscipline[]
  existing: DbTemplate[]
  onClose: () => void
  onSaved: (msg: string) => void
}) {
  const app = useApp()
  const editing = !!initial.id
  const today = ymd(new Date())
  const [d, setD] = useState<Draft>(initial)
  const [repeat, setRepeat] = useState<'weekly' | 'once'>('weekly')
  const [onceDate, setOnceDate] = useState(today)
  const [forever, setForever] = useState(!initial.valid_until)
  const [error, setError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [dupOk, setDupOk] = useState(false)
  const set = <K extends keyof Draft>(k: K, v: Draft[K]) => setD((x) => ({ ...x, [k]: v }))

  // Otra clase semanal activa el mismo día y a la misma hora
  const dup =
    repeat === 'weekly'
      ? existing.find(
          (t) =>
            t.id !== d.id &&
            t.active &&
            (!t.valid_until || t.valid_until >= today) &&
            t.start_time.slice(0, 5) === d.start_time.slice(0, 5) &&
            t.weekdays.some((w) => d.weekdays.includes(w)),
        )
      : undefined

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!d.name.trim()) return setError('Falta el nombre de la clase')
    setError(null)
    if (dup && !dupOk) {
      setDupOk(true)
      return setError(
        `Ya hay "${dup.name}" los ${dup.weekdays.filter((w) => d.weekdays.includes(w)).map((n) => DAYS[n - 1].name).join(' y ')} a las ${dup.start_time.slice(0, 5)}. Si quieres cambiar esa clase, edítala en la lista. Para crear otra a la vez, pulsa de nuevo.`,
      )
    }

    if (repeat === 'once') {
      setSaving(true)
      const { error } = await supabase!.rpc('create_one_off_session', {
        p_gym: app.gymId,
        p_discipline: d.discipline_id,
        p_name: d.name.trim(),
        p_date: onceDate,
        p_start: d.start_time.slice(0, 5),
        p_duration_min: Number(d.duration_min),
        p_capacity: Number(d.capacity),
        p_level: d.level.trim(),
        p_coach: d.coach_profile_id || null,
        p_place: d.place.trim() || 'Tatami',
      })
      setSaving(false)
      if (error) return setError(error.code === '42501' ? 'No tienes permiso para cambiar el horario' : error.message)
      return onSaved(`Clase creada: ${d.name.trim()}, ${mediumDay(parseYmd(onceDate))} a las ${d.start_time.slice(0, 5)}`)
    }

    if (d.weekdays.length === 0) return setError('Elige al menos un día de la semana')
    if (!forever && !d.valid_until) return setError('Elige hasta qué día se repite')
    if (!forever && d.valid_until! < d.valid_from) return setError('La fecha de fin es anterior a la de inicio')
    setSaving(true)
    const row = {
      discipline_id: d.discipline_id,
      name: d.name.trim(),
      level: d.level.trim(),
      weekdays: [...d.weekdays].sort(),
      start_time: d.start_time.slice(0, 5),
      duration_min: Number(d.duration_min),
      capacity: Number(d.capacity),
      coach_profile_id: d.coach_profile_id || null,
      place: d.place.trim() || 'Tatami',
      active: d.active,
      valid_from: d.valid_from || today,
      valid_until: forever ? null : d.valid_until,
    }
    const res = editing ? await supabase!.from('class_templates').update(row).eq('id', d.id!) : await supabase!.from('class_templates').insert({ ...row, gym_id: app.gymId })
    setSaving(false)
    if (res.error) return setError(res.error.code === '42501' ? 'No tienes permiso para cambiar el horario' : `No se pudo guardar: ${res.error.message}`)
    onSaved(editing ? 'Clase actualizada en el horario' : `Clase creada: ${row.name}, ${row.weekdays.map((n) => DAYS[n - 1].name).join(' y ')} a las ${row.start_time}`)
  }

  return (
    <Sheet open onClose={onClose} title={editing ? 'Editar clase' : 'Nueva clase'}>
      <form onSubmit={submit} className="flex flex-col gap-3">
        {!editing && (
          <div role="radiogroup" aria-label="Cuándo" className="grid grid-cols-2 gap-1 rounded-[14px] bg-surface-2 p-1">
            {(
              [
                ['weekly', 'Cada semana'],
                ['once', 'Solo un día'],
              ] as const
            ).map(([k, label]) => (
              <button
                key={k}
                type="button"
                role="radio"
                aria-checked={repeat === k}
                onClick={() => setRepeat(k)}
                className={cx('hy h-10 rounded-[10px] border-0 text-[14px]', repeat === k ? 'bg-ink font-semibold text-on-ink' : 'bg-transparent font-medium text-ink-2')}
              >
                {label}
              </button>
            ))}
          </div>
        )}
        <label className={labelCls}>
          Nombre
          <input className={inputCls} value={d.name} onChange={(e) => set('name', e.target.value)} placeholder="Avanzados Gi" required />
        </label>
        <div className="grid grid-cols-2 gap-3">
          <label className={labelCls}>
            Disciplina
            <select className={inputCls} value={d.discipline_id} onChange={(e) => set('discipline_id', e.target.value)}>
              {disciplines.map((x) => (
                <option key={x.id} value={x.id}>
                  {x.name}
                </option>
              ))}
            </select>
          </label>
          <label className={labelCls}>
            Nivel o edad (opcional)
            <input className={inputCls} value={d.level} onChange={(e) => set('level', e.target.value)} placeholder="7 a 10 años" />
          </label>
        </div>

        {repeat === 'weekly' ? (
          <>
            <fieldset className="m-0 flex flex-col gap-1 border-0 p-0">
              <legend className="mb-1 text-[12px] font-semibold text-muted">Días de la semana</legend>
              <div className="flex gap-[6px]">
                {DAYS.map((day) => {
                  const on = d.weekdays.includes(day.n)
                  return (
                    <button
                      key={day.n}
                      type="button"
                      aria-pressed={on}
                      aria-label={day.name}
                      onClick={() => set('weekdays', on ? d.weekdays.filter((x) => x !== day.n) : [...d.weekdays, day.n])}
                      className={cx('hy h-11 flex-1 rounded-xl border-[1.5px] text-[14px] font-semibold', on ? 'border-ink bg-ink text-on-ink' : 'border-border bg-bg text-ink')}
                    >
                      {day.short}
                    </button>
                  )
                })}
              </div>
            </fieldset>
            <fieldset className="m-0 flex flex-col gap-2 border-0 p-0">
              <legend className="mb-1 text-[12px] font-semibold text-muted">¿Hasta cuándo?</legend>
              <div role="radiogroup" className="grid grid-cols-2 gap-2">
                {(
                  [
                    [true, 'Todos los meses'],
                    [false, 'Hasta una fecha'],
                  ] as const
                ).map(([v, label]) => (
                  <button
                    key={label}
                    type="button"
                    role="radio"
                    aria-checked={forever === v}
                    onClick={() => setForever(v)}
                    className={cx('hy h-11 rounded-xl border-[1.5px] text-[14px]', forever === v ? 'border-ink bg-ink font-semibold text-on-ink' : 'border-border bg-bg font-medium text-ink')}
                  >
                    {label}
                  </button>
                ))}
              </div>
              <div className="grid grid-cols-2 gap-3">
                <label className={labelCls}>
                  Empieza el
                  <input className={inputCls} type="date" value={d.valid_from} onChange={(e) => set('valid_from', e.target.value)} required />
                </label>
                {!forever && (
                  <label className={labelCls}>
                    Último día
                    <input className={inputCls} type="date" min={d.valid_from} value={d.valid_until ?? ''} onChange={(e) => set('valid_until', e.target.value || null)} required />
                  </label>
                )}
              </div>
            </fieldset>
          </>
        ) : (
          <label className={labelCls}>
            Día
            <input className={inputCls} type="date" min={today} value={onceDate} onChange={(e) => setOnceDate(e.target.value)} required />
          </label>
        )}

        <div className="grid grid-cols-3 gap-3">
          <label className={labelCls}>
            Hora
            <input className={inputCls} type="time" step={300} value={d.start_time.slice(0, 5)} onChange={(e) => set('start_time', e.target.value)} required />
          </label>
          <label className={labelCls}>
            Minutos
            <input className={inputCls} type="number" min={15} max={600} step={5} value={d.duration_min} onChange={(e) => set('duration_min', Number(e.target.value))} required />
          </label>
          <label className={labelCls}>
            Aforo
            <input className={inputCls} type="number" min={1} max={500} value={d.capacity} onChange={(e) => set('capacity', Number(e.target.value))} required />
          </label>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <label className={labelCls}>
            Profesor
            <select className={inputCls} value={d.coach_profile_id ?? ''} onChange={(e) => set('coach_profile_id', e.target.value || null)}>
              <option value="">Por asignar</option>
              {app.coaches.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <label className={labelCls}>
            Lugar
            <input className={inputCls} value={d.place} onChange={(e) => set('place', e.target.value)} />
          </label>
        </div>
        {editing && (
          <label className="flex min-h-11 items-center gap-3 text-[15px]">
            <input type="checkbox" className="h-5 w-5" checked={!d.active} onChange={(e) => set('active', !e.target.checked)} />
            Pausar la clase (desaparece del horario hasta que la reactives)
          </label>
        )}
        {error && (
          <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
            {error}
          </p>
        )}
        <Btn variant="accent" size="lg" block type="submit" disabled={saving}>
          {saving ? 'Guardando…' : dupOk && dup ? 'Crear otra clase a la misma hora' : editing ? 'Guardar cambios' : 'Crear clase'}
        </Btn>
      </form>
    </Sheet>
  )
}

/** Clase de un solo día (seminario, clase extra, recuperación…) */
export function OneOffSheet({
  gymId,
  disciplines,
  initialDate,
  onClose,
  onSaved,
}: {
  gymId: string
  disciplines: DbDiscipline[]
  initialDate?: string
  onClose: () => void
  onSaved: (msg: string) => void
}) {
  const app = useApp()
  const today = ymd(new Date())
  const [name, setName] = useState('')
  const [disc, setDisc] = useState(disciplines[0]?.id ?? '')
  const [date, setDate] = useState(initialDate && initialDate >= today ? initialDate : today)
  const [time, setTime] = useState('19:00')
  const [mins, setMins] = useState(60)
  const [cap, setCap] = useState(50)
  const [coach, setCoach] = useState('')
  const [place, setPlace] = useState('Tatami')
  const [level, setLevel] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!disc && disciplines[0]) setDisc(disciplines[0].id)
  }, [disc, disciplines])

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!name.trim()) return setError('Falta el nombre de la clase')
    setSaving(true)
    setError(null)
    const { error } = await supabase!.rpc('create_one_off_session', {
      p_gym: gymId,
      p_discipline: disc,
      p_name: name.trim(),
      p_date: date,
      p_start: time,
      p_duration_min: mins,
      p_capacity: cap,
      p_level: level.trim(),
      p_coach: coach || null,
      p_place: place.trim() || 'Tatami',
    })
    setSaving(false)
    if (error) return setError(error.code === '42501' ? 'No tienes permiso para cambiar el horario' : error.message)
    onSaved(`Clase puntual creada: ${name.trim()}, ${mediumDay(parseYmd(date))} a las ${time}`)
  }

  return (
    <Sheet open onClose={onClose} title="Clase puntual">
      <form onSubmit={submit} className="flex flex-col gap-3">
        <p className="m-0 text-[13px] text-muted">Solo ese día: un seminario, una clase extra o una recuperación.</p>
        <label className={labelCls}>
          Nombre
          <input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} placeholder="Seminario de guardia" required />
        </label>
        <div className="grid grid-cols-2 gap-3">
          <label className={labelCls}>
            Disciplina
            <select className={inputCls} value={disc} onChange={(e) => setDisc(e.target.value)}>
              {disciplines.map((x) => (
                <option key={x.id} value={x.id}>
                  {x.name}
                </option>
              ))}
            </select>
          </label>
          <label className={labelCls}>
            Nivel o edad (opcional)
            <input className={inputCls} value={level} onChange={(e) => setLevel(e.target.value)} />
          </label>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <label className={labelCls}>
            Día
            <input className={inputCls} type="date" min={today} value={date} onChange={(e) => setDate(e.target.value)} required />
          </label>
          <label className={labelCls}>
            Hora
            <input className={inputCls} type="time" step={300} value={time} onChange={(e) => setTime(e.target.value)} required />
          </label>
          <label className={labelCls}>
            Minutos
            <input className={inputCls} type="number" min={15} max={600} step={5} value={mins} onChange={(e) => setMins(Number(e.target.value))} required />
          </label>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <label className={labelCls}>
            Aforo
            <input className={inputCls} type="number" min={1} max={500} value={cap} onChange={(e) => setCap(Number(e.target.value))} required />
          </label>
          <label className={cx(labelCls, 'col-span-2')}>
            Profesor
            <select className={inputCls} value={coach} onChange={(e) => setCoach(e.target.value)}>
              <option value="">Por asignar</option>
              {app.coaches.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
        </div>
        <label className={labelCls}>
          Lugar
          <input className={inputCls} value={place} onChange={(e) => setPlace(e.target.value)} />
        </label>
        {error && (
          <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
            {error}
          </p>
        )}
        <Btn variant="accent" size="lg" block type="submit" disabled={saving}>
          {saving ? 'Creando…' : 'Crear clase'}
        </Btn>
      </form>
    </Sheet>
  )
}

function ClosureSheet({ open, gymId, onClose, onSaved }: { open: boolean; gymId: string; onClose: () => void; onSaved: (msg: string) => void }) {
  const today = ymd(new Date())
  const [from, setFrom] = useState(today)
  const [to, setTo] = useState(today)
  const [reason, setReason] = useState('')
  const [error, setError] = useState<string | null>(null)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (to < from) return setError('La fecha final es anterior a la inicial')
    const { error } = await supabase!.from('closures').insert({ gym_id: gymId, date_from: from, date_to: to, reason: reason.trim() || 'Cierre' })
    if (error) return setError(error.code === '42501' ? 'No tienes permiso para añadir cierres' : `No se pudo guardar: ${error.message}`)
    setReason('')
    setError(null)
    onSaved('Cierre añadido: se han cancelado las clases de esos días')
  }

  return (
    <Sheet open={open} onClose={onClose} title="Añadir cierre o festivo">
      <form onSubmit={submit} className="flex flex-col gap-3">
        <div className="grid grid-cols-2 gap-3">
          <label className={labelCls}>
            Desde
            <input className={inputCls} type="date" value={from} min={today} onChange={(e) => {
              setFrom(e.target.value)
              if (to < e.target.value) setTo(e.target.value)
            }} required />
          </label>
          <label className={labelCls}>
            Hasta
            <input className={inputCls} type="date" value={to} min={from} onChange={(e) => setTo(e.target.value)} required />
          </label>
        </div>
        <label className={labelCls}>
          Motivo
          <input className={inputCls} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Festivo de San Mateo" />
        </label>
        <p className="m-0 text-[13px] text-muted">Las clases de esos días se cancelan y los alumnos las verán como canceladas.</p>
        {error && (
          <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
            {error}
          </p>
        )}
        <Btn variant="accent" size="lg" block type="submit">
          Añadir cierre
        </Btn>
      </form>
    </Sheet>
  )
}

