import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { useSearchParams } from 'react-router'
import { Screen } from '../../components/Layout'
import { Avatar, BeltBar, Btn, Chip, FilterChip, Sheet, Title, cx } from '../../components/ui'
import { useAvatarUrls } from '../../lib/avatars'
import { BELT_LABEL, BELTS, PLANS, planSessions, planUsageText } from '../../lib/data'
import { ymd } from '../../lib/dates'
import { initials } from '../../lib/logic'
import { useApp } from '../../lib/store'
import { loadPlanStatus } from '../../lib/remote'
import { ROLE_LABEL, supabase, type GymRole } from '../../lib/supabase'
import type { Belt } from '../../lib/types'
import { useAuth } from '../auth/AuthProvider'

const norm = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

interface RosterRow {
  profile_id: string
  full_name: string
  avatar_path: string | null
  role: GymRole
  status: 'active' | 'inactive'
  birth_date: string | null
  has_account: boolean
  belt: Belt | null
  stripes: number | null
  promoted_at: string | null
  self_declared: boolean | null
  attended_30d: number
}

type F = 'todos' | 'pendientes' | 'solicitudes' | 'alumnos' | 'personal' | 'sin-cinturon'

interface PlanRequestRow {
  id: string
  profile_id: string
  full_name: string
  plan_id: string
  plan_name: string
  created_at: string
}

/** Alumnos: con servidor, la lista real con su cinturón; en demo, datos de ejemplo */
export function Members() {
  const auth = useAuth()
  return auth.mode === 'live' ? <LiveMembers /> : <DemoMembers />
}

