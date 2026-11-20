import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

/**
 * Cliente de Supabase con la clave pública: los permisos los pone RLS.
 * La clave de servicio nunca va en el cliente.
 * `null` = modo demo (sin variables de entorno): la app usa datos de ejemplo.
 */
export const supabase: SupabaseClient | null = url && key ? createClient(url, key) : null

export type GymRole = 'owner' | 'admin' | 'coach' | 'front_desk' | 'member'

export const ROLE_LABEL: Record<GymRole, string> = {
  owner: 'Propietario',
  admin: 'Administración',
  coach: 'Profesor',
  front_desk: 'Recepción',
  member: 'Alumno',
}

export const STAFF_ROLES: GymRole[] = ['owner', 'admin', 'coach', 'front_desk']
