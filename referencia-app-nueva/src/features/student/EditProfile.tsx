import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router'
import { Screen } from '../../components/Layout'
import { BackButton, BeltBar, Btn, Eyebrow, Title, cx } from '../../components/ui'
import { BELT_LABEL, BELTS, MY_PROGRESS } from '../../lib/data'
import { ymd } from '../../lib/dates'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import type { Belt } from '../../lib/types'
import { useAuth } from '../auth/AuthProvider'
import { ProfilePhoto } from './ProfilePhoto'

const inputCls = 'h-12 w-full rounded-[14px] border-[1.5px] border-border bg-bg px-3 text-[16px] text-ink'
const labelCls = 'flex flex-col gap-1 text-[12px] font-semibold text-muted'

/** Editar mis datos y mi cinturón */
export function EditProfile() {
  const app = useApp()
  const auth = useAuth()
  const nav = useNavigate()
  const live = auth.mode === 'live'
  const p = auth.profile
  const demo = app.state.demoProfile

  const [name, setName] = useState(live ? p?.fullName ?? '' : demo?.name ?? app.me.name)
  const [birthDate, setBirthDate] = useState((live ? p?.birthDate : demo?.birthDate) ?? '')
  const [phone, setPhone] = useState((live ? p?.phone : demo?.phone) ?? '')

  // Cinturón: el alumno puede indicarlo mientras el personal no haya registrado una graduación
  const locked = live && !!auth.rank && !auth.rank.selfDeclared
  const startBelt: Belt = live ? auth.rank?.belt ?? 'blanco' : demo?.belt ?? app.me.belt
  const startStripes = live ? auth.rank?.stripes ?? 0 : demo?.stripes ?? app.me.stripes
  const [belt, setBelt] = useState<Belt>(startBelt)
  const [stripes, setStripes] = useState(startStripes)
  const [since, setSince] = useState((live ? auth.rank?.promotedAt : demo?.rankSince) ?? '')
  const rankChanged = belt !== startBelt || stripes !== startStripes || (since || '') !== ((live ? auth.rank?.promotedAt : demo?.rankSince) ?? '')

  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const maxStripes = belt === 'negro' ? 6 : 4

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    const n = name.trim()
    if (!n) return setError('Escribe tu nombre')
    if (n.length > 80) return setError('El nombre es demasiado largo (máximo 80 caracteres)')
    if (birthDate && birthDate > ymd(new Date())) return setError('La fecha de nacimiento no puede ser futura')
    if (since && since > ymd(new Date())) return setError('La fecha del cinturón no puede ser futura')
    setSaving(true)
    setError(null)
    try {
      if (live && supabase && p) {
        const upd = await supabase
          .from('profiles')
          .update({
            full_name: n,
            birth_date: birthDate || null,
            phone: phone.trim() || null,
          })
          .eq('id', p.id)
        if (upd.error) throw new Error(upd.error.message)
        if (!locked && rankChanged && auth.memberships[0]) {
          const r = await supabase.rpc('set_my_rank', {
            p_gym: auth.memberships[0].gymId,
            p_belt: belt,
            p_stripes: stripes,
            p_since: since || null,
          })
          if (r.error) throw new Error(r.error.message)
        }
        auth.refreshProfile()
      } else {
        app.setDemoProfile({
          name: n,
          belt,
          stripes,
          rankSince: since || null,
          birthDate: birthDate || null,
          phone: phone.trim() || null,
          emergencyName: demo?.emergencyName ?? null,
          emergencyPhone: demo?.emergencyPhone ?? null,
        })
      }
      app.toast('Perfil guardado')
      nav('/perfil')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo guardar')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Screen gap={16}>
      <div className="flex items-center gap-3">
        <BackButton label="Volver al perfil" to="/perfil" />
        <Title size={40}>Editar perfil</Title>
      </div>

      <form onSubmit={submit} className="flex flex-col gap-5">
        <div className="flex items-center gap-4">
          <ProfilePhoto name={name || app.me.name} />
          <p className="m-0 text-[13px] text-muted">Toca la foto para cambiarla.</p>
        </div>

        <fieldset className="m-0 flex flex-col gap-3 border-0 p-0">
          <legend className="mb-2 p-0">
            <Eyebrow>Tus datos</Eyebrow>
          </legend>
          <label className={labelCls}>
            Nombre y apellidos
            <input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" maxLength={80} required />
          </label>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <label className={labelCls}>
              Fecha de nacimiento
              <input className={inputCls} type="date" value={birthDate} max={ymd(new Date())} onChange={(e) => setBirthDate(e.target.value)} autoComplete="bday" />
            </label>
            <label className={labelCls}>
              Teléfono
              <input className={inputCls} type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} autoComplete="tel" maxLength={30} />
            </label>
          </div>
        </fieldset>

        <fieldset className="m-0 flex flex-col gap-3 border-0 p-0">
          <legend className="mb-2 p-0">
            <Eyebrow>Cinturón</Eyebrow>
          </legend>
          <BeltBar belt={belt} stripes={stripes} height={26} />
          {locked ? (
            <p className="m-0 rounded-2xl bg-surface px-4 py-3 text-[13px] text-ink-2">
              Tu cinturón lo ha registrado tu profesor ({BELT_LABEL[belt].toLowerCase()}, {stripes} {stripes === 1 ? 'grado' : 'grados'}). Si hay un error, pídele que lo cambie.
            </p>
          ) : (
            <>
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
                    className={cx(
                      'hy h-11 rounded-full border-[1.5px] px-4 text-[14px]',
                      belt === b ? 'border-ink bg-ink font-semibold text-on-ink' : 'border-border bg-bg font-medium text-ink',
                    )}
                  >
                    {BELT_LABEL[b]}
                  </button>
                ))}
              </div>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <label className={labelCls}>
                  Grados
                  <select className={inputCls} value={stripes} onChange={(e) => setStripes(Number(e.target.value))}>
                    {Array.from({ length: maxStripes + 1 }, (_, i) => (
                      <option key={i} value={i}>
                        {i === 0 ? 'Sin grados' : `${i} ${i === 1 ? 'grado' : 'grados'}`}
                      </option>
                    ))}
                  </select>
                </label>
                <label className={labelCls}>
                  Desde (aproximado)
                  <input className={inputCls} type="date" value={since} max={ymd(new Date())} onChange={(e) => setSince(e.target.value)} />
                </label>
              </div>
              <p className="m-0 text-[12px] text-muted">
                Puedes indicarlo tú mientras tu profesor no lo registre. Cuando lo haga, solo él podrá cambiarlo.
                {!live && ` (Modo demo: objetivo provisional de ${MY_PROGRESS.classesRequired} clases por grado.)`}
              </p>
            </>
          )}
        </fieldset>

        {error && (
          <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
            {error}
          </p>
        )}
        <Btn type="submit" variant="accent" size="lg" block disabled={saving}>
          {saving ? 'Guardando…' : 'Guardar'}
        </Btn>
      </form>
    </Screen>
  )
}
