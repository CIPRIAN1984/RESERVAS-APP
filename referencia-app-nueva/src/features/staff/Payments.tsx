import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { Screen } from '../../components/Layout'
import { Avatar, Chip, Eyebrow, ProgressBar, Sheet, Stat, Title } from '../../components/ui'
import { BILLING } from '../../lib/data'
import { euros, initials } from '../../lib/logic'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../auth/AuthProvider'

/**
 * Cobros por tarifa (propietario y administración).
 * En el paso 6 estas cifras salen de vistas SQL sobre `subscriptions` y `payments`.
 */
export function Payments() {
  const auth = useAuth()
  return auth.mode === 'live' ? <LivePayments /> : <DemoPayments />
}

function DemoPayments() {
  const app = useApp()
  const [overdueOpen, setOverdueOpen] = useState(false)
  const expected = BILLING.byPlan.reduce((a, p) => a + p.expected, 0)
  const collected = BILLING.byMethod.reduce((a, m) => a + m.amount, 0)
  const pending = expected - collected
  const pct = Math.round((collected / expected) * 100)
  const maxPlan = Math.max(...BILLING.byPlan.map((p) => p.expected))
  // Ingreso medio por alumno: previsto entre alumnos de pago
  const avg = expected / BILLING.payingStudents

  return (
    <Screen gap={12}>
      <div className="flex items-center justify-between">
        <Title>Cobros</Title>
        <span className="flex h-11 items-center rounded-full border-[1.5px] border-border px-4 text-[14px] font-semibold">{BILLING.month}</span>
      </div>

      <div className="flex flex-col gap-[10px] rounded-[24px] bg-surface px-5 py-[18px]">
        <Eyebrow>Cobrado este mes</Eyebrow>
        <div className="flex flex-wrap items-baseline gap-2">
          <span className="text-[48px] font-bold leading-none tracking-[-0.03em]">{euros(collected)}</span>
          <span className="text-[14px] text-muted">de {euros(expected)} previstos</span>
        </div>
        <ProgressBar value={pct} height={10} label={`${pct} por ciento cobrado`} />
        <div className="flex items-center justify-between gap-2">
          <Chip tone="err">
            {euros(pending)} pendientes · {BILLING.pendingStudents} alumnos
          </Chip>
          <button onClick={() => setOverdueOpen(true)} className="h-11 whitespace-nowrap border-0 bg-transparent px-1 text-[14px] font-semibold text-ink underline">
            Ver impagos
          </button>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2">
        <Stat compact size={28} value={BILLING.payingStudents} label="alumnos de pago" />
        <Stat compact size={28} value={`+${BILLING.newSubs} / −${BILLING.cancelledSubs}`} label="altas y bajas" />
        <Stat compact size={28} value={euros(Math.round(avg * 10) / 10)} label="media por alumno" />
      </div>

      <div className="flex flex-col gap-[10px]">
        <Eyebrow>Ingresos por tarifa</Eyebrow>
        {BILLING.byPlan.map((p) => (
          <div key={p.name} className="flex flex-col gap-1">
            <div className="flex justify-between text-[14px]">
              <span className="font-semibold">
                {p.name}{' '}
                <span className="font-normal text-muted">
                  · {p.count} {p.unit}
                </span>
              </span>
              <span className="font-bold">{euros(p.expected)}</span>
            </div>
            <ProgressBar value={(p.expected / maxPlan) * 100} accent={p.accent} track="bg-surface" />
          </div>
        ))}
      </div>

      <div className="flex flex-col gap-2">
        <Eyebrow>Cobrado por método</Eyebrow>
        <div className="grid grid-cols-4 gap-[6px]">
          {BILLING.byMethod.map((m) => (
            <div key={m.name} className="flex flex-col gap-[2px] rounded-[14px] bg-surface px-2 py-[10px]">
              <span className="text-[14px] font-bold">{euros(m.amount)}</span>
              <span className="text-[11px] text-muted">{m.name}</span>
            </div>
          ))}
        </div>
      </div>

      <Sheet open={overdueOpen} onClose={() => setOverdueOpen(false)} title="Impagos">
        {BILLING.overdue.map((o) => {
          const m = app.member(o.memberId)!
          return (
            <div key={o.memberId} className="flex items-center gap-3 border-b border-line py-2 last:border-0">
              <Avatar text={initials(m.name)} />
              <div className="flex flex-1 flex-col">
                <span className="text-[15px] font-semibold">{m.name}</span>
                <span className="text-[12px] text-muted">Vencida hace {o.days} días</span>
              </div>
              <span className="text-[15px] font-bold">{euros(o.amount)}</span>
            </div>
          )
        })}
        <p className="m-0 pt-2 text-[13px] text-muted">
          Lista de ejemplo. Con los cobros reales (paso 6) aparecerán todos, por antigüedad, y se podrá registrar el pago por Bizum, efectivo o transferencia.
        </p>
      </Sheet>
    </Screen>
  )
}

