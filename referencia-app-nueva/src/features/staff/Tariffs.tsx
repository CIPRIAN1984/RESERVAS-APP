import { useEffect, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router'
import { Screen } from '../../components/Layout'
import { Btn, Chip, EmptyState, FilterChip, Sheet, Title, cx } from '../../components/ui'
import { usePendingPlanRequests, type PendingPlanRequest } from '../../lib/planRequests'
import { useApp } from '../../lib/store'
import { ROLE_LABEL, supabase, type GymRole } from '../../lib/supabase'
import { useAuth } from '../auth/AuthProvider'
import { ExpectedPanel } from './Payments'

type View = 'pendientes' | 'alumnos' | 'ingresos'

const eur = (cents: number) => `${(cents / 100).toLocaleString('es-ES', { maximumFractionDigits: cents % 100 ? 2 : 0 })} €`
const fmt = (d: string) => new Date(d + 'T12:00:00').toLocaleDateString('es-ES', { day: 'numeric', month: 'short', year: 'numeric' })
const norm = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

/** Tarifas (recepción y administración): solicitudes por aprobar, tarifa de cada alumno y previsto del mes */
export function Tariffs() {
  const app = useApp()
  const auth = useAuth()
  const [params, setParams] = useSearchParams()
  const view = (params.get('vista') as View) || 'pendientes'
  const can = auth.memberships.some((m) => m.gymId === app.gymId && ['owner', 'admin', 'front_desk'].includes(m.role))
  const pending = usePendingPlanRequests(can ? app.gymId ?? undefined : undefined)
  const count = pending.items?.length ?? 0

  if (auth.mode !== 'live') {
    return (
      <Screen>
        <Title>Tarifas</Title>
        <EmptyState title="Disponible con el servidor" text="Las tarifas de los alumnos se gestionan con la app conectada." />
      </Screen>
    )
  }
  if (!can) {
    return (
      <Screen>
        <Title>Tarifas</Title>
        <EmptyState title="Sin permiso" text="Las tarifas las gestionan recepción y administración." />
      </Screen>
    )
  }

  return (
    <Screen gap={14}>
      <Title>Tarifas</Title>
      <div role="tablist" aria-label="Vista" className="grid grid-cols-3 gap-1 rounded-[14px] bg-surface-2 p-1">
        {(
          [
            ['pendientes', 'Por aprobar'],
            ['alumnos', 'Alumnos'],
            ['ingresos', 'Ingresos'],
          ] as [View, string][]
        ).map(([v, label]) => (
          <button
            key={v}
            type="button"
            role="tab"
            aria-selected={view === v}
            onClick={() => setParams(v === 'pendientes' ? {} : { vista: v }, { replace: true })}
            className={cx('hy h-10 rounded-[10px] border-0 text-[14px]', view === v ? 'bg-ink font-semibold text-on-ink' : 'bg-transparent font-medium text-ink-2')}
          >
            <span className="inline-flex items-center gap-1.5 whitespace-nowrap">
              {label}
              {v === 'pendientes' && count > 0 && (
                <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-accent px-1.5 text-[11px] font-bold text-on-accent">{count}</span>
              )}
            </span>
          </button>
        ))}
      </div>

      {view === 'pendientes' && <PendingList items={pending.items} onChanged={pending.reload} />}
      {view === 'alumnos' && <StudentsPlans />}
      {(view === 'ingresos' || (params.get('vista') as string) === 'previsto') && <ExpectedPanel />}
    </Screen>
  )
}

function PendingList({ items, onChanged }: { items: PendingPlanRequest[] | null; onChanged: () => void }) {
  const app = useApp()
  const [busy, setBusy] = useState<string | null>(null)
  const [rejecting, setRejecting] = useState<PendingPlanRequest | null>(null)

  const approve = async (r: PendingPlanRequest) => {
    if (!supabase) return
    setBusy(r.id)
    const { error } = await supabase.rpc('assign_plan', { p_profile: r.profileId, p_plan: r.planId })
    setBusy(null)
    if (error) return app.toast(error.message)
    app.toast(`${r.planName} asignada a ${r.fullName.split(' ')[0]}`)
    onChanged()
  }

  if (items === null) return <p className="m-0 text-[14px] text-muted">Cargando…</p>
  if (items.length === 0) return <EmptyState title="Nada por aprobar" text="Cuando un alumno pida una tarifa desde la app aparecerá aquí, y te avisaremos al momento." />

  return (
    <div className="flex flex-col gap-3">
      <p className="m-0 text-[13px] text-muted">Aprueba cuando el alumno haya pagado en recepción. La tarifa empieza hoy y sustituye a la anterior (ITACA+ se suma).</p>
      {items.map((r) => (
        <div key={r.id} className="flex flex-col gap-3 rounded-[18px] border border-accent/50 bg-surface p-4">
          <div className="flex items-start justify-between gap-3">
            <div className="flex min-w-0 flex-col gap-[2px]">
              <span className="truncate text-[16px] font-bold">{r.fullName}</span>
              <span className="text-[14px] text-ink-2">
                Pide <b>{r.planName}</b> · {eur(r.priceCents)}/mes
              </span>
              <span className="text-[12px] text-muted">
                {r.isAddon ? 'Complemento: se suma a su tarifa' : r.currentPlan ? `Ahora tiene ${r.currentPlan}` : 'Ahora no tiene tarifa'} ·{' '}
                {r.createdAt.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' })}
              </span>
            </div>
            {!r.isAddon && r.currentPlan && <Chip tone="accent" small>Cambio</Chip>}
            {!r.currentPlan && !r.isAddon && <Chip tone="warn" small>Nueva</Chip>}
          </div>
          <div className="flex gap-2">
            <Btn variant="accent" block disabled={busy === r.id} onClick={() => void approve(r)}>
              {busy === r.id ? 'Aprobando…' : 'Aprobar'}
            </Btn>
            <Btn variant="outline" onClick={() => setRejecting(r)}>
              Rechazar
            </Btn>
          </div>
        </div>
      ))}
      {rejecting && (
        <RejectSheet
          r={rejecting}
          onClose={() => setRejecting(null)}
          onDone={() => {
            setRejecting(null)
            app.toast('Solicitud rechazada')
            onChanged()
          }}
        />
      )}
    </div>
  )
}

function RejectSheet({ r, onClose, onDone }: { r: PendingPlanRequest; onClose: () => void; onDone: () => void }) {
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)
  return (
    <Sheet open onClose={onClose} title="Rechazar solicitud">
      <p className="m-0 text-[15px]">
        {r.fullName} pidió <b>{r.planName}</b>.
      </p>
      <label className="flex flex-col gap-1 text-[13px] font-medium text-ink-2">
        Motivo (opcional, lo verá el alumno)
        <input className="h-12 rounded-[12px] border border-border bg-surface-2 px-3 text-[16px] text-ink" value={reason} maxLength={200} onChange={(e) => setReason(e.target.value)} placeholder="Pásate por recepción y lo vemos" />
      </label>
      <Btn
        variant="coral"
        block
        disabled={busy}
        onClick={async () => {
          if (!supabase) return
          setBusy(true)
          await supabase.rpc('reject_plan_request', { p_request: r.id, p_reason: reason.trim() || null })
          setBusy(false)
          onDone()
        }}
      >
        Rechazar
      </Btn>
    </Sheet>
  )
}

interface OverviewRow {
  profile_id: string
  full_name: string
  role: GymRole
  is_minor: boolean
  plan_id: string | null
  plan_name: string | null
  price_cents: number | null
  starts_on: string | null
  ends_on: string | null
  has_plus: boolean
  pending_plan: string | null
}

type F = 'todos' | 'sin' | 'caducan' | 'plus'

function StudentsPlans() {
  const app = useApp()
  const nav = useNavigate()
  const [rows, setRows] = useState<OverviewRow[] | null>(null)
  const [q, setQ] = useState('')
  const [f, setF] = useState<F>('todos')

  useEffect(() => {
    if (!supabase || !app.gymId) return
    supabase.rpc('staff_plan_overview', { p_gym: app.gymId }).then(({ data }) => setRows((data ?? []) as OverviewRow[]))
  }, [app.gymId])

  const soon = new Date(app.now.getTime() + 14 * 86400000).toISOString().slice(0, 10)
  const list = (rows ?? [])
    .filter((r) => !q || norm(r.full_name).includes(norm(q)))
    .filter((r) => f === 'todos' || (f === 'sin' && !r.plan_id) || (f === 'caducan' && !!r.ends_on && r.ends_on <= soon) || (f === 'plus' && r.has_plus))
  const byPlan = new Map<string, number>()
  for (const r of rows ?? []) if (r.plan_name) byPlan.set(r.plan_name, (byPlan.get(r.plan_name) ?? 0) + 1)

  if (rows === null) return <p className="m-0 text-[14px] text-muted">Cargando…</p>

  return (
    <div className="flex flex-col gap-3">
      <p className="m-0 text-[13px] text-muted">
        {rows.filter((r) => r.plan_id).length} con tarifa · {rows.filter((r) => !r.plan_id).length} sin tarifa · {rows.filter((r) => r.has_plus).length} con ITACA+
        {byPlan.size > 0 && ` · ${[...byPlan.entries()].sort((a, b) => b[1] - a[1]).map(([n, c]) => `${n} ${c}`).join(', ')}`}
      </p>
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
            ['sin', 'Sin tarifa'],
            ['caducan', 'Caducan en 14 días'],
            ['plus', 'Con ITACA+'],
          ] as [F, string][]
        ).map(([id, l]) => (
          <FilterChip key={id} active={f === id} onClick={() => setF(id)}>
            {l}
          </FilterChip>
        ))}
      </div>
      <div className="flex flex-col rounded-[18px] bg-surface px-4 py-1">
        {list.length === 0 && <p className="m-0 py-4 text-[14px] text-muted">Nadie en esta lista.</p>}
        {list.map((r) => (
          <button
            key={r.profile_id}
            type="button"
            onClick={() => nav(`/staff/alumnos?alumno=${r.profile_id}`)}
            className="hy-text flex min-h-[60px] items-center gap-3 border-0 border-b border-line bg-transparent py-2 text-left text-ink last:border-b-0"
          >
            <span className="flex min-w-0 flex-1 flex-col">
              <span className="truncate text-[15px] font-semibold">
                {r.full_name}
                {r.is_minor ? <span className="font-normal text-muted"> · menor</span> : null}
                {r.role !== 'member' ? <span className="font-normal text-muted"> · {ROLE_LABEL[r.role]}</span> : null}
              </span>
              <span className="truncate text-[13px] text-muted">
                {r.plan_name ? `${r.plan_name} · ${r.ends_on ? `hasta el ${fmt(r.ends_on)}` : 'se renueva cada mes'}` : 'Sin tarifa'}
                {r.has_plus ? ' · ITACA+' : ''}
              </span>
            </span>
            {r.pending_plan && <Chip tone="accent" small>Pide {r.pending_plan}</Chip>}
            {!r.plan_id && !r.pending_plan && <Chip tone="warn" small>Sin tarifa</Chip>}
            {r.ends_on && r.ends_on <= soon && <Chip tone="err" small>Caduca</Chip>}
          </button>
        ))}
      </div>
    </div>
  )
}
