/**
 * Fotos de perfil: cubo privado "avatars" de Supabase.
 * Se ven con direcciones firmadas que caducan; aquí se cachean en memoria.
 */
import { useEffect, useState } from 'react'
import { supabase } from './supabase'

const BUCKET = 'avatars'
const TTL_SECONDS = 60 * 60
const cache = new Map<string, { url: string; expires: number }>()

/** Direcciones firmadas para varias rutas a la vez (una sola petición) */
export async function signedAvatarUrls(paths: string[]): Promise<Record<string, string>> {
  const out: Record<string, string> = {}
  const now = Date.now()
  const missing: string[] = []
  for (const p of new Set(paths)) {
    const c = cache.get(p)
    if (c && c.expires > now + 60_000) out[p] = c.url
    else missing.push(p)
  }
  if (supabase && missing.length) {
    const { data } = await supabase.storage.from(BUCKET).createSignedUrls(missing, TTL_SECONDS)
    for (const d of data ?? []) {
      if (d.signedUrl && d.path) {
        cache.set(d.path, { url: d.signedUrl, expires: now + TTL_SECONDS * 1000 })
        out[d.path] = d.signedUrl
      }
    }
  }
  return out
}

/** Hook: mapa ruta → dirección para las fotos indicadas */
export function useAvatarUrls(paths: (string | null | undefined)[]): Record<string, string> {
  const key = paths.filter(Boolean).sort().join('|')
  const [urls, setUrls] = useState<Record<string, string>>({})
  useEffect(() => {
    if (!key) return
    let cancelled = false
    void signedAvatarUrls(key.split('|')).then((u) => !cancelled && setUrls(u))
    return () => {
      cancelled = true
    }
  }, [key])
  return urls
}

/** Recorta al centro y reduce a un cuadrado de `size` px en JPEG */
export async function squareJpeg(file: File, size = 512): Promise<Blob> {
  if (!file.type.startsWith('image/')) throw new Error('El fichero no es una imagen')
  const bitmap = await createImageBitmap(file)
  const side = Math.min(bitmap.width, bitmap.height)
  const canvas = document.createElement('canvas')
  canvas.width = size
  canvas.height = size
  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('No se pudo procesar la imagen')
  ctx.drawImage(bitmap, (bitmap.width - side) / 2, (bitmap.height - side) / 2, side, side, 0, 0, size, size)
  bitmap.close()
  return new Promise((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('No se pudo procesar la imagen'))), 'image/jpeg', 0.85),
  )
}

/** Sube la foto a <userId>/avatar-<fecha>.jpg, la pone en el perfil y borra la anterior */
export async function uploadAvatar(file: File, userId: string, profileId: string, previous: string | null): Promise<string> {
  if (!supabase) throw new Error('Sin servidor')
  const blob = await squareJpeg(file)
  const path = `${userId}/avatar-${Date.now()}.jpg`
  const up = await supabase.storage.from(BUCKET).upload(path, blob, { contentType: 'image/jpeg', upsert: false })
  if (up.error) throw up.error
  const upd = await supabase.from('profiles').update({ avatar_path: path }).eq('id', profileId)
  if (upd.error) {
    await supabase.storage.from(BUCKET).remove([path])
    throw upd.error
  }
  if (previous) await supabase.storage.from(BUCKET).remove([previous])
  return path
}

export async function removeAvatar(profileId: string, previous: string): Promise<void> {
  if (!supabase) return
  const upd = await supabase.from('profiles').update({ avatar_path: null }).eq('id', profileId)
  if (upd.error) throw upd.error
  await supabase.storage.from(BUCKET).remove([previous])
  cache.delete(previous)
}

/** Para el modo demo: la foto se guarda como dataURL pequeña en el dispositivo */
export async function demoAvatarDataUrl(file: File): Promise<string> {
  const blob = await squareJpeg(file, 256)
  return new Promise((resolve, reject) => {
    const r = new FileReader()
    r.onload = () => resolve(r.result as string)
    r.onerror = () => reject(new Error('No se pudo leer la imagen'))
    r.readAsDataURL(blob)
  })
}
