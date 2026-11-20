import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'

/** Novedades (avisos del gimnasio): lectura en tiempo real y aviso de "hay algo nuevo" */

export interface Announcement {
  id: string
  title: string
  body: string
  pinned: boolean
  publishedAt: Date
  edited: boolean
  authorName: string
  canEdit: boolean
}

const SEEN_KEY = 'itaca-novedades-vistas'
const CHANGED = 'itaca-novedades-cambio'

/** Avisos de la sede, fijados primero; se actualizan solos cuando alguien publica */
export function useAnnouncements(gymId: string | undefined, limit: number) {
  const [items, setItems] = useState<Announcement[] | null>(null)
  const [error, setError] = useState(false)
  const [version, setVersion] = useState(0)

  useEffect(() => {
    if (!supabase || !gymId) return
    let cancelled = false
    supabase.rpc('gym_announcements', { p_gym: gymId, p_limit: limit + 1 }).then(({ data, error }) => {
      if (cancelled) return
      if (error) {
        setError(true)
        setItems([])
        return
      }
      setError(false)
      type R = { id: string; title: string; body: string; pinned: boolean; published_at: string; edited: boolean; author_name: string; can_edit: boolean }
      setItems(
        ((data ?? []) as R[]).map((r) => ({
          id: r.id,
          title: r.title,
          body: r.body,
          pinned: r.pinned,
          publishedAt: new Date(r.published_at),
          edited: r.edited,
          authorName: r.author_name,
          canEdit: r.can_edit,
        })),
      )
    })
    return () => {
      cancelled = true
    }
  }, [gymId, limit, version])

  useAnnouncementChanges(gymId, () => setVersion((v) => v + 1))
  const reload = useCallback(() => setVersion((v) => v + 1), [])
  // Se pide uno de más para saber si hay más que mostrar
  return { items: items?.slice(0, limit) ?? null, hasMore: (items?.length ?? 0) > limit, error, reload }
}

/** Avisa cuando se publica, edita o borra un aviso de la sede */
function useAnnouncementChanges(gymId: string | undefined, onChange: () => void) {
  useEffect(() => {
    if (!supabase || !gymId) return
    const channel = supabase
      .channel(`avisos-${gymId}-${Math.random().toString(36).slice(2)}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'announcements', filter: `gym_id=eq.${gymId}` }, () => onChange())
      .subscribe()
    return () => {
      void supabase!.removeChannel(channel)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [gymId])
}

function seenAt(): number {
  try {
    return Number(localStorage.getItem(SEEN_KEY) ?? 0)
  } catch {
    return 0
  }
}

/** Marca las novedades como vistas (al abrir la pestaña) */
export function markNewsSeen() {
  try {
    localStorage.setItem(SEEN_KEY, String(Date.now()))
  } catch {
    /* sin almacenamiento: el aviso de novedades volverá a salir */
  }
  window.dispatchEvent(new Event(CHANGED))
}

/** ¿Hay algún aviso publicado después de la última vez que se abrió Novedades? */
export function useNewsUnread(gymId: string | undefined): boolean {
  const [latest, setLatest] = useState<number>(0)
  const [seen, setSeen] = useState(seenAt)
  const [version, setVersion] = useState(0)

  useEffect(() => {
    if (!supabase || !gymId) return
    let cancelled = false
    supabase
      .from('announcements')
      .select('published_at')
      .eq('gym_id', gymId)
      .order('published_at', { ascending: false })
      .limit(1)
      .then(({ data }) => {
        if (!cancelled) setLatest(data?.[0] ? new Date(data[0].published_at as string).getTime() : 0)
      })
    return () => {
      cancelled = true
    }
  }, [gymId, version])

  useAnnouncementChanges(gymId, () => setVersion((v) => v + 1))
  useEffect(() => {
    const on = () => setSeen(seenAt())
    window.addEventListener(CHANGED, on)
    return () => window.removeEventListener(CHANGED, on)
  }, [])

  return latest > seen
}

/** "hace 5 min", "hace 3 h", "ayer", "12 nov" */
export function timeAgo(d: Date, now = new Date()): string {
  const s = Math.max(0, (now.getTime() - d.getTime()) / 1000)
  if (s < 60) return 'ahora'
  if (s < 3600) return `hace ${Math.floor(s / 60)} min`
  if (s < 86400) return `hace ${Math.floor(s / 3600)} h`
  const days = Math.floor(s / 86400)
  if (days === 1) return 'ayer'
  if (days < 7) return `hace ${days} días`
  return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'short', ...(d.getFullYear() !== now.getFullYear() ? { year: 'numeric' } : {}) })
}
