import { useState, type FormEvent, type ReactNode } from 'react'
import { BrandMark } from '../../components/BrandMark'
import { Cover } from './Cover'
import { Link, Navigate, useLocation, useNavigate } from 'react-router'
import { Frame } from '../../components/Layout'
import { Btn, Title } from '../../components/ui'
import { supabase } from '../../lib/supabase'
import { useAuth } from './AuthProvider'

export const MIN_PASSWORD = 8

const inputCls =
  'h-[52px] w-full rounded-[12px] border border-border bg-surface px-4 text-[16px] text-ink placeholder:text-muted focus:border-ink focus:outline-none'
const labelCls = 'flex flex-col gap-2 text-[13px] font-medium text-ink-2'

/** Traduce los errores de Supabase Auth a mensajes claros */
export function authError(e: { message?: string; status?: number; code?: string } | null): string {
  if (!e) return ''
  const m = (e.message ?? '').toLowerCase()
  if (e.status === 429 || m.includes('rate limit') || m.includes('only request this after')) return 'Demasiados intentos. Espera un minuto y vuelve a probar.'
  if (m.includes('invalid login credentials')) return 'Correo o contraseña incorrectos.'
  if (m.includes('email not confirmed')) return 'Confirma tu correo: te enviamos un enlace al registrarte.'
  if (m.includes('already registered') || m.includes('already been registered')) return 'Ya hay una cuenta con ese correo. Entra o recupera la contraseña.'
  if (m.includes('password should be at least') || m.includes('weak')) return `La contraseña debe tener al menos ${MIN_PASSWORD} caracteres.`
  if (m.includes('same password') || m.includes('different from the old')) return 'La nueva contraseña debe ser distinta de la anterior.'
  if (m.includes('signups not allowed')) return 'El registro está cerrado. Pide acceso en recepción.'
  if (m.includes('fetch') || m.includes('network')) return 'Sin conexión. Comprueba la red y vuelve a intentarlo.'
  return 'No se ha podido completar. Vuelve a intentarlo.'
}

// La portada se ve una vez por sesión del navegador
const COVER_KEY = 'itaca-portada-vista'
const coverSeen = () => {
  try {
    return sessionStorage.getItem(COVER_KEY) === '1'
  } catch {
    return false
  }
}
const markCoverSeen = () => {
  try {
    sessionStorage.setItem(COVER_KEY, '1')
  } catch {
    /* sin almacenamiento: se volverá a ver */
  }
}

function AuthShell({ title, subtitle, children, footer, reveal }: { title: string; subtitle?: string; children: ReactNode; footer?: ReactNode; reveal?: boolean }) {
  return (
    <Frame>
      <div
        className={`flex w-full flex-1 flex-col px-5 pb-10 md:mx-auto md:max-w-[420px] md:justify-center ${reveal ? 'itaca-reveal' : ''}`}
        style={{ paddingTop: 'calc(56px + env(safe-area-inset-top))' }}
      >
        <div className="mb-8 flex items-center gap-3">
          <BrandMark size={44} className="text-ink" />
          <span className="flex flex-col leading-tight">
            <span className="text-[17px] font-bold tracking-[0.18em]">ITACA</span>
            <span className="font-mono text-[10px] uppercase tracking-[0.12em] text-muted">Jiu Jitsu</span>
          </span>
        </div>
        <div className="mb-6 flex flex-col gap-2">
          <Title>{title}</Title>
          {subtitle && <p className="m-0 text-[15px] text-ink-2">{subtitle}</p>}
        </div>
        {children}
        {footer && <div className="mt-8 text-center text-[14px] text-ink-2">{footer}</div>}
      </div>
    </Frame>
  )
}

function ErrorBox({ text }: { text: string }) {
  if (!text) return null
  return (
    <p role="alert" className="m-0 rounded-[12px] bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
      {text}
    </p>
  )
}

