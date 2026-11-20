import { useEffect, useState, type FormEvent, type ReactNode } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router'
import { Screen } from '../../components/Layout'
import { Avatar, BackButton, BeltBar, Btn, Card, EmptyState, Eyebrow, Sheet, Title, cx } from '../../components/ui'
import { IconAt, IconChat, IconChevron, IconGlobe, IconMail, IconPhone, IconPin } from '../../components/icons'
import { BELT_LABEL, BELTS, MY_PROGRESS } from '../../lib/data'
import { ymd } from '../../lib/dates'
import { initials } from '../../lib/logic'
import {
  DEMO_CONTACT,
  ageOn,
  prettyPhone,
  saveBilling,
  useBilling,
  useFamily,
  useGymContact,
  usePromotions,
  type Billing,
  type GymContact,
} from '../../lib/profileApi'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import type { Belt } from '../../lib/types'
import { useAuth } from '../auth/AuthProvider'
import { useMyAvatar } from '../auth/useMyAvatar'

const inputCls = 'h-12 w-full rounded-[12px] border border-border bg-surface-2 px-3 text-[16px] text-ink'
const labelCls = 'flex flex-col gap-1 text-[13px] font-medium text-ink-2'
const MONTHS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic']
const fmtDate = (s: string) => {
  const [y, m, d] = s.split('-').map(Number)
  return `${d} ${MONTHS[m - 1]} ${y}`
}

function Header({ title, back = '/perfil' }: { title: string; back?: string }) {
  return (
    <div className="flex items-center gap-2">
      <BackButton label="Volver" to={back} />
      <Title size={40}>{title}</Title>
    </div>
  )
}

function ErrorNote({ children }: { children: ReactNode }) {
  return (
    <p role="alert" className="m-0 rounded-[12px] bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
      {children}
    </p>
  )
}

function DemoNote({ what }: { what: string }) {
  return <Card className="p-4 text-[14px] text-muted">En el modo demo no hay servidor. Con la app conectada, aquí {what}.</Card>
}

// ---------------------------------------------------------------- Perfiles

/** Perfiles de la cuenta: el mío y los de los menores a mi cargo */
export function FamilyProfiles() {
  const app = useApp()
  const auth = useAuth()
  const live = auth.mode === 'live'
  const avatar = useMyAvatar()
  const family = useFamily(live ? auth.profile?.id : undefined)
  const [adding, setAdding] = useState(false)
  const name = auth.profile?.fullName ?? app.me.name

  return (
    <Screen top={24} gap={18}>
      <Header title="Perfiles" />
      <p className="m-0 text-[14px] text-ink-2">Desde tu cuenta puedes gestionar a tus hijos menores de edad: sus datos, su cinturón y sus reservas.</p>

      <div className="flex flex-col rounded-[18px] bg-surface px-4 py-1">
        <Link to="/perfil/editar" className="hy-text flex min-h-[64px] items-center gap-3 border-b border-line py-2 text-ink no-underline last:border-0">
          <Avatar text={initials(name)} src={avatar} size={44} tone="grey" />
          <span className="flex flex-1 flex-col">
            <span className="text-[16px] font-semibold">{name}</span>
            <span className="text-[13px] text-muted">Tú · titular de la cuenta</span>
          </span>
          <IconChevron size={18} className="text-muted" />
        </Link>
        {(family.data ?? []).map((k) => (
          <Link key={k.id} to={`/perfil/perfiles/${k.id}`} className="hy-text flex min-h-[64px] items-center gap-3 border-b border-line py-2 text-ink no-underline last:border-0">
            <Avatar text={initials(k.fullName)} size={44} tone="grey" />
            <span className="flex flex-1 flex-col">
              <span className="text-[16px] font-semibold">{k.fullName}</span>
              <span className="text-[13px] text-muted">{k.birthDate ? `${ageOn(k.birthDate)} años` : 'Menor a tu cargo'}</span>
            </span>
            <IconChevron size={18} className="text-muted" />
          </Link>
        ))}
      </div>
      {family.error && <ErrorNote>No se pudieron cargar los perfiles.</ErrorNote>}

      {live ? (
        <Btn variant="soft" block onClick={() => setAdding(true)}>
          Añadir perfil de un menor
        </Btn>
      ) : (
        <DemoNote what="añades a tus hijos" />
      )}
      <p className="m-0 text-[12px] text-muted">Los mayores de 14 años pueden tener su propia cuenta. Para quitar un perfil, pídelo en recepción.</p>

      {adding && (
        <AddMinorSheet
          onClose={() => setAdding(false)}
          onAdded={() => {
            setAdding(false)
            family.reload()
            app.toast('Perfil añadido')
          }}
        />
      )}
    </Screen>
  )
}

