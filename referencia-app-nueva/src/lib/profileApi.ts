import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'
import type { Belt } from './types'

/** Lecturas del perfil completo (familia, graduaciones, facturación, contacto de la sede). RLS decide qué se ve. */

export interface FamilyMember {
  id: string
  fullName: string
  birthDate: string | null
  emergencyName: string | null
  emergencyPhone: string | null
}

export interface Promotion {
  id: string
  belt: Belt
  stripes: number
  promotedAt: string
  selfDeclared: boolean
  note: string | null
}

export interface Billing {
  name: string
  taxId: string
  address: string
  postalCode: string
  city: string
}

export interface GymContact {
  email?: string
  phone?: string
  whatsapp?: string
  address?: string
  instagram?: string
  web?: string
}

/** Estado de una lectura: datos, cargando, error y volver a leer */
function useQuery<T>(load: (() => Promise<T>) | null, deps: unknown[]): { data: T | null; loading: boolean; error: boolean; reload: () => void } {
  const [data, setData] = useState<T | null>(null)
  const [loading, setLoading] = useState(!!load)
  const [error, setError] = useState(false)
  const [version, setVersion] = useState(0)
  useEffect(() => {
    if (!load) {
      setLoading(false)
      return
    }
    let cancelled = false
    setLoading(true)
    load()
      .then((d) => {
        if (!cancelled) {
          setData(d)
          setError(false)
        }
      })
      .catch(() => !cancelled && setError(true))
      .finally(() => !cancelled && setLoading(false))
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, version])
  const reload = useCallback(() => setVersion((v) => v + 1), [])
  return { data, loading, error, reload }
}

/** Menores a mi cargo (perfiles de la familia) */
export function useFamily(myProfileId: string | undefined) {
  return useQuery<FamilyMember[]>(
    supabase && myProfileId
      ? async () => {
          const { data, error } = await supabase!
            .from('guardianships')
            .select('minor:profiles!guardianships_minor_profile_id_fkey(id, full_name, birth_date, emergency_contact_name, emergency_contact_phone)')
            .eq('guardian_profile_id', myProfileId)
            .order('created_at')
          if (error) throw error
          type Row = { minor: { id: string; full_name: string; birth_date: string | null; emergency_contact_name: string | null; emergency_contact_phone: string | null } | null }
          return ((data ?? []) as unknown as Row[])
            .map((r) => r.minor)
            .filter((m): m is NonNullable<Row['minor']> => !!m)
            .map((m) => ({ id: m.id, fullName: m.full_name, birthDate: m.birth_date, emergencyName: m.emergency_contact_name, emergencyPhone: m.emergency_contact_phone }))
        }
      : null,
    [myProfileId],
  )
}

/** Historial de cinturones de una persona, de la más reciente a la más antigua */
export function usePromotions(profileId: string | undefined, gymId: string | undefined) {
  return useQuery<Promotion[]>(
    supabase && profileId && gymId
      ? async () => {
          const { data, error } = await supabase!
            .from('promotions')
            .select('id, belt, stripes, promoted_at, self_declared, note')
            .eq('profile_id', profileId)
            .eq('gym_id', gymId)
            .order('promoted_at', { ascending: false })
            .order('created_at', { ascending: false })
          if (error) throw error
          return (data ?? []).map((r) => ({
            id: r.id as string,
            belt: r.belt as Belt,
            stripes: r.stripes as number,
            promotedAt: r.promoted_at as string,
            selfDeclared: r.self_declared as boolean,
            note: (r.note as string | null) ?? null,
          }))
        }
      : null,
    [profileId, gymId],
  )
}

export function useBilling(profileId: string | undefined) {
  return useQuery<Billing>(
    supabase && profileId
      ? async () => {
          const { data, error } = await supabase!
            .from('profiles')
            .select('billing_name, billing_tax_id, billing_address, billing_postal_code, billing_city')
            .eq('id', profileId)
            .single()
          if (error) throw error
          return {
            name: data.billing_name ?? '',
            taxId: data.billing_tax_id ?? '',
            address: data.billing_address ?? '',
            postalCode: data.billing_postal_code ?? '',
            city: data.billing_city ?? '',
          }
        }
      : null,
    [profileId],
  )
}

export async function saveBilling(profileId: string, b: Billing): Promise<void> {
  if (!supabase) throw new Error('Sin servidor')
  const clean = (s: string) => s.trim() || null
  const { error } = await supabase
    .from('profiles')
    .update({
      billing_name: clean(b.name),
      billing_tax_id: clean(b.taxId.toUpperCase()),
      billing_address: clean(b.address),
      billing_postal_code: clean(b.postalCode),
      billing_city: clean(b.city),
    })
    .eq('id', profileId)
  if (error) throw error
}

/** Contacto público de la sede (datos de la web del gimnasio en el modo demo) */
export const DEMO_CONTACT: GymContact = {
  email: 'contacto@tu-gimnasio.com',
  phone: '+34600000000',
  whatsapp: '34600000000',
  address: 'Calle Ejemplo, 1 · 00000 Tu ciudad',
  instagram: 'tu_gimnasio',
  web: 'https://www.tu-gimnasio.com',
}

export function useGymContact(gymId: string | undefined) {
  return useQuery<GymContact>(
    supabase && gymId
      ? async () => {
          const { data, error } = await supabase!.rpc('gym_contact', { p_gym: gymId })
          if (error) throw error
          return (data ?? {}) as GymContact
        }
      : null,
    [gymId],
  )
}

/** Edad en años cumplidos */
export function ageOn(birthDate: string, today = new Date()): number {
  const [y, m, d] = birthDate.split('-').map(Number)
  let age = today.getFullYear() - y
  if (today.getMonth() + 1 < m || (today.getMonth() + 1 === m && today.getDate() < d)) age--
  return age
}

/** "+34600000000" → "600 00 00 00" */
export function prettyPhone(p: string): string {
  const digits = p.replace(/\D/g, '').replace(/^34(?=\d{9}$)/, '')
  return digits.length === 9 ? `${digits.slice(0, 3)} ${digits.slice(3, 5)} ${digits.slice(5, 7)} ${digits.slice(7)}` : p
}