/** Entrar: con contraseña o con un enlace al correo */
export function Login() {
  const auth = useAuth()
  const [mode, setMode] = useState<'password' | 'link'>('password')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [sent, setSent] = useState(false)
  const [error, setError] = useState('')
  const [cover, setCover] = useState(() => !coverSeen())
  const [revealed, setRevealed] = useState(false)

  if (auth.mode === 'demo' || auth.session) return <Navigate to="/" replace />
  if (cover)
    return (
      <Cover
        onDone={() => {
          markCoverSeen()
          setCover(false)
          setRevealed(true)
        }}
      />
    )

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase) return
    setBusy(true)
    setError('')
    if (mode === 'password') {
      const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password })
      if (error) setError(authError(error))
    } else {
      const { error } = await supabase.auth.signInWithOtp({ email: email.trim(), options: { emailRedirectTo: window.location.origin, shouldCreateUser: false } })
      if (error && !error.message.toLowerCase().includes('signups not allowed')) setError(authError(error))
      // Si el correo no tiene cuenta no se dice (para no revelar quién está registrado)
      else setSent(true)
    }
    setBusy(false)
  }

  if (sent) {
    return (
      <AuthShell title="Revisa tu correo" subtitle={`Si ${email.trim()} tiene cuenta, te hemos enviado un enlace para entrar. Ábrelo en este dispositivo.`}>
        <Btn variant="outline" block onClick={() => setSent(false)}>
          Volver
        </Btn>
      </AuthShell>
    )
  }

  return (
    <AuthShell
      reveal={revealed}
      title="Entrar"
      subtitle={mode === 'password' ? 'Con tu correo y tu contraseña.' : 'Te enviamos un enlace al correo para entrar sin contraseña.'}
      footer={
        <>
          ¿No tienes cuenta?{' '}
          <Link to="/registro" className="font-semibold text-ink underline underline-offset-4">
            Crear cuenta
          </Link>
        </>
      }
    >
      <form onSubmit={submit} className="flex flex-col gap-4">
        <label className={labelCls}>
          Correo electrónico
          <input className={inputCls} type="email" inputMode="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="tu@correo.com" />
        </label>
        {mode === 'password' && (
          <label className={labelCls}>
            <span className="flex items-center justify-between">
              Contraseña
              <Link to="/recuperar" state={{ email }} className="text-[13px] font-medium text-ink-2 underline underline-offset-4">
                ¿La has olvidado?
              </Link>
            </span>
            <input className={inputCls} type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
          </label>
        )}
        <ErrorBox text={error} />
        <Btn type="submit" size="lg" block disabled={busy}>
          {busy ? 'Un momento…' : mode === 'password' ? 'Entrar' : 'Enviarme el enlace'}
        </Btn>
      </form>

      <div className="my-6 flex items-center gap-3 text-[13px] text-muted" aria-hidden="true">
        <span className="h-px flex-1 bg-line" />o<span className="h-px flex-1 bg-line" />
      </div>
      <Btn
        variant="outline"
        block
        onClick={() => {
          setMode(mode === 'password' ? 'link' : 'password')
          setError('')
        }}
      >
        {mode === 'password' ? 'Entrar con un enlace al correo' : 'Entrar con contraseña'}
      </Btn>
    </AuthShell>
  )
}