function LiveMembers() {
  const app = useApp()
  const auth = useAuth()
  const [rows, setRows] = useState<RosterRow[] | null>(null)
  const [q, setQ] = useState('')
  const [f, setF] = useState<F>('todos')
  const [open, setOpen] = useState<RosterRow | null>(null)
  const canPromote = auth.memberships.some((m) => m.gymId === app.gymId && ['owner', 'admin', 'coach'].includes(m.role))
  const canActivate = auth.memberships.some((m) => m.gymId === app.gymId && ['owner', 'admin', 'front_desk'].includes(m.role))

  const [requests, setRequests] = useState<PlanRequestRow[]>([])
  // Tarifa actual de cada persona (solo recepción y administración la ven)
  const [plans, setPlans] = useState<Map<string, { name: string | null; ends: string | null; plus: boolean }>>(new Map())
  const [planFilter, setPlanFilter] = useState('')
  const load = useCallback(async () => {
    if (!supabase || !app.gymId) return
    const [{ data, error }, reqs, ov] = await Promise.all([
      supabase.rpc('gym_roster', { p_gym: app.gymId }),
      supabase.rpc('pending_plan_requests', { p_gym: app.gymId }),
      supabase.rpc('staff_plan_overview', { p_gym: app.gymId }),
    ])
    setRows(error ? [] : ((data ?? []) as RosterRow[]))
    setRequests((reqs.data ?? []) as PlanRequestRow[])
    type O = { profile_id: string; plan_name: string | null; ends_on: string | null; has_plus: boolean }
    setPlans(new Map(((ov.data ?? []) as O[]).map((o) => [o.profile_id, { name: o.plan_name, ends: o.ends_on, plus: o.has_plus }])))
  }, [app.gymId])
  const planNames = [...new Set([...plans.values()].map((p) => p.name).filter((n): n is string => !!n))].sort()
  const requestFor = (profileId: string) => requests.find((r) => r.profile_id === profileId)
  useEffect(() => {
    void load()
  }, [load])

  // Desde Tarifas: ?alumno=<id> abre su ficha
  const [params, setParams] = useSearchParams()
  const wanted = params.get('alumno')
  useEffect(() => {
    if (!wanted || !rows) return
    const r = rows.find((x) => x.profile_id === wanted)
    if (r) setOpen(r)
    setParams({}, { replace: true })
  }, [wanted, rows, setParams])

  const urls = useAvatarUrls((rows ?? []).map((r) => r.avatar_path))
  const list = (rows ?? [])
    .filter((r) => !q || norm(r.full_name).includes(norm(q)))
    .filter(
      (r) =>
        f === 'todos' ||
        (f === 'pendientes' && r.status === 'inactive' && r.full_name !== 'Usuario eliminado') ||
        (f === 'solicitudes' && !!requestFor(r.profile_id)) ||
        (f === 'alumnos' && r.role === 'member') ||
        (f === 'personal' && r.role !== 'member') ||
        (f === 'sin-cinturon' && (!r.belt || r.self_declared)),
    )
    .filter((r) => !planFilter || (planFilter === '__sin' ? !plans.get(r.profile_id)?.name : planFilter === '__plus' ? !!plans.get(r.profile_id)?.plus : plans.get(r.profile_id)?.name === planFilter))

  return (
    <Screen gap={12}>
      <Title>Alumnos</Title>
      <p className="m-0 text-[14px] text-muted">
        {rows === null ? 'Cargando…' : `${rows.filter((r) => r.role === 'member').length} alumnos · ${rows.filter((r) => r.role !== 'member').length} del personal`}
      </p>
      {(() => {
        const n = (rows ?? []).filter((r) => r.status === 'inactive' && r.full_name !== 'Usuario eliminado').length
        return n > 0 && f !== 'pendientes' ? (
          <button
            type="button"
            onClick={() => setF('pendientes')}
            className="flex items-center justify-between rounded-[14px] border-0 bg-warn-bg px-4 py-3 text-left text-[14px] font-medium text-warn-fg"
          >
            {n === 1 ? '1 cuenta nueva pendiente de activar' : `${n} cuentas nuevas pendientes de activar`}
            <span className="font-semibold underline underline-offset-4">Ver</span>
          </button>
        ) : null
      })()}
      {requests.length > 0 && f !== 'solicitudes' && canActivate && (
        <button
          type="button"
          onClick={() => setF('solicitudes')}
          className="hy flex items-center justify-between rounded-[14px] border-0 bg-surface-2 px-4 py-3 text-left text-[14px] font-medium text-ink"
        >
          {requests.length === 1 ? `${requests[0].full_name.split(' ')[0]} ha pedido ${requests[0].plan_name}` : `${requests.length} solicitudes de tarifa`}
          <span className="font-semibold underline underline-offset-4">Ver</span>
        </button>
      )}
      <input
        type="search"
        aria-label="Buscar alumno"
        placeholder="Buscar alumno"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        className="h-[46px] rounded-[14px] border-[1.5px] border-border bg-bg px-[14px] text-[15px] text-ink placeholder:text-muted"
      />
      <div className="no-scrollbar -mx-5 flex gap-2 overflow-x-auto px-5">
        {(
          [
            ['todos', 'Todos'],
            ['pendientes', 'Pendientes'],
            ['solicitudes', 'Solicitudes'],
            ['alumnos', 'Alumnos'],
            ['personal', 'Personal'],
            ['sin-cinturon', 'Cinturón por confirmar'],
          ] as [F, string][]
        ).map(([id, l]) => (
          <FilterChip key={id} active={f === id} onClick={() => setF(id)}>
            {l}
          </FilterChip>
        ))}
      </div>
      {plans.size > 0 && (
        <label className="flex items-center gap-2 text-[13px] font-medium text-muted">
          Tarifa
          <select
            value={planFilter}
            onChange={(e) => setPlanFilter(e.target.value)}
            className="h-10 flex-1 rounded-full border border-border bg-surface-2 px-3 text-[14px] text-ink md:max-w-[280px]"
          >
            <option value="">Todas las tarifas</option>
            {planNames.map((n) => (
              <option key={n} value={n}>
                {n} ({[...plans.values()].filter((p) => p.name === n).length})
              </option>
            ))}
            <option value="__sin">Sin tarifa ({[...plans.values()].filter((p) => !p.name).length})</option>
            <option value="__plus">Con ITACA+ ({[...plans.values()].filter((p) => p.plus).length})</option>
          </select>
        </label>
      )}
      <div className="grid grid-cols-1 gap-x-6 lg:grid-cols-2">
        {list.map((r) => (
          <button
            key={r.profile_id}
            onClick={() => setOpen(r)}
            className="flex items-center gap-3 border-0 border-b border-line bg-transparent py-[9px] text-left text-ink"
          >
            <Avatar text={initials(r.full_name)} src={r.avatar_path ? urls[r.avatar_path] : null} />
            <span className="flex min-w-0 flex-1 flex-col gap-[2px]">
              <span className="truncate text-[15px] font-semibold">{r.full_name}</span>
              <span className="truncate text-[12px] text-muted">
                {r.belt ? `${BELT_LABEL[r.belt]}${r.stripes ? ` · ${r.stripes} ${r.stripes === 1 ? 'grado' : 'grados'}` : ''}` : 'Cinturón sin indicar'}
                {r.self_declared ? ' (indicado por el alumno)' : ''} · {r.attended_30d} clases en 30 días
              </span>
              {plans.size > 0 && (
                <span className="truncate text-[12px] font-medium text-ink-2">
                  {plans.get(r.profile_id)?.name ?? 'Sin tarifa'}
                  {plans.get(r.profile_id)?.plus ? ' + ITACA+' : ''}
                </span>
              )}
            </span>
            {r.status === 'inactive' && <Chip tone="warn" small>{r.full_name === 'Usuario eliminado' ? 'Eliminada' : 'Pendiente'}</Chip>}
            {requestFor(r.profile_id) && <Chip tone="accent" small>Pide {requestFor(r.profile_id)!.plan_name}</Chip>}
            {r.role !== 'member' && <Chip tone="neutral" small>{ROLE_LABEL[r.role]}</Chip>}
            {!r.has_account && <Chip tone="surface" small>Sin cuenta</Chip>}
          </button>
        ))}
      </div>
      {rows && list.length === 0 && <p className="m-0 py-4 text-[14px] text-muted">Nadie coincide con la búsqueda.</p>}

      {open && (
        <MemberSheet
          row={open}
          avatar={open.avatar_path ? urls[open.avatar_path] : null}
          canPromote={canPromote}
          canActivate={canActivate}
          request={requestFor(open.profile_id)}
          onClose={() => setOpen(null)}
          onSaved={async () => {
            setOpen(null)
            await load()
          }}
        />
      )}
    </Screen>
  )
}