function AddMinorSheet({ onClose, onAdded }: { onClose: () => void; onAdded: () => void }) {
  const auth = useAuth()
  const [name, setName] = useState('')
  const [birth, setBirth] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase || !auth.memberships[0]) return
    if (!name.trim()) return setError('Escribe su nombre')
    if (!birth) return setError('Indica su fecha de nacimiento')
    setBusy(true)
    setError('')
    const { error } = await supabase.rpc('add_minor', { p_gym: auth.memberships[0].gymId, p_full_name: name.trim(), p_birth_date: birth })
    setBusy(false)
    if (error) setError(error.message.includes('18') ? 'Solo se pueden añadir menores de 18 años.' : 'No se pudo añadir. Inténtalo de nuevo.')
    else onAdded()
  }

  return (
    <Sheet open onClose={onClose} title="Añadir perfil">
      <form onSubmit={submit} className="flex flex-col gap-3">
        <label className={labelCls}>
          Nombre y apellidos
          <input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} maxLength={80} required />
        </label>
        <label className={labelCls}>
          Fecha de nacimiento
          <input className={inputCls} type="date" value={birth} max={ymd(new Date())} onChange={(e) => setBirth(e.target.value)} required />
        </label>
        {error && <ErrorNote>{error}</ErrorNote>}
        <Btn type="submit" variant="accent" block disabled={busy}>
          {busy ? 'Añadiendo…' : 'Añadir'}
        </Btn>
      </form>
    </Sheet>
  )
}

