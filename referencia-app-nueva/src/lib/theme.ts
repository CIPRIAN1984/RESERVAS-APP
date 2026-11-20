/**
 * Tema de la app: oscuro por defecto, claro o "como el sistema".
 * La preferencia se guarda en el dispositivo; index.html la aplica antes de pintar.
 */
import { useEffect, useState } from 'react'

export type ThemePref = 'dark' | 'light' | 'system'
const KEY = 'itaca-tema'

export function getThemePref(): ThemePref {
  try {
    const v = localStorage.getItem(KEY)
    return v === 'light' || v === 'system' ? v : 'dark'
  } catch {
    return 'dark'
  }
}

function resolve(pref: ThemePref): 'dark' | 'light' {
  if (pref !== 'system') return pref
  return window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
}

export function applyTheme(pref: ThemePref = getThemePref()) {
  const t = resolve(pref)
  document.documentElement.dataset.theme = t
  document.querySelector('meta[name=theme-color]')?.setAttribute('content', t === 'light' ? '#FFFFFF' : '#121212')
}

export function setThemePref(pref: ThemePref) {
  try {
    localStorage.setItem(KEY, pref)
  } catch {
    /* sin almacenamiento: se aplica solo en esta sesión */
  }
  applyTheme(pref)
  window.dispatchEvent(new Event('itaca-tema'))
}

/** Sigue los cambios del sistema cuando la preferencia es "system" */
export function watchSystemTheme() {
  const mq = window.matchMedia?.('(prefers-color-scheme: light)')
  const on = () => getThemePref() === 'system' && applyTheme('system')
  mq?.addEventListener?.('change', on)
  return () => mq?.removeEventListener?.('change', on)
}

export function useThemePref(): [ThemePref, (p: ThemePref) => void] {
  const [pref, setPref] = useState<ThemePref>(getThemePref)
  useEffect(() => {
    const on = () => setPref(getThemePref())
    window.addEventListener('itaca-tema', on)
    return () => window.removeEventListener('itaca-tema', on)
  }, [])
  return [pref, setThemePref]
}