function MemberSheet({
  row,
  avatar,
  canPromote,
  canActivate,
  request,
  onClose,
  onSaved,
}: {
  row: RosterRow
  avatar: string | null
  canPromote: boolean
  canActivate: boolean
  request?: PlanRequestRow
  onClose: () => void
  onSaved: () => void
}) {
  const app = useApp()
  const [belt, setBelt] = useState<Belt>(row.belt ?? 'blanco')
  const [stripes, setStripes] = useState(row.stripes ?? 0)
  const [date, setDate] = useState(ymd(new Date()))
  const [note, setNote] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const maxStripes = belt === 'negro' ? 6 : 4
  const fieldCls = 'h-12 rounded-[14px] border-[1.5px] border-border bg-bg px-3 text-[16px] text-ink'

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase || !app.gymId) return
    setSaving(true)
    setError(null)
    const { error } = await supabase.rpc('promote', {
      p_gym: app.gymId,
      p_profile: row.profile_id,
      p_belt: belt,
      p_stripes: stripes,
      p_date: date || null,
      p_note: note || null,
    })
    setSaving(false)
    if (error) return setError(error.message)
    app.toast(`Cinturón guardado: ${row.full_name}, ${BELT_LABEL[belt].toLowerCase()}${stripes ? ` con ${stripes} ${stripes === 1 ? 'grado' : 'grados'}` : ''}`)
    onSaved()
  }

  return (
    <Sheet open onClose={onClose} title={row.full_name}>
      <div className="flex items-center gap-3">
        <Avatar text={initials(row.full_name)} size={56} tone="ink" src={avatar} />
        <div className="flex flex-col">
          <span className="text-[14px] text-muted">
            {ROLE_LABEL[row.role]}
            {row.has_account ? '' : ' · sin cuenta en la app'}
          </span>
          <span className="text-[14px] text-muted">{row.attended_30d} clases en los últimos 30 días</span>
        </div>
      </div>
      {row.status === 'inactive' && row.full_name !== 'Usuario eliminado' && (
        <div className="flex flex-col gap-2 rounded-[14px] bg-warn-bg p-3 text-warn-fg">
          <span className="text-[14px] font-medium">Cuenta pendiente: todavía no puede reservar ni ver el horario.</span>
          {canActivate ? (
            <Btn
              size="sm"
              disabled={saving}
              onClick={async () => {
                if (!supabase || !app.gymId) return
                setSaving(true)
                const { error } = await supabase.from('gym_members').update({ status: 'active' }).eq('gym_id', app.gymId).eq('profile_id', row.profile_id)
                setSaving(false)
                if (error) return setError('No se pudo activar la cuenta')
                app.toast(`Cuenta de ${row.full_name} activada`)
                onSaved()
              }}
            >
              Activar cuenta
            </Btn>
          ) : (
            <span className="text-[13px]">La activan recepción o administración.</span>
          )}
        </div>
      )}
      <RoleSection row={row} onChanged={onSaved} />
      {canActivate && <PlanSection profileId={row.profile_id} canAssign={canActivate} request={request} onAssigned={onSaved} />}
      {row.belt && <BeltBar belt={row.belt} stripes={row.stripes ?? 0} />}
      <p className="m-0 text-[13px] text-muted">
        {row.belt
          ? `Actual: ${BELT_LABEL[row.belt].toLowerCase()}, ${row.stripes ?? 0} ${row.stripes === 1 ? 'grado' : 'grados'}${row.promoted_at ? ` desde el ${new Date(row.promoted_at + 'T12:00:00').toLocaleDateString('es-ES')}` : ''}${row.self_declared ? ' (indicado por el alumno, sin confirmar)' : ''}`
          : 'Todavía no tiene cinturón registrado.'}
      </p>

      {canPromote ? (
        <form onSubmit={submit} className="mt-2 flex flex-col gap-3">
          <span className="font-mono text-[11px] font-medium uppercase tracking-[0.06em] text-muted">Registrar graduación o corregir</span>
          <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="Color del cinturón">
            {BELTS.map((b) => (
              <button
                key={b}
                type="button"
                role="radio"
                aria-checked={belt === b}
                onClick={() => {
                  setBelt(b)
                  if (stripes > (b === 'negro' ? 6 : 4)) setStripes(0)
                }}
                className={cx('h-10 rounded-full border-[1.5px] px-3 text-[13px]', belt === b ? 'border-ink bg-ink font-semibold text-on-ink' : 'border-border bg-bg text-ink')}
              >
                {BELT_LABEL[b]}
              </button>
            ))}
          </div>
          <div className="grid grid-cols-2 gap-3">
            <label className="flex flex-col gap-1 text-[12px] font-semibold text-muted">
              Grados
              <select className={fieldCls} value={stripes} onChange={(e) => setStripes(Number(e.target.value))}>
                {Array.from({ length: maxStripes + 1 }, (_, i) => (
                  <option key={i} value={i}>
                    {i === 0 ? 'Sin grados' : `${i} ${i === 1 ? 'grado' : 'grados'}`}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1 text-[12px] font-semibold text-muted">
              Fecha
              <input className={fieldCls} type="date" value={date} max={ymd(new Date())} onChange={(e) => setDate(e.target.value)} />
            </label>
          </div>
          <label className="flex flex-col gap-1 text-[12px] font-semibold text-muted">
            Nota (opcional)
            <input className={fieldCls} value={note} maxLength={300} onChange={(e) => setNote(e.target.value)} />
          </label>
          {error && (
            <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
              {error}
            </p>
          )}
          <Btn type="submit" variant="accent" size="lg" block disabled={saving}>
            {saving ? 'Guardando…' : 'Guardar cinturón'}
          </Btn>
        </form>
      ) : (
        <p className="m-0 text-[13px] text-muted">Solo el personal docente registra graduaciones.</p>
      )}
    </Sheet>
  )
}

/** Rol en el gimnasio (lo cambia el propietario) y "da clases" (propietario y administración) */
function RoleSection({ row, onChanged }: { row: RosterRow; onChanged: () => void }) {
  const app = useApp()
  const auth = useAuth()
  const my = auth.memberships.find((m) => m.gymId === app.gymId)?.role
  const isOwner = my === 'owner'
  const canTeach = my === 'owner' || my === 'admin'
  const [role, setRole] = useState<GymRole>(row.role)
  const [teaches, setTeaches] = useState<boolean | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const eligible = row.has_account && !(row.birth_date && row.birth_date > new Date(Date.now() - 18 * 365.25 * 86400000).toISOString().slice(0, 10))

  useEffect(() => {
    if (!supabase || !app.gymId) return
    supabase
      .from('gym_members')
      .select('teaches')
      .eq('gym_id', app.gymId)
      .eq('profile_id', row.profile_id)
      .single()
      .then(({ data }) => setTeaches(data ? !!data.teaches : false))
  }, [app.gymId, row.profile_id])

  if (!isOwner && !canTeach) return null
  const save = async (nextRole: GymRole, nextTeaches: boolean | null) => {
    if (!supabase || !app.gymId) return
    setBusy(true)
    setError(null)
    const { error } = await supabase.rpc('set_member_role', {
      p_gym: app.gymId,
      p_profile: row.profile_id,
      p_role: nextRole !== row.role ? nextRole : null,
      p_teaches: nextTeaches,
    })
    setBusy(false)
    if (error) {
      setRole(row.role)
      return setError(error.message)
    }
    app.toast(nextRole !== row.role ? `${row.full_name.split(' ')[0]} ahora es ${ROLE_LABEL[nextRole].toLowerCase()}` : nextTeaches ? 'Ahora aparece como monitor' : 'Ya no aparece como monitor')
    await app.reloadSchedule()
    onChanged()
  }

  return (
    <div className="flex flex-col gap-2 rounded-[14px] bg-surface-2 p-3">
      <span className="font-mono text-[11px] uppercase tracking-[0.06em] text-muted">Rol en el gimnasio</span>
      {isOwner ? (
        <select
          aria-label="Rol"
          value={role}
          disabled={busy}
          onChange={(e) => {
            const r = e.target.value as GymRole
            setRole(r)
            void save(r, null)
          }}
          className="h-12 rounded-[12px] border border-border bg-bg px-3 text-[15px] text-ink"
        >
          {(['member', 'coach', 'front_desk', 'admin', 'owner'] as GymRole[]).map((r) => (
            <option key={r} value={r} disabled={r !== 'member' && !eligible}>
              {ROLE_LABEL[r]}
            </option>
          ))}
        </select>
      ) : (
        <span className="text-[15px] font-semibold">{ROLE_LABEL[row.role]}</span>
      )}
      {!eligible && row.role === 'member' && <span className="text-[12px] text-muted">Para ser del personal hace falta ser mayor de edad y tener cuenta en la app.</span>}
      {(row.role === 'owner' || row.role === 'admin') && canTeach && teaches !== null && (
        <label className="flex min-h-11 items-center gap-3 text-[14px]">
          <input type="checkbox" className="h-5 w-5" checked={teaches} disabled={busy} onChange={(e) => void save(row.role, e.target.checked)} />
          También da clases (aparece en Monitores y se le pueden asignar clases)
        </label>
      )}
      {row.role === 'coach' && <span className="text-[12px] text-muted">Aparece en Monitores y se le pueden asignar clases.</span>}
      {error && (
        <p role="alert" className="m-0 rounded-[12px] bg-err-bg px-3 py-2 text-[13px] font-medium text-err-fg">
          {error}
        </p>
      )}
    </div>
  )
}

/** Tarifa del alumno: la vigente, lo que lleva gastado y asignar otra (recepción y administración) */
function PlanSection({ profileId, canAssign, request, onAssigned }: { profileId: string; canAssign: boolean; request?: PlanRequestRow; onAssigned?: () => void }) {
  const app = useApp()
  const plans = app.plans.filter((p) => p.dbId)
  const [status, setStatus] = useState<Awaited<ReturnType<typeof loadPlanStatus>> | undefined>(undefined)
  const [editing, setEditing] = useState(false)
  const [planId, setPlanId] = useState('')
  const [starts, setStarts] = useState(ymd(new Date()))
  const [ends, setEnds] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const fieldCls = 'h-12 rounded-[14px] border-[1.5px] border-border bg-bg px-3 text-[16px] text-ink'

  const [plus, setPlus] = useState(false)
  const load = useCallback(async () => {
    try {
      setStatus(await loadPlanStatus(profileId))
    } catch {
      setStatus(null)
    }
    const { data } = await supabase!.rpc('has_itaca_plus', { p_profile: profileId })
    setPlus(data === true)
  }, [profileId])
  useEffect(() => {
    void load()
  }, [load])

  const chosen = plans.find((p) => p.dbId === planId)
  const assign = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase || !chosen) return
    setBusy(true)
    setError(null)
    const { error } = await supabase.rpc('assign_plan', { p_profile: profileId, p_plan: chosen.dbId, p_starts_on: starts, p_ends_on: ends || null })
    setBusy(false)
    if (error) return setError(error.message)
    app.toast(`Tarifa asignada: ${chosen.name}`)
    setEditing(false)
    void load()
    if (request) onAssigned?.()
  }
  const endToday = async () => {
    if (!supabase || !status) return
    setBusy(true)
    const { error } = await supabase.rpc('end_plan', { p_member_plan: status.memberPlanId, p_ends_on: ymd(new Date()) })
    setBusy(false)
    if (error) return setError(error.message)
    app.toast('Tarifa terminada hoy')
    void load()
  }
  const fmt = (d: string) => new Date(d + 'T12:00:00').toLocaleDateString('es-ES')
  const usage = planUsageText(status ?? null, true)

  return (
    <div className="flex flex-col gap-2 rounded-[14px] bg-surface-2 p-3">
      <div className="flex items-start justify-between gap-3">
        <div className="flex flex-col">
          <span className="font-mono text-[11px] uppercase tracking-[0.06em] text-muted">Tarifa</span>
          <span className="text-[16px] font-semibold">{status === undefined ? '…' : status ? status.planName : 'Sin tarifa asignada'}</span>
          {status && (
            <span className="text-[13px] text-muted">
              Desde el {fmt(status.startsOn)}
              {status.endsOn ? ` hasta el ${fmt(status.endsOn)}` : ' · se renueva cada mes'}
            </span>
          )}
          {usage && <span className="text-[13px] font-medium text-ink-2">{usage}</span>}
          <span className="text-[13px] text-muted">ITACA+: {plus ? 'activo' : 'no'}</span>
        </div>
        {canAssign && !editing && (
          <Btn size="sm" variant="soft" onClick={() => setEditing(true)}>
            {status ? 'Cambiar' : 'Asignar'}
          </Btn>
        )}
      </div>
      {request && !editing && canAssign && (
        <div className="flex flex-col gap-2 rounded-[12px] bg-surface p-3">
          <span className="text-[14px] font-medium">
            Ha pedido <b>{request.plan_name}</b> desde la app ({new Date(request.created_at).toLocaleDateString('es-ES')}). Cuando la pague, asígnasela.
          </span>
          <Btn
            size="sm"
            variant="accent"
            onClick={() => {
              setPlanId(request.plan_id)
              setEditing(true)
            }}
          >
            Asignar {request.plan_name}
          </Btn>
        </div>
      )}
      {editing && (
        <form onSubmit={assign} className="flex flex-col gap-3">
          <label className="flex flex-col gap-1 text-[12px] font-semibold text-muted">
            Tarifa
            <select className={fieldCls} value={planId} onChange={(e) => setPlanId(e.target.value)} required>
              <option value="">Elige una tarifa</option>
              {plans.map((p) => (
                <option key={p.dbId} value={p.dbId}>
                  {p.isAddon ? `${p.name} · complemento de ${(p.priceCents / 100).toLocaleString('es-ES')} €/mes` : `${p.name} · ${planSessions(p)}`}
                </option>
              ))}
            </select>
          </label>
          <div className="grid grid-cols-2 gap-3">
            <label className="flex flex-col gap-1 text-[12px] font-semibold text-muted">
              Desde
              <input className={fieldCls} type="date" value={starts} onChange={(e) => setStarts(e.target.value)} required />
            </label>
            <label className="flex flex-col gap-1 text-[12px] font-semibold text-muted">
              Hasta (opcional)
              <input className={fieldCls} type="date" value={ends} min={starts} onChange={(e) => setEnds(e.target.value)} />
            </label>
          </div>
          <p className="m-0 text-[12px] text-muted">
            {chosen?.validityMonths ? `Si no pones fecha de fin, vale ${chosen.validityMonths} meses.` : 'Sin fecha de fin, se renueva cada mes hasta que la cambies.'} La tarifa anterior termina el día antes.
          </p>
          {error && (
            <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
              {error}
            </p>
          )}
          <div className="flex gap-2">
            <Btn type="submit" variant="accent" disabled={busy || !chosen}>
              {busy ? 'Guardando…' : 'Guardar tarifa'}
            </Btn>
            <Btn type="button" variant="ghost" onClick={() => setEditing(false)}>
              Cancelar
            </Btn>
          </div>
        </form>
      )}
      {canAssign && !editing && status && !status.endsOn && (
        <button type="button" onClick={() => void endToday()} disabled={busy} className="self-start border-0 bg-transparent p-0 text-[13px] font-semibold text-err-fg">
          Terminar la tarifa hoy (baja)
        </button>
      )}
    </div>
  )
}