/** Editar el perfil de un menor a mi cargo */
export function MinorProfile() {
  const { id } = useParams()
  const app = useApp()
  const auth = useAuth()
  const nav = useNavigate()
  const family = useFamily(auth.profile?.id)
  const kid = family.data?.find((k) => k.id === id)
  const gymId = auth.memberships[0]?.gymId

  const [name, setName] = useState('')
  const [birth, setBirth] = useState('')
  const [emName, setEmName] = useState('')
  const [emPhone, setEmPhone] = useState('')
  const [rank, setRank] = useState<{ belt: Belt; stripes: number; locked: boolean } | null>(null)
  const [belt, setBelt] = useState<Belt>('blanco')
  const [stripes, setStripes] = useState(0)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!kid) return
    setName(kid.fullName)
    setBirth(kid.birthDate ?? '')
    setEmName(kid.emergencyName ?? '')
    setEmPhone(kid.emergencyPhone ?? '')
  }, [kid])

  useEffect(() => {
    if (!supabase || !id || !gymId) return
    supabase.rpc('current_rank', { p_profile: id, p_gym: gymId }).then(({ data }) => {
      const r = (data as { belt: Belt; stripes: number; self_declared: boolean }[] | null)?.[0]
      const v = r ? { belt: r.belt, stripes: r.stripes, locked: !r.self_declared } : { belt: 'blanco' as Belt, stripes: 0, locked: false }
      setRank(v)
      setBelt(v.belt)
      setStripes(v.stripes)
    })
  }, [id, gymId])

  if (family.loading) return <Screen top={24}><Header title="Perfil" back="/perfil/perfiles" /></Screen>
  if (!kid) {
    return (
      <Screen top={24} gap={18}>
        <Header title="Perfil" back="/perfil/perfiles" />
        <EmptyState title="Perfil no encontrado" text="Este perfil no está a tu cargo." />
      </Screen>
    )
  }

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase || !gymId) return
    if (!name.trim()) return setError('Escribe su nombre')
    setBusy(true)
    setError('')
    try {
      const upd = await supabase
        .from('profiles')
        .update({ full_name: name.trim(), birth_date: birth || null, emergency_contact_name: emName.trim() || null, emergency_contact_phone: emPhone.trim() || null })
        .eq('id', kid.id)
      if (upd.error) throw upd.error
      if (rank && !rank.locked && (belt !== rank.belt || stripes !== rank.stripes)) {
        const r = await supabase.rpc('set_my_rank', { p_gym: gymId, p_belt: belt, p_stripes: stripes, p_profile: kid.id })
        if (r.error) throw r.error
      }
      app.toast('Perfil guardado')
      nav('/perfil/perfiles')
    } catch {
      setError('No se pudo guardar. Revisa los datos e inténtalo de nuevo.')
      setBusy(false)
    }
  }

  return (
    <Screen top={24} gap={18}>
      <Header title={kid.fullName.split(' ')[0]} back="/perfil/perfiles" />
      <form onSubmit={submit} className="flex flex-col gap-5">
        <Card className="gap-3 p-4">
          <Eyebrow>Datos</Eyebrow>
          <label className={labelCls}>
            Nombre y apellidos
            <input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} maxLength={80} required />
          </label>
          <label className={labelCls}>
            Fecha de nacimiento
            <input className={inputCls} type="date" value={birth} max={ymd(new Date())} onChange={(e) => setBirth(e.target.value)} />
          </label>
        </Card>
        <Card className="gap-3 p-4">
          <Eyebrow>Contacto de emergencia</Eyebrow>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className={labelCls}>
              Nombre
              <input className={inputCls} value={emName} onChange={(e) => setEmName(e.target.value)} maxLength={80} />
            </label>
            <label className={labelCls}>
              Teléfono
              <input className={inputCls} type="tel" value={emPhone} onChange={(e) => setEmPhone(e.target.value)} maxLength={30} />
            </label>
          </div>
        </Card>
        {rank && (
          <Card className="gap-3 p-4">
            <Eyebrow>Cinturón</Eyebrow>
            <BeltBar belt={belt} stripes={stripes} />
            {rank.locked ? (
              <p className="m-0 text-[13px] text-muted">Lo ha registrado su profesor. Si hay un error, pídele que lo cambie.</p>
            ) : (
              <BeltPicker belt={belt} stripes={stripes} onBelt={setBelt} onStripes={setStripes} />
            )}
            <Link to={`/perfil/promociones?perfil=${kid.id}`} className="text-[14px] font-semibold text-ink">
              Ver historial de cinturones
            </Link>
          </Card>
        )}
        {error && <ErrorNote>{error}</ErrorNote>}
        <Btn type="submit" variant="accent" size="lg" block disabled={busy}>
          {busy ? 'Guardando…' : 'Guardar'}
        </Btn>
      </form>
    </Screen>
  )
}

function BeltPicker({ belt, stripes, onBelt, onStripes }: { belt: Belt; stripes: number; onBelt: (b: Belt) => void; onStripes: (n: number) => void }) {
  const max = belt === 'negro' ? 6 : 4
  return (
    <>
      <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="Color del cinturón">
        {BELTS.map((b) => (
          <button
            key={b}
            type="button"
            role="radio"
            aria-checked={belt === b}
            onClick={() => {
              onBelt(b)
              if (stripes > (b === 'negro' ? 6 : 4)) onStripes(0)
            }}
            className={cx('hy h-10 rounded-full border-0 px-4 text-[14px]', belt === b ? 'bg-ink font-semibold text-on-ink' : 'bg-surface-2 font-medium text-ink')}
          >
            {BELT_LABEL[b]}
          </button>
        ))}
      </div>
      <label className={labelCls}>
        Grados
        <select className={inputCls} value={stripes} onChange={(e) => onStripes(Number(e.target.value))}>
          {Array.from({ length: max + 1 }, (_, i) => (
            <option key={i} value={i}>
              {i === 0 ? 'Sin grados' : `${i} ${i === 1 ? 'grado' : 'grados'}`}
            </option>
          ))}
        </select>
      </label>
    </>
  )
}

