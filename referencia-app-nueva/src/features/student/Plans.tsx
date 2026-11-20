import { useState } from 'react'
import { useNavigate } from 'react-router'
import { Screen } from '../../components/Layout'
import { BackButton, Btn, Card, Chip, Eyebrow, FilterChip, Sheet, Title } from '../../components/ui'
import { planPrice, planRenewal, planSessions, planUsageText } from '../../lib/data'
import { cancelPlanRequest, requestPlan, useMemberships, usePlanHistory, type PersonMembership } from '../../lib/memberships'
import { useFamily } from '../../lib/profileApi'
import { useApp } from '../../lib/store'
import { useAuth } from '../auth/AuthProvider'
import type { Plan } from '../../lib/types'

type Tab = 'membresias' | 'sueltas'

function IconTicket() {
  return (
    <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 8a2 2 0 0 0 2-2h14a2 2 0 0 0 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 0-2 2H5a2 2 0 0 0-2-2v-2a2 2 0 0 0 0-4z" />
      <path d="M9 9v1M9 12v1M9 15v1" />
    </svg>
  )
}
function IconRenew() {
  return (
    <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="5" width="18" height="16" rx="3" />
      <path d="M3 10h18M8 3v4M16 3v4M10 17a3 3 0 1 0 0-3M10 14h-1.5V12.5" />
    </svg>
  )
}

function PlanCard({ plan, current, onChoose, label, requested }: { plan: Plan; current: boolean; onChoose: () => void; label?: string; requested?: boolean }) {
  return (
    <div className="flex flex-col gap-3 rounded-[20px] bg-surface p-4">
      <div className="flex items-start justify-between gap-3">
        <div className="flex flex-col gap-[2px]">
          <span className="text-[18px] font-bold leading-tight">{plan.name}</span>
          {plan.description && <span className="text-[13px] text-muted">{plan.description}</span>}
        </div>
        <span className="shrink-0 whitespace-nowrap text-[15px] font-semibold text-ink-2">{planPrice(plan)}</span>
      </div>
      <div className="grid grid-cols-2 gap-2 text-[13px] text-ink-2">
        <span className="flex items-center gap-2">
          <IconTicket />
          {planSessions(plan)}
        </span>
        <span className="flex items-center gap-2">
          <IconRenew />
          {planRenewal(plan)}
        </span>
      </div>
      {current ? (
        <Chip tone="ok">Tu tarifa actual</Chip>
      ) : requested ? (
        <Chip tone="warn">Solicitada · pendiente de recepción</Chip>
      ) : (
        <Btn variant="ink" size="sm" block onClick={onChoose}>
          {label ?? (plan.kind === 'membership' ? 'Elegir esta tarifa' : 'Comprar')}
        </Btn>
      )}
    </div>
  )
}

export function Plans() {
  const auth = useAuth()
  return auth.mode === 'live' ? <LiveMemberships /> : <DemoPlans />
}