type DF = 'todos' | 'graduar' | 'deuda' | 'prueba'

function DemoMembers() {
  const app = useApp()
  const [q, setQ] = useState('')
  const [f, setF] = useState<DF>('todos')
  const list = app.members
    .filter((m) => !q || norm(m.name).includes(norm(q)))
    .filter((m) => f === 'todos' || (f === 'graduar' && m.readyToPromote) || (f === 'deuda' && m.debt) || (f === 'prueba' && m.trial))
    .sort((a, b) => a.name.localeCompare(b.name, 'es'))

  return (
    <Screen gap={12}>
      <Title>Alumnos</Title>
      <p className="m-0 text-[14px] text-muted">{app.members.length} alumnos de ejemplo</p>
      <input
        type="search"
        aria-label="Buscar alumno"
        placeholder="Buscar alumno"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        className="h-[46px] rounded-[14px] border-[1.5px] border-border bg-bg px-[14px] text-[15px] text-ink placeholder:text-muted"
      />
      <div className="no-scrollbar -mx-5 flex gap-2 overflow-x-auto px-5">
        {(
          [
            ['todos', 'Todos'],
            ['graduar', 'Listos para graduar'],
            ['deuda', 'Con deuda'],
            ['prueba', 'De prueba'],
          ] as [DF, string][]
        ).map(([id, l]) => (
          <FilterChip key={id} active={f === id} onClick={() => setF(id)}>
            {l}
          </FilterChip>
        ))}
      </div>
      <div className="grid grid-cols-1 gap-x-6 lg:grid-cols-2">
        {list.map((m) => (
          <div key={m.id} className="flex items-center gap-3 border-b border-line py-[9px]">
            <Avatar text={initials(m.name)} />
            <div className="flex min-w-0 flex-1 flex-col gap-[2px]">
              <span className="truncate text-[15px] font-semibold">{m.name}</span>
              <span className="text-[12px] text-muted">
                {BELT_LABEL[m.belt]}
                {m.stripes ? ` · ${m.stripes} ${m.stripes === 1 ? 'grado' : 'grados'}` : ''} · {PLANS.find((p) => p.id === m.plan)?.name}
              </span>
            </div>
            {m.debt && <Chip tone="err" small>Cuota pendiente</Chip>}
            {m.trial && <Chip tone="accent" small>Prueba</Chip>}
            {m.readyToPromote && <Chip tone="ok" small>Graduar</Chip>}
          </div>
        ))}
        {list.length === 0 && <p className="m-0 py-4 text-[14px] text-muted">Nadie coincide con la búsqueda.</p>}
      </div>
    </Screen>
  )
}