// ---------------------------------------------------------------- Promociones

const rankLabel = (belt: Belt, stripes: number) =>
  stripes === 0 ? `Cinturón ${BELT_LABEL[belt].toLowerCase()}` : `${BELT_LABEL[belt]} · ${stripes} ${stripes === 1 ? 'grado' : 'grados'}`

/** Cinturón actual e historial de graduaciones (mío o de un menor a mi cargo con ?perfil=) */
export function Promotions() {
  const app = useApp()
  const auth = useAuth()
  const live = auth.mode === 'live'
  const [params] = useSearchParams()
  const family = useFamily(live ? auth.profile?.id : undefined)
  const kid = family.data?.find((k) => k.id === params.get('perfil'))
  const profileId = params.get('perfil') ?? auth.profile?.id
  const promos = usePromotions(live ? profileId : undefined, auth.memberships[0]?.gymId)

  const items = live
    ? (promos.data ?? []).map((p) => ({ id: p.id, title: rankLabel(p.belt, p.stripes), date: fmtDate(p.promotedAt), belt: p.belt, stripes: p.stripes, sub: p.selfDeclared ? 'Indicado por ti' : p.note || 'Registrado por el gimnasio' }))
    : MY_PROGRESS.history.map((h, i) => ({ id: String(i), title: h.label, date: h.date, belt: app.me.belt, stripes: Math.max(0, app.me.stripes - i), sub: 'Registrado por el gimnasio' }))
  const current = items[0]

  return (
    <Screen top={24} gap={18}>
      <Header title="Promociones" back={kid ? `/perfil/perfiles/${kid.id}` : '/perfil'} />
      {kid && <p className="-mt-2 m-0 text-[14px] text-muted">{kid.fullName}</p>}

      {promos.loading ? null : !current ? (
        <EmptyState
          title="Aún no hay cinturón registrado"
          text={kid ? 'Indícalo en su perfil o pídele a su profesor que lo registre.' : 'Indícalo en Editar perfil o pídele a tu profesor que lo registre.'}
          action={!kid ? <Link to="/perfil/editar" className="text-[14px] font-semibold text-ink">Indicar mi cinturón</Link> : undefined}
        />
      ) : (
        <>
          <Card radius={24} className="gap-3 p-5">
            <Eyebrow>Cinturón actual</Eyebrow>
            <span className="text-[22px] font-bold">{current.title}</span>
            <BeltBar belt={current.belt} stripes={current.stripes} height={26} />
            <span className="text-[13px] text-muted">Desde el {current.date}</span>
          </Card>

          <section aria-labelledby="historial" className="flex flex-col gap-3">
            <h2 id="historial" className="m-0 text-[18px] font-bold">
              Historial
            </h2>
            <ol className="m-0 flex list-none flex-col p-0">
              {items.map((it, i) => (
                <li key={it.id} className="relative flex gap-4 pb-5 last:pb-0">
                  {i < items.length - 1 && <span aria-hidden="true" className="absolute left-[7px] top-5 bottom-0 w-[2px] bg-line" />}
                  <span aria-hidden="true" className={cx('relative mt-1 h-4 w-4 shrink-0 rounded-full border-2', i === 0 ? 'border-accent bg-accent' : 'border-border bg-bg')} />
                  <span className="flex flex-1 flex-col gap-1">
                    <span className="flex items-baseline justify-between gap-3">
                      <span className="text-[16px] font-semibold">{it.title}</span>
                      <span className="shrink-0 font-mono text-[12px] text-muted">{it.date}</span>
                    </span>
                    <span className="text-[13px] text-muted">{it.sub}</span>
                  </span>
                </li>
              ))}
            </ol>
          </section>
        </>
      )}
      {promos.error && <ErrorNote>No se pudo cargar el historial.</ErrorNote>}
    </Screen>
  )
}

// ---------------------------------------------------------------- Emergencia