function DemoPlans() {
  const app = useApp()
  const nav = useNavigate()
  const [tab, setTab] = useState<Tab>('membresias')
  const mine = app.myPlan
  const status = app.planStatus
  const live = app.scheduleSource === 'live'
  const usage = planUsageText(status)
  const fmt = (d: string) => new Date(d + 'T12:00:00').toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })
  const list = app.plans.filter((p) => (tab === 'membresias' ? p.kind !== 'drop_in' : p.kind === 'drop_in'))
  const adults = list.filter((p) => p.audience !== 'kids')
  const kids = list.filter((p) => p.audience === 'kids')
  const firstOfNextMonth = new Date(app.now.getFullYear(), app.now.getMonth() + 1, 1)
  const nextCharge = `${firstOfNextMonth.getDate()} de ${firstOfNextMonth.toLocaleDateString('es-ES', { month: 'long' })}`

  const choose = (p: Plan) => {
    app.requestPlan(p.name)
    app.toast('Solicitud enviada a recepción. El pago en la app llegará más adelante')
  }

  return (
    <Screen gap={12}>
      <div className="flex items-center gap-3">
        <BackButton label="Volver al perfil" to="/perfil" />
        <Title>Tarifas</Title>
      </div>

      {mine ? (
        <div className="flex flex-col gap-[10px] rounded-[24px] bg-ink px-5 py-[18px] text-on-ink">
          <div className="flex items-center justify-between">
            <Eyebrow onInk>Tu tarifa</Eyebrow>
            {live ? null : app.me.debt ? <Chip tone="err">Cuota pendiente</Chip> : <Chip tone="ok">Al corriente</Chip>}
          </div>
          <div className="flex items-baseline justify-between gap-3">
            <span className="text-[24px] font-bold">{mine.name}</span>
            <span className="whitespace-nowrap font-display text-[28px] font-extrabold">{planPrice(mine)}</span>
          </div>
          <p className="m-0 text-[13px] text-muted-on-ink">
            {planSessions(mine)}
            {live
              ? status?.endsOn
                ? ` · Válida hasta el ${fmt(status.endsOn)}`
                : ' · Se renueva cada mes'
              : mine.autoRenew
                ? ` · Próximo cobro el ${nextCharge}`
                : ` · ${planRenewal(mine)}`}
          </p>
          {usage && <p className="m-0 text-[15px] font-semibold">{usage}</p>}
        </div>
      ) : (
        <div className="flex flex-col gap-1 rounded-[20px] bg-surface p-4">
          <span className="text-[15px] font-bold">{live ? 'Aún no tienes tarifa asignada' : 'Aún no tienes tarifa en la app'}</span>
          <span className="text-[13px] text-muted">
            {live ? 'Recepción te la asigna cuando pagas la cuota. Mientras tanto puedes reservar con normalidad.' : 'Elige una y recepción la activará. Las cuotas se gestionarán aquí más adelante.'}
          </span>
        </div>
      )}

      {app.state.requestedPlan && (
        <p role="status" className="m-0 rounded-2xl bg-warn-bg px-4 py-3 text-[13px] font-medium text-warn-fg">
          Solicitud enviada: {app.state.requestedPlan}. Recepción la confirmará contigo.
        </p>
      )}

      <div className="flex gap-2">
        <FilterChip active={tab === 'membresias'} onClick={() => setTab('membresias')}>
          Membresías
        </FilterChip>
        <FilterChip active={tab === 'sueltas'} onClick={() => setTab('sueltas')}>
          Clases sueltas
        </FilterChip>
      </div>

      <div className="flex flex-col gap-[10px]">
        {adults.map((p) => (
          <PlanCard key={p.id} plan={p} current={p.id === mine?.id} onChoose={() => choose(p)} />
        ))}
      </div>
      {kids.length > 0 && (
        <>
          <Eyebrow>Infantil</Eyebrow>
          <div className="flex flex-col gap-[10px]">
            {kids.map((p) => (
              <PlanCard key={p.id} plan={p} current={p.id === mine?.id} onChoose={() => choose(p)} />
            ))}
          </div>
        </>
      )}

      <div className="mt-2 flex flex-col gap-[10px] rounded-[18px] border border-accent/40 bg-surface px-5 py-4 text-ink">
        <div className="flex items-baseline justify-between">
          <span className="text-[22px] font-bold leading-none tracking-[-0.02em]">ITACA+</span>
          <span className="text-[15px] font-bold">+ 5 €/mes</span>
        </div>
        <p className="m-0 text-[14px] leading-[1.35]">Vídeos de las clases, técnicas sueltas y currículos. Se suma a una tarifa mensual de pago.</p>
        {app.itacaPlus ? (
          <button onClick={() => nav('/itaca')} className="hy h-12 rounded-[12px] border-0 bg-ink text-[15px] font-semibold text-on-ink">
            Ya estás suscrito · Ir a ITACA+
          </button>
        ) : (
          <button
            onClick={() => {
              app.setItacaPlus(true)
              app.toast('Suscripción de prueba activada. El pago con Stripe llega en la Fase 3')
            }}
            className="hy h-12 rounded-[12px] border-0 bg-ink text-[15px] font-semibold text-on-ink"
          >
            Suscribirme
          </button>
        )}
      </div>
    </Screen>
  )
}

const fmtDate = (d: string) => new Date(d + 'T12:00:00').toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })

/** Membresías con servidor: las mías y las de mis hijos, y los productos para pedir en recepción */
function LiveMemberships() {
  const app = useApp()
  const nav = useNavigate()
  const auth = useAuth()
  const family = useFamily(auth.profile?.id)
  const me = auth.profile ? [{ id: auth.profile.id, name: auth.profile.fullName }] : []
  const people = family.loading ? [] : [...me, ...(family.data ?? []).map((k) => ({ id: k.id, name: k.fullName }))]
  const m = useMemberships(people)
  const history = usePlanHistory(auth.profile?.id)
  const [tab, setTab] = useState<Tab>('membresias')
  const [choosing, setChoosing] = useState<Plan | null>(null)
  // Con todas las membresías activas, los productos se ocultan tras "Mejorar plan"
  const [upgrade, setUpgrade] = useState(false)

  const plans = app.plans.filter((p) => p.dbId && !p.isAddon && (tab === 'membresias' ? p.kind !== 'drop_in' : p.kind === 'drop_in'))
  const adults = plans.filter((p) => p.audience !== 'kids')
  const kids = plans.filter((p) => p.audience === 'kids')
  const mine = m.data?.[0]
  const addon = app.plans.find((p) => p.isAddon)
  const basePlan = mine?.status ? app.plans.find((p) => p.dbId === mine.status!.planId) : undefined
  const hasRecurring = !!basePlan && basePlan.autoRenew && basePlan.priceCents > 0
  const multi = (m.data?.length ?? 0) > 1

  const ask = async (plan: Plan, profileId: string, who: string) => {
    try {
      await requestPlan(plan.dbId!, profileId)
      app.toast(`Solicitud enviada: ${plan.name}${multi ? ` para ${who}` : ''}. Págala en recepción para activarla`)
      m.reload()
    } catch {
      app.toast('No se pudo enviar la solicitud')
    }
  }
  const choose = (plan: Plan) => {
    if (multi) setChoosing(plan)
    else if (mine) void ask(plan, mine.profileId, mine.name)
  }

  return (
    <Screen top={24} gap={16}>
      <div className="flex items-center gap-2">
        <BackButton label="Volver al perfil" to="/perfil" />
        <Title size={44}>Membresías</Title>
      </div>

      <section aria-labelledby="mis" className="flex flex-col gap-3">
        <h2 id="mis" className="m-0 text-[18px] font-bold">
          Mis membresías
        </h2>
        {m.data === null ? (
          <p className="m-0 text-[14px] text-muted">Cargando…</p>
        ) : (
          m.data.map((p) => (
            <MembershipCard
              key={p.profileId}
              p={p}
              showName={multi}
              onCancelRequest={async () => {
                if (!p.pending) return
                await cancelPlanRequest(p.pending.id).catch(() => undefined)
                app.toast('Solicitud retirada')
                m.reload()
              }}
            />
          ))
        )}
        {history.length > 0 && (
          <details className="rounded-[14px] bg-surface px-4 py-3">
            <summary className="hy-text cursor-pointer text-[14px] font-semibold">Tarifas anteriores</summary>
            <ul className="m-0 mt-2 flex list-none flex-col gap-1 p-0">
              {history.map((h) => (
                <li key={h.id} className="flex justify-between gap-3 text-[13px]">
                  <span className="font-medium">{h.planName}</span>
                  <span className="text-muted">
                    {fmtDate(h.startsOn)} – {h.endsOn ? fmtDate(h.endsOn) : 'hoy'}
                  </span>
                </li>
              ))}
            </ul>
          </details>
        )}
      </section>

      {m.data && m.data.every((p) => p.status) && !upgrade ? (
        <Btn variant="highlight" size="lg" block onClick={() => setUpgrade(true)}>
          Mejorar plan
        </Btn>
      ) : (
      <section aria-labelledby="productos" className="flex flex-col gap-3">
        <div className="flex items-baseline justify-between gap-3">
          <h2 id="productos" className="m-0 text-[18px] font-bold">
            {upgrade ? 'Cambiar de tarifa' : 'Productos disponibles'}
          </h2>
          {upgrade && (
            <button type="button" onClick={() => setUpgrade(false)} className="hy-text border-0 bg-transparent p-0 text-[14px] font-semibold text-ink">
              Cerrar
            </button>
          )}
        </div>
        <div className="flex gap-2">
          <FilterChip active={tab === 'membresias'} onClick={() => setTab('membresias')}>
            Membresías
          </FilterChip>
          <FilterChip active={tab === 'sueltas'} onClick={() => setTab('sueltas')}>
            Clases sueltas
          </FilterChip>
        </div>
        <p className="m-0 text-[13px] text-muted">Pídela aquí y págala en recepción (Bizum, transferencia o efectivo): recepción la activará. El pago desde la app llegará más adelante.</p>
        <div className="flex flex-col gap-[10px]">
          {adults.map((p) => (
            <PlanCard
              key={p.id}
              plan={p}
              current={!multi && mine?.status?.planId === p.dbId}
              requested={!multi && mine?.pending?.planId === p.dbId}
              label="Solicitar"
              onChoose={() => choose(p)}
            />
          ))}
        </div>
        {kids.length > 0 && (
          <>
            <Eyebrow>Infantil</Eyebrow>
            <div className="flex flex-col gap-[10px]">
              {kids.map((p) => (
                <PlanCard key={p.id} plan={p} current={false} label="Solicitar" onChoose={() => choose(p)} />
              ))}
            </div>
          </>
        )}
      </section>
      )}

      {addon && (
        <section aria-labelledby="itaca" className="flex flex-col gap-[10px] rounded-[18px] border border-accent/40 bg-surface px-5 py-4 text-ink">
          <div className="flex items-baseline justify-between gap-3">
            <h2 id="itaca" className="m-0 text-[22px] font-bold leading-none tracking-[-0.02em]">
              ITACA+
            </h2>
            <span className="text-[15px] font-bold">+ {planPrice(addon)}</span>
          </div>
          <p className="m-0 text-[14px] leading-[1.35]">{addon.description || 'Vídeos de las clases, técnicas sueltas y currículos.'}</p>
          {app.itacaPlus ? (
            <Btn block onClick={() => nav('/itaca')}>
              Activo · Ir a ITACA+
            </Btn>
          ) : mine?.addonPending ? (
            <div className="flex items-center justify-between gap-3 rounded-[12px] bg-warn-bg px-3 py-2 text-warn-fg">
              <span className="text-[13px] font-medium">Has pedido ITACA+. Pásate por recepción para pagarlo.</span>
              <button
                type="button"
                onClick={async () => {
                  await cancelPlanRequest(mine.addonPending!.id).catch(() => undefined)
                  app.toast('Solicitud retirada')
                  m.reload()
                }}
                className="hy-text shrink-0 border-0 bg-transparent p-0 text-[13px] font-semibold text-warn-fg underline"
              >
                Retirar
              </button>
            </div>
          ) : hasRecurring ? (
            <Btn block onClick={() => mine && void ask(addon, mine.profileId, mine.name)}>
              Solicitar ITACA+
            </Btn>
          ) : (
            <>
              <Btn block disabled>
                Solicitar ITACA+
              </Btn>
              <p className="m-0 text-[13px] text-muted">
                {mine?.status ? `Tu tarifa (${mine.status.planName}) no es mensual. ` : ''}ITACA+ se suma a una tarifa mensual de pago: necesitas tener una activa.
              </p>
            </>
          )}
        </section>
      )}

      {choosing && m.data && (
        <Sheet open onClose={() => setChoosing(null)} title={`¿Para quién es ${choosing.name}?`}>
          {m.data.map((p) => (
            <Btn
              key={p.profileId}
              variant="soft"
              block
              onClick={() => {
                const plan = choosing
                setChoosing(null)
                void ask(plan, p.profileId, p.name.split(' ')[0])
              }}
            >
              {p.profileId === m.data![0].profileId ? `Para mí (${p.name.split(' ')[0]})` : p.name}
            </Btn>
          ))}
        </Sheet>
      )}
    </Screen>
  )
}