/** Crear cuenta con correo y contraseña. El alta queda pendiente de que la active el gimnasio. */
export function Signup() {
  const auth = useAuth()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [repeat, setRepeat] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [confirmSent, setConfirmSent] = useState(false)

  if (auth.mode === 'demo' || auth.session) return <Navigate to="/" replace />

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase) return
    if (!name.trim()) return setError('Escribe tu nombre.')
    if (password.length < MIN_PASSWORD) return setError(`La contraseña debe tener al menos ${MIN_PASSWORD} caracteres.`)
    if (password !== repeat) return setError('Las dos contraseñas no coinciden.')
    setBusy(true)
    setError('')
    const { data, error } = await supabase.auth.signUp({
      email: email.trim(),
      password,
      options: { data: { full_name: name.trim() }, emailRedirectTo: window.location.origin },
    })
    setBusy(false)
    if (error) return setError(authError(error))
    // Con confirmación de correo (producción) no hay sesión hasta pulsar el enlace
    if (!data.session) setConfirmSent(true)
  }

  if (confirmSent) {
    return (
      <AuthShell title="Confirma tu correo" subtitle={`Te hemos enviado un enlace a ${email.trim()}. Púlsalo para activar tu cuenta.`}>
        <Link to="/entrar" className="inline-flex h-12 w-full items-center justify-center rounded-[12px] border border-border text-[15px] font-semibold text-ink no-underline">
          Ir a Entrar
        </Link>
      </AuthShell>
    )
  }

  return (
    <AuthShell
      title="Crear cuenta"
      subtitle="Después, el gimnasio activará tu acceso."
      footer={
        <>
          ¿Ya tienes cuenta?{' '}
          <Link to="/entrar" className="font-semibold text-ink underline underline-offset-4">
            Entrar
          </Link>
        </>
      }
    >
      <form onSubmit={submit} className="flex flex-col gap-4">
        <label className={labelCls}>
          Nombre y apellidos
          <input className={inputCls} autoComplete="name" required maxLength={80} value={name} onChange={(e) => setName(e.target.value)} />
        </label>
        <label className={labelCls}>
          Correo electrónico
          <input className={inputCls} type="email" inputMode="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label className={labelCls}>
          Contraseña
          <input className={inputCls} type="password" autoComplete="new-password" required minLength={MIN_PASSWORD} value={password} onChange={(e) => setPassword(e.target.value)} />
          <span className="text-[12px] font-normal text-muted">Mínimo {MIN_PASSWORD} caracteres.</span>
        </label>
        <label className={labelCls}>
          Repite la contraseña
          <input className={inputCls} type="password" autoComplete="new-password" required value={repeat} onChange={(e) => setRepeat(e.target.value)} />
        </label>
        <ErrorBox text={error} />
        <Btn type="submit" size="lg" block disabled={busy}>
          {busy ? 'Creando la cuenta…' : 'Crear cuenta'}
        </Btn>
        <p className="m-0 text-center text-[12px] text-muted">Al crear la cuenta aceptas la política de privacidad del gimnasio.</p>
      </form>
    </AuthShell>
  )
}

/** Olvidé mi contraseña: correo con un enlace para crear una nueva */
export function ForgotPassword() {
  const auth = useAuth()
  const loc = useLocation()
  const [email, setEmail] = useState((loc.state as { email?: string } | null)?.email ?? '')
  const [busy, setBusy] = useState(false)
  const [sent, setSent] = useState(false)
  const [error, setError] = useState('')

  if (auth.mode === 'demo') return <Navigate to="/" replace />

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase) return
    setBusy(true)
    setError('')
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: `${window.location.origin}/restablecer` })
    setBusy(false)
    if (error && error.status === 429) return setError(authError(error))
    // No se dice si el correo existe
    setSent(true)
  }

  if (sent) {
    return (
      <AuthShell title="Revisa tu correo" subtitle={`Si ${email.trim()} tiene cuenta, te hemos enviado un enlace para crear una contraseña nueva.`}>
        <Link to="/entrar" className="inline-flex h-12 w-full items-center justify-center rounded-[12px] border border-border text-[15px] font-semibold text-ink no-underline">
          Volver a Entrar
        </Link>
      </AuthShell>
    )
  }

  return (
    <AuthShell title="Recuperar contraseña" subtitle="Te enviaremos un enlace para crear una nueva." footer={<Link to="/entrar" className="font-semibold text-ink underline underline-offset-4">Volver a Entrar</Link>}>
      <form onSubmit={submit} className="flex flex-col gap-4">
        <label className={labelCls}>
          Correo electrónico
          <input className={inputCls} type="email" inputMode="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <ErrorBox text={error} />
        <Btn type="submit" size="lg" block disabled={busy}>
          {busy ? 'Enviando…' : 'Enviarme el enlace'}
        </Btn>
      </form>
    </AuthShell>
  )
}