interface Summary {
  month: string
  expected_cents: number
  by_plan: { plan: string; plan_id: string; people: number; expected_cents: number; addon: boolean; members: { id: string; name: string }[] }[]
  with_plan: number
  members: number
  without_plan: number
  new: number
  ended: number
  pending_requests: number
}

const MONTHS = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const eur = (cents: number) => `${(cents / 100).toLocaleString('es-ES', { maximumFractionDigits: cents % 100 ? 2 : 0 })} €`

/** Cobros con servidor: previsto del mes según las tarifas asignadas */
function LivePayments() {
  return (
    <Screen gap={14}>
      <Title>Cobros</Title>
      <ExpectedPanel />
    </Screen>
  )
}

/** Ingresos previstos del mes (se usa en Tarifas → Ingresos) */
export function ExpectedPanel() {
  const app = useApp()
  const nav = useNavigate()
  const [offset, setOffset] = useState(0)
  const [openPlan, setOpenPlan] = useState<Summary['by_plan'][number] | null>(null)
  const [data, setData] = useState<Summary | null>(null)
  const [error, setError] = useState(false)
  const month = new Date(app.now.getFullYear(), app.now.getMonth() + offset, 1)
  const key = `${month.getFullYear()}-${String(month.getMonth() + 1).padStart(2, '0')}-01`

  useEffect(() => {
    if (!supabase || !app.gymId) return
    let cancelled = false
    setData(null)
    supabase.rpc('gym_billing_summary', { p_gym: app.gymId, p_month: key }).then(({ data, error }) => {
      if (cancelled) return
      setError(!!error)
      setData(error ? null : (data as Summary))
    })
    return () => {
      cancelled = true
    }
  }, [app.gymId, key])

  const plans = (data?.by_plan ?? []).filter((p) => p.expected_cents > 0 || p.people > 0)
  const max = Math.max(1, ...plans.map((p) => p.expected_cents))
  const avg = data && data.with_plan ? data.expected_cents / data.with_plan : 0

  return (
    <div className="flex flex-col gap-[14px]">
      <div className="flex items-center justify-end gap-2">
        <div className="flex items-center gap-1">
          <button type="button" aria-label="Mes anterior" onClick={() => setOffset((o) => o - 1)} className="hy flex h-10 w-10 items-center justify-center rounded-full border-0 bg-surface-2 text-ink">
            ‹
          </button>
          <span className="min-w-[96px] text-center text-[14px] font-semibold">
            {MONTHS[month.getMonth()].charAt(0).toUpperCase() + MONTHS[month.getMonth()].slice(1)} {month.getFullYear()}
          </span>
          <button type="button" aria-label="Mes siguiente" disabled={offset >= 2} onClick={() => setOffset((o) => o + 1)} className="hy flex h-10 w-10 items-center justify-center rounded-full border-0 bg-surface-2 text-ink disabled:opacity-30">
            ›
          </button>
        </div>
      </div>

      {error ? (
        <p className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] text-err-fg">No se pudieron cargar los cobros. Solo los ven recepción y administración.</p>
      ) : !data ? (
        <p className="m-0 text-[14px] text-muted">Cargando…</p>
      ) : (
        <>
          <div className="flex flex-col gap-2 rounded-[24px] bg-surface px-5 py-[18px]">
            <Eyebrow>Ingresos previstos este mes</Eyebrow>
            <span className="text-[48px] font-bold leading-none tracking-[-0.03em]">{eur(data.expected_cents)}</span>
            <span className="text-[14px] text-muted">
              {data.with_plan} {data.with_plan === 1 ? 'alumno' : 'alumnos'} con tarifa de {data.members}. Se cobra en recepción; el registro de pagos llegará con el pago con tarjeta.
            </span>
          </div>

          <div className="grid grid-cols-3 gap-2">
            <Stat compact size={28} value={data.with_plan} label="con tarifa" />
            <Stat compact size={28} value={`+${data.new} / −${data.ended}`} label="altas y bajas" />
            <Stat compact size={28} value={eur(Math.round(avg))} label="media por alumno" />
          </div>

          {data.without_plan > 0 && (
            <Link to="/staff/alumnos" className="hy-text flex items-center justify-between rounded-[14px] bg-warn-bg px-4 py-3 text-[14px] font-medium text-warn-fg no-underline">
              {data.without_plan} {data.without_plan === 1 ? 'alumno sin tarifa asignada' : 'alumnos sin tarifa asignada'}
              <span className="font-semibold underline underline-offset-4">Asignar</span>
            </Link>
          )}
          {data.pending_requests > 0 && (
            <Link to="/staff/alumnos" className="hy-text flex items-center justify-between rounded-[14px] bg-surface-2 px-4 py-3 text-[14px] font-medium text-ink no-underline">
              {data.pending_requests} {data.pending_requests === 1 ? 'solicitud de tarifa pendiente' : 'solicitudes de tarifa pendientes'}
              <span className="font-semibold underline underline-offset-4">Ver</span>
            </Link>
          )}

          <div className="flex flex-col gap-[10px]">
            <Eyebrow>Ingresos por tarifa</Eyebrow>
            {plans.length === 0 && <p className="m-0 text-[14px] text-muted">Aún no hay tarifas asignadas este mes. Se asignan en Alumnos → ficha → Tarifa.</p>}
            {plans.map((p) => (
              <button
                key={p.plan}
                type="button"
                onClick={() => setOpenPlan(p)}
                aria-label={`${p.plan}: ver sus ${p.people} ${p.people === 1 ? 'alumno' : 'alumnos'}`}
                className="hy-text flex flex-col gap-1 rounded-[12px] border-0 bg-transparent p-0 text-left text-ink"
              >
                <div className="flex w-full justify-between text-[14px]">
                  <span className="font-semibold">
                    {p.plan} <span className="font-normal text-muted">· {p.people} {p.addon ? 'suscriptores' : p.people === 1 ? 'alumno' : 'alumnos'}</span>
                  </span>
                  <span className="font-bold">{eur(p.expected_cents)}</span>
                </div>
                <span className="block w-full">
                  <ProgressBar value={(p.expected_cents / max) * 100} height={8} accent={p.addon} label={`${p.plan}: ${eur(p.expected_cents)}`} />
                </span>
              </button>
            ))}
            <p className="m-0 text-[12px] text-muted">Toca una tarifa para ver quién la tiene. Mensuales a precio completo; trimestrales y anuales, la parte de un mes; bonos y pases, el mes en que empiezan.</p>
          </div>
        </>
      )}
      {openPlan && (
        <Sheet open onClose={() => setOpenPlan(null)} title={openPlan.plan}>
          <p className="m-0 text-[14px] text-muted">
            {openPlan.people} {openPlan.people === 1 ? 'persona' : 'personas'} · {eur(openPlan.expected_cents)} previstos este mes
          </p>
          <div className="flex flex-col">
            {[...openPlan.members]
              .sort((a, b) => a.name.localeCompare(b.name))
              .map((m) => (
                <button
                  key={m.id}
                  type="button"
                  onClick={() => nav(`/staff/alumnos?alumno=${m.id}`)}
                  className="hy-text flex min-h-[48px] items-center justify-between border-0 border-b border-line bg-transparent text-left text-[15px] text-ink last:border-b-0"
                >
                  {m.name}
                  <span className="text-muted">›</span>
                </button>
              ))}
          </div>
        </Sheet>
      )}
    </div>
  )
}