function MembershipCard({ p, showName, onCancelRequest }: { p: PersonMembership; showName: boolean; onCancelRequest: () => void }) {
  const usage = planUsageText(p.status)
  return (
    <Card radius={20} className={p.status ? 'gap-2 border border-accent/40 p-4' : 'gap-2 p-4'}>
      {showName && <Eyebrow>{p.name}</Eyebrow>}
      {p.status ? (
        <>
          <div className="flex items-baseline justify-between gap-3">
            <span className="text-[22px] font-bold">{p.status.planName}</span>
            <Chip tone="ok" small>
              Activa
            </Chip>
          </div>
          <span className="text-[14px] text-ink-2">{p.status.endsOn ? `Válida hasta el ${fmtDate(p.status.endsOn)}` : 'Se renueva cada mes'}</span>
          {usage && <span className="text-[14px] font-semibold">{usage}</span>}
        </>
      ) : (
        <>
          <span className="text-[17px] font-bold">Sin membresía activa</span>
          <span className="text-[13px] text-muted">Solicita una abajo y págala en recepción. Mientras tanto se puede reservar con normalidad.</span>
        </>
      )}
      {p.rejected && !p.pending && (
        <p className="m-0 mt-1 rounded-[12px] bg-err-bg px-3 py-2 text-[13px] font-medium text-err-fg">
          Recepción no ha aprobado {p.rejected.planName}
          {p.rejected.reason ? `: ${p.rejected.reason}` : '.'}
        </p>
      )}
      {p.pending && (
        <div className="mt-1 flex items-center justify-between gap-3 rounded-[12px] bg-warn-bg px-3 py-2 text-warn-fg">
          <span className="text-[13px] font-medium">Has pedido {p.pending.planName}. Pásate por recepción para pagarla.</span>
          <button type="button" onClick={onCancelRequest} className="hy-text shrink-0 border-0 bg-transparent p-0 text-[13px] font-semibold text-warn-fg underline">
            Retirar
          </button>
        </div>
      )}
    </Card>
  )
}