/** Formulario para poner o cambiar la contraseña (también tras el enlace de recuperación) */
export function PasswordForm({ onDone, submitLabel = 'Guardar contraseña' }: { onDone: () => void; submitLabel?: string }) {
  const [password, setPassword] = useState('')
  const [repeat, setRepeat] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase) return
    if (password.length < MIN_PASSWORD) return setError(`La contraseña debe tener al menos ${MIN_PASSWORD} caracteres.`)
    if (password !== repeat) return setError('Las dos contraseñas no coinciden.')
    setBusy(true)
    setError('')
    const { error } = await supabase.auth.updateUser({ password })
    setBusy(false)
    if (error) return setError(authError(error))
    setPassword('')
    setRepeat('')
    onDone()
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-4">
      <label className={labelCls}>
        Nueva contraseña
        <input className={inputCls} type="password" autoComplete="new-password" required minLength={MIN_PASSWORD} value={password} onChange={(e) => setPassword(e.target.value)} />
        <span className="text-[12px] font-normal text-muted">Mínimo {MIN_PASSWORD} caracteres.</span>
      </label>
      <label className={labelCls}>
        Repite la contraseña
        <input className={inputCls} type="password" autoComplete="new-password" required value={repeat} onChange={(e) => setRepeat(e.target.value)} />
      </label>
      <ErrorBox text={error} />
      <Btn type="submit" size="lg" block disabled={busy}>
        {busy ? 'Guardando…' : submitLabel}
      </Btn>
    </form>
  )
}

/** Tras pulsar el enlace de recuperación: poner la contraseña nueva */
export function ResetPassword() {
  const auth = useAuth()
  const nav = useNavigate()
  if (auth.mode === 'demo') return <Navigate to="/" replace />
  if (!auth.session) {
    return (
      <AuthShell title="Enlace caducado" subtitle="El enlace para cambiar la contraseña ya no es válido. Pide otro.">
        <Link to="/recuperar" className="inline-flex h-12 w-full items-center justify-center rounded-[12px] bg-ink text-[15px] font-semibold text-on-ink no-underline">
          Pedir otro enlace
        </Link>
      </AuthShell>
    )
  }
  return (
    <AuthShell title="Contraseña nueva" subtitle="Escribe la contraseña que usarás para entrar.">
      <PasswordForm
        onDone={() => {
          auth.clearRecovery()
          nav('/', { replace: true })
        }}
      />
    </AuthShell>
  )
}

/** Cuenta creada pero aún no activada por el gimnasio */
function PendingAccount() {
  const auth = useAuth()
  return (
    <AuthShell
      title="Cuenta pendiente"
      subtitle="Tu cuenta está creada. En cuanto el gimnasio la active podrás reservar clases. Si ya entrenas en ITACA, díselo en recepción."
    >
      <Btn variant="outline" block onClick={() => void auth.signOut()}>
        Cerrar sesión
      </Btn>
    </AuthShell>
  )
}

/** Protege las rutas: en modo real exige sesión activa y, para el personal, un rol de personal */
export function RequireAuth({ children, staff }: { children: ReactNode; staff?: boolean }) {
  const auth = useAuth()
  if (auth.mode === 'demo') return <>{children}</>
  if (auth.loading) {
    return (
      <Frame>
        <div className="flex flex-1 items-center justify-center text-[14px] text-muted" role="status">
          Cargando…
        </div>
      </Frame>
    )
  }
  if (!auth.session) return <Navigate to="/entrar" replace />
  if (auth.recovery) return <Navigate to="/restablecer" replace />
  if (auth.pending) return <PendingAccount />
  if (staff && !auth.isStaff) return <Navigate to="/" replace />
  return <>{children}</>
}
