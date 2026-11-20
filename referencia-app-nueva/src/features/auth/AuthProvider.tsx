import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { STAFF_ROLES, supabase, type GymRole } from '../../lib/supabase'
import type { Belt } from '../../lib/types'

export interface Membership {
  gymId: string
  gymName: string
  role: GymRole
}

export interface AuthProfile {
  id: string
  fullName: string
  avatarPath: string | null
  birthDate: string | null
  phone: string | null
  emergencyName: string | null
  emergencyPhone: string | null
}

export interface Rank {
  belt: Belt
  stripes: number
  promotedAt: string
  /** true: lo indicó el alumno; false: lo registró el personal (ya no lo puede cambiar el alumno) */
  selfDeclared: boolean
}

interface AuthState {
  /** demo: sin Supabase configurado; live: con servidor */
  mode: 'demo' | 'live'
  loading: boolean
  session: Session | null
  profile: AuthProfile | null
  memberships: Membership[]
  /** Mi cinturón actual en mi sede (null si no consta) */
  rank: Rank | null
  /** Cuenta registrada pero aún no activada por el gimnasio */
  pending: boolean
  /** Se ha entrado con un enlace de "olvidé mi contraseña": hay que poner una nueva */
  recovery: boolean
  clearRecovery: () => void
  isStaff: boolean
  signOut: () => Promise<void>
  /** Vuelve a leer el perfil (p. ej. tras cambiar la foto) */
  refreshProfile: () => void
}

const Ctx = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(!!supabase)
  const [profile, setProfile] = useState<AuthProfile | null>(null)
  const [memberships, setMemberships] = useState<Membership[]>([])
  const [rank, setRank] = useState<Rank | null>(null)
  const [pending, setPending] = useState(false)
  const [recovery, setRecovery] = useState(false)
  const [profileVersion, setProfileVersion] = useState(0)

  useEffect(() => {
    if (!supabase) return
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      if (!data.session) setLoading(false)
    })
    const { data } = supabase.auth.onAuthStateChange((event, s) => {
      if (event === 'PASSWORD_RECOVERY') setRecovery(true)
      setSession(s)
      if (!s) {
        setProfile(null)
        setMemberships([])
        setLoading(false)
      }
    })
    return () => data.subscription.unsubscribe()
  }, [])

  // Perfil y roles del usuario. RLS devuelve solo lo que le corresponde.
  // Depende solo del id: renovar el token crea otra sesión, pero el usuario es el mismo.
  const userId = session?.user.id
  useEffect(() => {
    if (!supabase || !userId) return
    let cancelled = false
    ;(async () => {
      setLoading(true)
      const { data: p } = await supabase.from('profiles').select('id, full_name, avatar_path, birth_date, phone, emergency_contact_name, emergency_contact_phone').eq('user_id', userId).maybeSingle()
      let ms: Membership[] = []
      let isPending = false
      if (p) {
        type Row = { gym_id: string; gym_name: string; role: GymRole; status: 'active' | 'inactive' }
        let { data: rows } = await supabase.rpc('my_membership_status')
        // Cuenta nueva (registro o primer enlace): se da de alta en la sede, pendiente de activar
        if (!rows || (rows as Row[]).length === 0) {
          await supabase.rpc('join_default_gym')
          ;({ data: rows } = await supabase.rpc('my_membership_status'))
        }
        const all = (rows ?? []) as Row[]
        ms = all.filter((r) => r.status === 'active').map((r) => ({ gymId: r.gym_id, gymName: r.gym_name, role: r.role }))
        isPending = all.length > 0 && ms.length === 0
      }
      let r: Rank | null = null
      if (p && ms[0]) {
        const { data: rows } = await supabase.rpc('current_rank', { p_profile: p.id, p_gym: ms[0].gymId })
        const row = (rows as { belt: Belt; stripes: number; promoted_at: string; self_declared: boolean }[] | null)?.[0]
        if (row) r = { belt: row.belt, stripes: row.stripes, promotedAt: row.promoted_at, selfDeclared: row.self_declared }
      }
      if (cancelled) return
      setPending(isPending)
      setRank(r)
      setProfile(
        p
          ? {
              id: p.id,
              fullName: p.full_name,
              avatarPath: p.avatar_path ?? null,
              birthDate: p.birth_date ?? null,
              phone: p.phone ?? null,
              emergencyName: p.emergency_contact_name ?? null,
              emergencyPhone: p.emergency_contact_phone ?? null,
            }
          : null,
      )
      setMemberships(ms)
      setLoading(false)
    })()
    return () => {
      cancelled = true
    }
  }, [userId, profileVersion])

  const value: AuthState = {
    mode: supabase ? 'live' : 'demo',
    loading,
    session,
    profile,
    memberships,
    rank,
    pending,
    recovery,
    clearRecovery: () => setRecovery(false),
    isStaff: supabase ? memberships.some((m) => STAFF_ROLES.includes(m.role)) : true,
    signOut: async () => {
      await supabase?.auth.signOut()
    },
    refreshProfile: () => setProfileVersion((v) => v + 1),
  }
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useAuth(): AuthState {
  const v = useContext(Ctx)
  if (!v) throw new Error('useAuth fuera de AuthProvider')
  return v
}
