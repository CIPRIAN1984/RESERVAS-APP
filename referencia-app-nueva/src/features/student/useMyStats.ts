import { useEffect, useMemo, useState } from 'react'
import { MY_MONTHLY_2026, MY_PROGRESS } from '../../lib/data'
import { addDays, startOfWeek, ymd } from '../../lib/dates'
import { countBetween, demoDays, monthlyTotals, weekStreak, type DayCounts } from '../../lib/stats'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../auth/AuthProvider'

export interface MyStats {
  loading: boolean
  year: number
  days: DayCounts
  monthly: number[]
  thisWeek: number
  thisMonth: number
  yearTotal: number
  streak: number
  /** Clases desde el último cinturón o grado */
  sinceRank: number
  /** Objetivo provisional por grado (las reglas reales llegan con el paso 5) */
  required: number
  rankSince: string | null
}

async function loadYear(year: number): Promise<DayCounts> {
  const { data, error } = await supabase!.rpc('my_attendance_days', { p_year: year })
  if (error) throw error
  const out: DayCounts = {}
  for (const r of (data ?? []) as { day: string; classes: number }[]) out[r.day] = r.classes
  return out
}

/** Mis estadísticas de asistencia: reales con sesión iniciada; de ejemplo en demo */
export function useMyStats(): MyStats {
  const app = useApp()
  const auth = useAuth()
  const live = auth.mode === 'live' && !!auth.profile
  const year = app.now.getFullYear()
  const [liveDays, setLiveDays] = useState<DayCounts | null>(null)

  useEffect(() => {
    if (!live || !supabase) return
    let cancelled = false
    Promise.all([loadYear(year - 1), loadYear(year)])
      .then(([a, b]) => !cancelled && setLiveDays({ ...a, ...b }))
      .catch(() => !cancelled && setLiveDays({}))
    return () => {
      cancelled = true
    }
  }, [live, year, app.syncVersion])

  const demo = useMemo(() => {
    if (live) return null
    const base = year === 2026 ? demoDays(2026, MY_MONTHLY_2026, app.now) : {}
    // Lo fichado en esta demo también cuenta
    for (const a of app.state.attendance) {
      if (a.profileId !== app.me.id) continue
      const d = ymd(new Date(a.at))
      base[d] = (base[d] ?? 0) + 1
    }
    return base
  }, [live, year, app.now, app.state.attendance, app.me.id])

  const days = live ? liveDays ?? {} : demo ?? {}
  const monthly = monthlyTotals(days, year)
  const monday = startOfWeek(app.now)
  const rankSince = live ? auth.rank?.promotedAt ?? null : app.state.demoProfile?.rankSince ?? null

  let sinceRank: number
  if (live) sinceRank = rankSince ? countBetween(days, new Date(rankSince + 'T00:00:00'), app.now) : 0
  else sinceRank = MY_PROGRESS.classesTowardNext + app.state.attendance.filter((a) => a.profileId === app.me.id).length

  return {
    loading: live && liveDays === null,
    year,
    days,
    monthly,
    thisWeek: countBetween(days, monday, addDays(monday, 6)),
    thisMonth: monthly[app.now.getMonth()],
    yearTotal: monthly.reduce((a, b) => a + b, 0),
    streak: weekStreak(days, app.now),
    sinceRank,
    required: MY_PROGRESS.classesRequired,
    rankSince,
  }
}