export function EmergencyContact() {
  const app = useApp()
  const auth = useAuth()
  const nav = useNavigate()
  const live = auth.mode === 'live'
  const demo = app.state.demoProfile
  const [name, setName] = useState((live ? auth.profile?.emergencyName : demo?.emergencyName) ?? '')
  const [phone, setPhone] = useState((live ? auth.profile?.emergencyPhone : demo?.emergencyPhone) ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError('')
    if (live && supabase && auth.profile) {
      const { error } = await supabase
        .from('profiles')
        .update({ emergency_contact_name: name.trim() || null, emergency_contact_phone: phone.trim() || null })
        .eq('id', auth.profile.id)
      if (error) {
        setBusy(false)
        return setError('No se pudo guardar. Inténtalo de nuevo.')
      }
      auth.refreshProfile()
    } else {
      app.setDemoProfile({
        name: demo?.name ?? app.me.name,
        belt: demo?.belt ?? app.me.belt,
        stripes: demo?.stripes ?? app.me.stripes,
        rankSince: demo?.rankSince ?? null,
        birthDate: demo?.birthDate ?? null,
        phone: demo?.phone ?? null,
        emergencyName: name.trim() || null,
        emergencyPhone: phone.trim() || null,
      })
    }
    app.toast('Contacto de emergencia guardado')
    nav('/perfil')
  }

  return (
    <Screen top={24} gap={18}>
      <Header title="Contacto de emergencia" />
      <p className="m-0 text-[14px] text-ink-2">A quién avisamos si te pasa algo en el tatami. Solo lo ve el personal del gimnasio.</p>
      <form onSubmit={submit} className="flex flex-col gap-4">
        <Card className="gap-3 p-4">
          <label className={labelCls}>
            Nombre
            <input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} maxLength={80} autoComplete="off" placeholder="Por ejemplo, tu pareja o tu madre" />
          </label>
          <label className={labelCls}>
            Teléfono
            <input className={inputCls} type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} maxLength={30} autoComplete="off" />
          </label>
        </Card>
        {error && <ErrorNote>{error}</ErrorNote>}
        <Btn type="submit" variant="accent" size="lg" block disabled={busy}>
          {busy ? 'Guardando…' : 'Guardar'}
        </Btn>
      </form>
    </Screen>
  )
}

// ---------------------------------------------------------------- Facturación

const EMPTY_BILLING: Billing = { name: '', taxId: '', address: '', postalCode: '', city: '' }

export function BillingSettings() {
  const app = useApp()
  const auth = useAuth()
  const live = auth.mode === 'live'
  const billing = useBilling(live ? auth.profile?.id : undefined)
  const [form, setForm] = useState<Billing>(EMPTY_BILLING)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (billing.data) setForm(billing.data)
  }, [billing.data])

  const set = (k: keyof Billing) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }))
  const changed = JSON.stringify(form) !== JSON.stringify(billing.data ?? EMPTY_BILLING)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!auth.profile) return
    setBusy(true)
    setError('')
    try {
      await saveBilling(auth.profile.id, form)
      billing.reload()
      app.toast('Datos de facturación guardados')
    } catch {
      setError('No se pudo guardar. Revisa los datos e inténtalo de nuevo.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Screen top={24} gap={18}>
      <Header title="Facturación y pago" />

      <Card className="gap-2 p-4">
        <Eyebrow>Forma de pago</Eyebrow>
        <span className="text-[16px] font-semibold">Pago en recepción</span>
        <p className="m-0 text-[14px] text-muted">Bizum, transferencia o efectivo. El pago con tarjeta desde la app llegará más adelante.</p>
      </Card>

      {live ? (
        <form onSubmit={submit} className="flex flex-col gap-4">
          <Card className="gap-3 p-4">
            <Eyebrow>Datos para la factura (opcional)</Eyebrow>
            <label className={labelCls}>
              Nombre o razón social
              <input className={inputCls} value={form.name} onChange={set('name')} maxLength={120} autoComplete="name" />
            </label>
            <label className={labelCls}>
              NIF
              <input className={inputCls} value={form.taxId} onChange={set('taxId')} maxLength={20} autoCapitalize="characters" autoComplete="off" />
            </label>
            <label className={labelCls}>
              Dirección
              <input className={inputCls} value={form.address} onChange={set('address')} maxLength={200} autoComplete="street-address" />
            </label>
            <div className="grid grid-cols-[minmax(0,2fr)_minmax(0,3fr)] gap-3">
              <label className={labelCls}>
                Código postal
                <input className={inputCls} value={form.postalCode} onChange={set('postalCode')} maxLength={10} inputMode="numeric" autoComplete="postal-code" />
              </label>
              <label className={labelCls}>
                Ciudad
                <input className={inputCls} value={form.city} onChange={set('city')} maxLength={80} autoComplete="address-level2" />
              </label>
            </div>
            <p className="m-0 text-[12px] text-muted">Solo hace falta si necesitas factura a tu nombre o al de tu empresa.</p>
          </Card>
          {error && <ErrorNote>{error}</ErrorNote>}
          <Btn type="submit" variant="accent" size="lg" block disabled={busy || !changed || billing.loading}>
            {busy ? 'Guardando…' : 'Guardar'}
          </Btn>
        </form>
      ) : (
        <DemoNote what="guardas tus datos de facturación" />
      )}
    </Screen>
  )
}

