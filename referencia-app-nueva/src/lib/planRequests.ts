import { useCallback, useEffect, useRef, useState } from 'react'
import { supabase } from './supabase'

/** Solicitudes de tarifa pendientes (personal): en tiempo real, con aviso al llegar una nueva */

export interface PendingPlanRequest {
  id: string
  profileId: string
  fullName: string
  planId: string
  planName: string
  priceCents: number
  isAddon: boolean
  currentPlan: string | null
  createdAt: Date
}

const CHANGED = 'itaca-solicitudes-cambio'

export function usePendingPlanRequests(gymId: string | undefined, onNew?: (r: PendingPlanRequest) => void) {
  const [items, setItems] = useState<PendingPlanRequest[] | null>(null)
  const [version, setVersion] = useState(0)
  const known = useRef<Set<string> | null>(null)
  const onNewRef = useRef(onNew)
  onNewRef.current = onNew

  useEffect(() => {
    if (!supabase || !gymId) return
    let cancelled = false
    supabase.rpc('pending_plan_requests', { p_gym: gymId }).then(({ data, error }) => {
      if (cancelled || error) return
      type R = { id: string; profile_id: string; full_name: string; plan_id: string; plan_name: string; price_cents: number; is_addon: boolean; current_plan: string | null; created_at: string }
      const list = ((data ?? []) as R[]).map((r) => ({
        id: r.id,
        profileId: r.profile_id,
        fullName: r.full_name,
        planId: r.plan_id,
        planName: r.plan_name,
        priceCents: r.price_cents,
        isAddon: r.is_addon,
        currentPlan: r.current_plan,
        createdAt: new Date(r.created_at),
      }))
      // Avisar de las que no estaban (no en la primera carga)
      if (known.current) for (const r of list) if (!known.current.has(r.id)) onNewRef.current?.(r)
      known.current = new Set(list.map((r) => r.id))
      setItems(list)
    })
    return () => {
      cancelled = true
    }
  }, [gymId, version])

  // Tiempo real: cualquier cambio en las solicitudes de la sede
  useEffect(() => {
    if (!supabase || !gymId) return
    const channel = supabase
      .channel(`solicitudes-${gymId}-${Math.random().toString(36).slice(2)}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'plan_requests', filter: `gym_id=eq.${gymId}` }, () => setVersion((v) => v + 1))
      .subscribe()
    const local = () => setVersion((v) => v + 1)
    window.addEventListener(CHANGED, local)
    return () => {
      void supabase!.removeChannel(channel)
      window.removeEventListener(CHANGED, local)
    }
  }, [gymId])

  const reload = useCallback(() => {
    window.dispatchEvent(new Event(CHANGED))
  }, [])
  return { items, reload }
}
