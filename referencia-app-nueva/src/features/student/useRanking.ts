import { useEffect, useState } from 'react'
import { MEMBERS } from '../../lib/data'
import { ymd } from '../../lib/dates'
import type { PeriodRange } from '../../lib/stats'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import type { Belt } from '../../lib/types'
import { useAuth } from '../auth/AuthProvider'

export interface RankRow {
  position: number
  profileId: string
  name: string
  avatarPath: string | null
  belt: Belt | null
  stripes: number
  classes: number
  isMe: boolean
}

export interface RecentClass {
  id: string
  name: string
  at: Date
}

/** Ranking de asistencia de la sede en un periodo (datos de ejemplo en demo) */
export function useRanking(range: PeriodRange) {
  const app = useApp()
  const auth = useAuth()
  const live = auth.mode === 'live'
  const gymId = auth.memberships[0]?.gymId
  const from = ymd(range.from)
  const to = ymd(range.to)
  const [rows, setRows] = useState<RankRow[] | null>(null)
  const [error, setError] = useState(false)

  useEffect(() => {
    if (!live) {
      setRows(demoRanking(from, app.me.name))
      return
    }
    if (!supabase || !gymId) return
    let cancelled = false
    setRows(null)
    setError(false)
    supabase
      .rpc('gym_ranking', { p_gym: gymId, p_from: from, p_to: to })
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) {
          setError(true)
          setRows([])
          return
        }
        type R = { rank_position: number; profile_id: string; display_name: string; avatar_path: string | null; belt: Belt | null; stripes: number | null; classes: number; is_me: boolean }
        setRows(
          ((data ?? []) as R[]).map((r) => ({
            position: r.rank_position,
            profileId: r.profile_id,
            name: r.display_name,
            avatarPath: r.avatar_path,
            belt: r.belt,
            stripes: r.stripes ?? 0,
            classes: r.classes,
            isMe: r.is_me,
          })),
        )
      })
    return () => {
      cancelled = true
    }
  }, [live, gymId, from, to, app.me.name, app.syncVersion])

  return { rows, error }
}

/** Mis últimas clases con asistencia */
export function useRecentClasses(limit = 6) {
  const auth = useAuth()
  const app = useApp()
  const live = auth.mode === 'live'
  const profileId = auth.profile?.id
  const [items, setItems] = useState<RecentClass[] | null>(null)

  useEffect(() => {
    if (!live) {
      setItems(
        app.state.attendance
          .filter((a) => a.profileId === app.me.id)
          .slice(-limit)
          .reverse()
          .map((a) => ({ id: a.sessionId, name: (() => { const ss = app.sessionById(a.sessionId); return ss ? app.template(ss.templateId).name : 'Clase' })(), at: new Date(a.at) })),
      )
      return
    }
    if (!supabase || !profileId) return
    let cancelled = false
    supabase
      .from('attendances')
      .select('id, checked_in_at, session:class_sessions(name)')
      .eq('profile_id', profileId)
      .is('voided_at', null)
      .order('checked_in_at', { ascending: false })
      .limit(limit)
      .then(({ data }) => {
        if (cancelled) return
        type R = { id: string; checked_in_at: string; session: { name: string } | null }
        setItems(((data ?? []) as unknown as R[]).map((r) => ({ id: r.id, name: r.session?.name ?? 'Clase', at: new Date(r.checked_in_at) })))
      })
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [live, profileId, limit, app.syncVersion])

  return items
}

/** Ranking de ejemplo, estable para cada periodo */
function demoRanking(seed: string, myName: string): RankRow[] {
  const h = (s: string) => {
    let x = 2166136261
    for (let i = 0; i < s.length; i++) x = Math.imul(x ^ s.charCodeAt(i), 16777619)
    return (x >>> 0) % 23
  }
  const rows = MEMBERS.map((m) => ({ m, n: h(seed + m.id) + (m.id === 'me' ? 6 : 0) }))
    .filter((r) => r.n > 0)
    .sort((a, b) => b.n - a.n || a.m.name.localeCompare(b.m.name))
  let pos = 0
  let last = -1
  return rows.map((r, i) => {
    if (r.n !== last) {
      pos = i + 1
      last = r.n
    }
    return {
      position: pos,
      profileId: r.m.id,
      name: r.m.id === 'me' ? myName : r.m.name,
      avatarPath: null,
      belt: r.m.belt,
      stripes: r.m.stripes,
      classes: r.n,
      isMe: r.m.id === 'me',
    }
  })
}
