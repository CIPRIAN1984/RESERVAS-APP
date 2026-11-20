import { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { Screen } from '../../components/Layout'
import { Avatar, BackButton, Btn, Chip, EmptyState, Sheet, Title } from '../../components/ui'
import { IconChevron } from '../../components/icons'
import { coachSubtitle } from '../../lib/data'
import { initials } from '../../lib/logic'
import { useApp } from '../../lib/store'
import { ROLE_LABEL, supabase, type GymRole } from '../../lib/supabase'
import { useAuth } from '../auth/AuthProvider'

/** Datos derivados de las clases de cada monitor */
export function useCoachStats() {
  const app = useApp()
  return (coachId: string) => {
    const templates = app.templates.filter((t) => t.coachId === coachId)
    const perWeek = templates.reduce((a, t) => a + t.weekdays.length, 0)
    const withCurriculum = templates.filter((t) => app.curriculumFor(t.id).curriculum)
    const withoutCurriculum = templates.filter((t) => !app.curriculumFor(t.id).curriculum)
    return { templates, perWeek, withCurriculum, withoutCurriculum }
  }
}

export function Coaches() {
  const app = useApp()
  const auth = useAuth()
  const [adding, setAdding] = useState(false)
  const stats = useCoachStats()
  const total = app.coaches.reduce((a, c) => a + stats(c.id).perWeek, 0)
  const month = app.now.toLocaleDateString('es-ES', { month: 'long' })

  return (
    <Screen gap={12}>
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <BackButton label="Volver a Más" to="/staff/mas" />
          <Title size={44}>Monitores</Title>
        </div>
        {auth.mode === 'live' && (
          <Btn size="sm" variant="accent" onClick={() => setAdding(true)}>
            Añadir
          </Btn>
        )}
      </div>
      <p className="m-0 text-[14px] text-muted">
        {app.coaches.length} monitores · {total} clases por semana · {month}
      </p>

      {app.coaches.map((c) => {
        const s = stats(c.id)
        let status
        if (c.unregisteredSessions > 0) status = <Chip tone="warn">{c.unregisteredSessions} clase sin registrar</Chip>
        else if (s.withoutCurriculum.length > 0) status = <Chip tone="neutral">Asignar</Chip>
        else status = <Chip tone="ok">Al día</Chip>
        return (
          <Link key={c.id} to={`/staff/monitores/${c.id}`} className="flex flex-col gap-[10px] rounded-[20px] bg-surface px-4 py-[14px] text-ink no-underline" aria-label={`Abrir ficha de ${c.name}`}>
            <div className="flex items-center gap-3">
              <Avatar text={initials(c.name)} size={44} tone="ink" />
              <div className="flex flex-1 flex-col gap-[1px]">
                <span className="text-[16px] font-bold">{c.name}</span>
                <span className="text-[12px] text-muted">{coachSubtitle(c)}</span>
              </div>
              <span className="flex h-11 w-11 items-center justify-center rounded-full bg-bg">
                <IconChevron size={20} />
              </span>
            </div>
            <div className="flex gap-2">
              {[
                [s.perWeek, 'clases por semana'],
                [c.hoursThisMonth || '—', 'horas este mes'],
                [c.avgAttendance || '—', 'asistencia media'],
              ].map(([v, l]) => (
                <div key={l} className="flex flex-1 flex-col gap-[1px]">
                  <span className="text-[26px] font-bold leading-none tracking-[-0.02em]">{v}</span>
                  <span className="text-[11px] text-muted">{l}</span>
                </div>
              ))}
            </div>
            <div className="flex items-center justify-between gap-2">
              <span className="text-[13px] text-ink-2">
                {s.withoutCurriculum.length > 0 && c.unregisteredSessions === 0
                  ? `${s.withoutCurriculum.length} ${s.withoutCurriculum.length === 1 ? 'clase' : 'clases'} sin currículo`
                  : `${s.withCurriculum.length} ${s.withCurriculum.length === 1 ? 'currículo' : 'currículos'} en curso`}
              </span>
              {status}
            </div>
          </Link>
        )
      })}
      <p className="m-0 text-[12px] text-muted">
        Las cifras sirven para ver la tendencia de un mismo grupo, no para comparar monitores: la clase de las 19:00 siempre llena más que la de las 7:30.
      </p>
      {app.coaches.length === 0 && auth.mode === 'live' && (
        <EmptyState title="Aún no hay monitores" text="Pulsa Añadir y elige a una persona del gimnasio. Tiene que haberse creado antes una cuenta en la app." />
      )}
      {adding && <AddCoachSheet onClose={() => setAdding(false)} />}
    </Screen>
  )
}

interface RosterLite {
  profile_id: string
  full_name: string
  role: GymRole
  has_account: boolean
  birth_date: string | null
}

/** Añadir monitor: una persona del gimnasio pasa a ser profesor (o, si ya es propietario o administración, "da clases") */
function AddCoachSheet({ onClose }: { onClose: () => void }) {
  const app = useApp()
  const auth = useAuth()
  const my = auth.memberships.find((m) => m.gymId === app.gymId)?.role
  const [rows, setRows] = useState<RosterLite[] | null>(null)
  const [q, setQ] = useState('')
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!supabase || !app.gymId) return
    supabase.rpc('gym_roster', { p_gym: app.gymId }).then(({ data }) => setRows((data ?? []) as RosterLite[]))
  }, [app.gymId])

  const adult = (b: string | null) => !b || b <= new Date(Date.now() - 18 * 365.25 * 86400000).toISOString().slice(0, 10)
  const coachIds = new Set(app.coaches.map((c) => c.id))
  const norm = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
  const list = (rows ?? [])
    .filter((r) => !coachIds.has(r.profile_id) && r.full_name !== 'Usuario eliminado')
    .filter((r) => !q || norm(r.full_name).includes(norm(q)))

  const add = async (r: RosterLite) => {
    if (!supabase || !app.gymId) return
    setBusy(r.profile_id)
    setError(null)
    const staff = r.role === 'owner' || r.role === 'admin'
    const { error } = await supabase.rpc('set_member_role', {
      p_gym: app.gymId,
      p_profile: r.profile_id,
      p_role: staff ? null : 'coach',
      p_teaches: staff ? true : null,
    })
    setBusy(null)
    if (error) return setError(error.message)
    await app.reloadSchedule()
    app.toast(`${r.full_name} ya aparece en Monitores`)
    onClose()
  }

  return (
    <Sheet open onClose={onClose} title="Añadir monitor">
      <p className="m-0 text-[13px] text-muted">
        Elige a una persona del gimnasio. Si es alumno, pasa a ser profesor (solo lo puede hacer el propietario). Si ya es propietario o administración, se marca que da clases.
      </p>
      <input
        type="search"
        aria-label="Buscar persona"
        placeholder="Buscar persona"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        className="h-11 rounded-[12px] border border-border bg-surface-2 px-3 text-[15px] text-ink placeholder:text-muted"
      />
      {error && (
        <p role="alert" className="m-0 rounded-[12px] bg-err-bg px-3 py-2 text-[13px] font-medium text-err-fg">
          {error}
        </p>
      )}
      {rows === null ? (
        <p className="m-0 text-[14px] text-muted">Cargando…</p>
      ) : (
        <div className="flex flex-col">
          {list.map((r) => {
            const staff = r.role === 'owner' || r.role === 'admin'
            const ok = staff ? my === 'owner' || my === 'admin' : my === 'owner' && r.has_account && adult(r.birth_date)
            return (
              <button
                key={r.profile_id}
                type="button"
                disabled={!ok || busy !== null}
                onClick={() => void add(r)}
                className="hy-text flex min-h-[52px] items-center justify-between gap-3 border-0 border-b border-line bg-transparent text-left text-ink last:border-b-0 disabled:opacity-50"
              >
                <span className="flex flex-col">
                  <span className="text-[15px] font-medium">{r.full_name}</span>
                  <span className="text-[12px] text-muted">
                    {ROLE_LABEL[r.role]}
                    {!r.has_account ? ' · sin cuenta en la app' : !adult(r.birth_date) ? ' · menor' : ''}
                  </span>
                </span>
                <span className="text-[13px] font-semibold">{busy === r.profile_id ? 'Añadiendo…' : ok ? 'Añadir' : ''}</span>
              </button>
            )
          })}
          {list.length === 0 && <p className="m-0 py-3 text-[14px] text-muted">No hay nadie más para añadir.</p>}
        </div>
      )}
    </Sheet>
  )
}
