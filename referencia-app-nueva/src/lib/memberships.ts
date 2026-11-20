import { useCallback, useEffect, useState } from 'react'
import { loadPlanStatus } from './remote'
import { supabase } from './supabase'
import type { PlanStatus } from './types'

/** Membresías del alumno y de sus hijos: tarifa vigente, solicitud pendiente e historial */

export interface PendingRequest {
  id: string
  planId: string
  planName: string
  createdAt: Date
}

export interface PersonMembership {
  profileId: string
  name: string
  status: PlanStatus | null
  pending: PendingRequest | null
  /** Solicitud pendiente de un complemento (ITACA+) */
  addonPending: PendingRequest | null
  /** Última solicitud rechazada por recepción en las dos últimas semanas */
  rejected: { planName: string; reason: string | null } | null
}

export interface PastPlan {
  id: string
  planName: string
  startsOn: string
  endsOn: string | null
}

export function useMemberships(people: { id: string; name: string }[]) {
  const key = people.map((p) => p.id).join(',')
  const [data, setData] = useState<PersonMembership[] | null>(null)
  const [version, setVersion] = useState(0)

  useEffect(() => {
    if (!supabase || people.length === 0) return
    let cancelled = false
    ;(async () => {
      const ids = people.map((p) => p.id)
      const since = new Date(Date.now() - 14 * 86400000).toISOString()
      const [statuses, reqs, rej] = await Promise.all([
        Promise.all(ids.map((id) => loadPlanStatus(id).catch(() => null))),
        supabase!.from('plan_requests').select('id, profile_id, plan_id, created_at, plan:plans(name, is_addon)').in('profile_id', ids).eq('status', 'pending'),
        supabase!
          .from('plan_requests')
          .select('profile_id, reject_reason, handled_by, requested_by, handled_at, plan:plans(name)')
          .in('profile_id', ids)
          .eq('status', 'cancelled')
          .gt('handled_at', since)
          .order('handled_at', { ascending: false }),
      ])
      type J = { profile_id: string; reject_reason: string | null; handled_by: string | null; requested_by: string | null; plan: { name: string } | null }
      const rejectedBy = new Map<string, J>()
      for (const r of (rej.data ?? []) as unknown as J[]) if (r.handled_by && r.handled_by !== r.requested_by && !rejectedBy.has(r.profile_id)) rejectedBy.set(r.profile_id, r)
      if (cancelled) return
      type R = { id: string; profile_id: string; plan_id: string; created_at: string; plan: { name: string; is_addon: boolean } | null }
      const all = (reqs.data ?? []) as unknown as R[]
      const byProfile = new Map(all.filter((r) => !r.plan?.is_addon).map((r) => [r.profile_id, r]))
      const addonBy = new Map(all.filter((r) => r.plan?.is_addon).map((r) => [r.profile_id, r]))
      const toReq = (r: R | undefined) => (r ? { id: r.id, planId: r.plan_id, planName: r.plan?.name ?? 'Tarifa', createdAt: new Date(r.created_at) } : null)
      setData(
        people.map((p, i) => {
          const r = byProfile.get(p.id)
          return {
            profileId: p.id,
            name: p.name,
            status: statuses[i],
            pending: toReq(r),
            addonPending: toReq(addonBy.get(p.id)),
            rejected: (() => {
              const j = rejectedBy.get(p.id)
              return j ? { planName: j.plan?.name ?? 'la tarifa', reason: j.reject_reason } : null
            })(),
          }
        }),
      )
    })()
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, version])

  const reload = useCallback(() => setVersion((v) => v + 1), [])
  return { data, reload }
}

/** Tarifas anteriores de una persona (las que ya terminaron) */
export function usePlanHistory(profileId: string | undefined, version = 0) {
  const [items, setItems] = useState<PastPlan[]>([])
  useEffect(() => {
    if (!supabase || !profileId) return
    let cancelled = false
    supabase
      .from('member_plans')
      .select('id, starts_on, ends_on, plan:plans(name)')
      .eq('profile_id', profileId)
      .order('starts_on', { ascending: false })
      .limit(12)
      .then(({ data }) => {
        if (cancelled) return
        type R = { id: string; starts_on: string; ends_on: string | null; plan: { name: string } | null }
        const today = new Date().toISOString().slice(0, 10)
        setItems(
          ((data ?? []) as unknown as R[])
            .filter((r) => r.ends_on && r.ends_on < today)
            .map((r) => ({ id: r.id, planName: r.plan?.name ?? 'Tarifa', startsOn: r.starts_on, endsOn: r.ends_on })),
        )
      })
    return () => {
      cancelled = true
    }
  }, [profileId, version])
  return items
}

export async function requestPlan(planDbId: string, profileId?: string): Promise<void> {
  if (!supabase) throw new Error('Sin servidor')
  const { error } = await supabase.rpc('request_plan', { p_plan: planDbId, ...(profileId ? { p_profile: profileId } : {}) })
  if (error) throw error
}

export async function cancelPlanRequest(id: string): Promise<void> {
  if (!supabase) throw new Error('Sin servidor')
  const { error } = await supabase.rpc('cancel_plan_request', { p_request: id })
  if (error) throw error
}