// ---------------------------------------------------------------- Soporte

function ContactRow({ href, icon: Icon, label, value, external }: { href: string; icon: typeof IconMail; label: string; value: string; external?: boolean }) {
  return (
    <a
      href={href}
      {...(external ? { target: '_blank', rel: 'noopener noreferrer' } : {})}
      className="hy-text flex min-h-[64px] items-center gap-4 border-b border-line py-2 text-ink no-underline last:border-0"
    >
      <Icon size={22} className="shrink-0 text-ink-2" />
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="text-[13px] text-muted">{label}</span>
        <span className="break-words text-[16px] font-medium">{value}</span>
      </span>
      <IconChevron size={18} className="text-muted" />
    </a>
  )
}

export function Support() {
  const auth = useAuth()
  const live = auth.mode === 'live'
  const q = useGymContact(live ? auth.memberships[0]?.gymId : undefined)
  const c: GymContact = live ? q.data ?? {} : DEMO_CONTACT
  const gym = auth.memberships[0]?.gymName ?? 'ITACA Jiu Jitsu'
  const subject = encodeURIComponent(`Consulta desde la app · ${auth.profile?.fullName ?? ''}`.trim())

  return (
    <Screen top={24} gap={18}>
      <Header title="Soporte" />
      <p className="m-0 text-[14px] text-ink-2">¿Dudas con tu cuota, una reserva o la app? Escribe a {gym} o pásate por recepción.</p>
      {q.loading ? null : Object.keys(c).length === 0 ? (
        <EmptyState title="Sin datos de contacto" text="Pregunta en recepción." />
      ) : (
        <div className="flex flex-col rounded-[18px] bg-surface px-4 py-1">
          {c.whatsapp && <ContactRow href={`https://wa.me/${c.whatsapp}`} icon={IconChat} label="WhatsApp" value={prettyPhone(c.whatsapp)} external />}
          {c.email && <ContactRow href={`mailto:${c.email}?subject=${subject}`} icon={IconMail} label="Correo" value={c.email} />}
          {c.phone && <ContactRow href={`tel:${c.phone}`} icon={IconPhone} label="Teléfono" value={prettyPhone(c.phone)} />}
          {c.address && (
            <ContactRow href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(c.address)}`} icon={IconPin} label="Dirección" value={c.address} external />
          )}
          {c.instagram && <ContactRow href={`https://www.instagram.com/${c.instagram}/`} icon={IconAt} label="Instagram" value={`@${c.instagram}`} external />}
          {c.web && <ContactRow href={c.web} icon={IconGlobe} label="Web" value={c.web.replace(/^https?:\/\/(www\.)?/, '')} external />}
        </div>
      )}
      {q.error && <ErrorNote>No se pudo cargar el contacto.</ErrorNote>}
    </Screen>
  )
}

// ---------------------------------------------------------------- Documentos

export function Documents() {
  return (
    <Screen top={24} gap={18}>
      <Header title="Documentos" />
      <EmptyState title="Aún no hay documentos" text="Aquí verás las normas del gimnasio y los documentos que firmes, como la autorización para los menores." />
    </Screen>
  )
}
