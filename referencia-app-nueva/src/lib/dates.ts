/**
 * Fechas. En el prototipo las horas se calculan en la zona del dispositivo
 * (se asume Europe/Madrid). Con Supabase, la base guarda UTC y la pantalla
 * muestra Europe/Madrid (principio 6 del plan).
 */

export function ymd(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

export function parseYmd(s: string): Date {
  const [y, m, d] = s.split('-').map(Number)
  return new Date(y, m - 1, d)
}

export function addDays(d: Date, n: number): Date {
  const r = new Date(d)
  r.setDate(r.getDate() + n)
  return r
}

/** 1 = lunes … 7 = domingo */
export function isoWeekday(d: Date): number {
  const w = d.getDay()
  return w === 0 ? 7 : w
}

export function startOfWeek(d: Date): Date {
  const r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  return addDays(r, 1 - isoWeekday(r))
}

export function atTime(date: string, hhmm: string): Date {
  const d = parseYmd(date)
  const [h, m] = hhmm.split(':').map(Number)
  d.setHours(h, m, 0, 0)
  return d
}

export function hhmm(d: Date): string {
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

const WEEKDAYS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']
const WEEKDAYS_SHORT = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb']
export const WEEKDAY_LETTER = ['D', 'L', 'M', 'X', 'J', 'V', 'S']
const MONTHS = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const MONTHS_SHORT = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

/** "Viernes, 13 de noviembre" */
export function longDay(d: Date): string {
  return `${cap(WEEKDAYS[d.getDay()])}, ${d.getDate()} de ${MONTHS[d.getMonth()]}`
}

/** "Viernes 13 nov" */
export function mediumDay(d: Date): string {
  return `${cap(WEEKDAYS[d.getDay()])} ${d.getDate()} ${MONTHS_SHORT[d.getMonth()]}`
}

/** "vie 13 nov" */
export function shortDay(d: Date): string {
  return `${WEEKDAYS_SHORT[d.getDay()]} ${d.getDate()} ${MONTHS_SHORT[d.getMonth()]}`
}

export function weekdayName(d: Date): string {
  return cap(WEEKDAYS[d.getDay()])
}

/** "Noviembre 2026" */
export function monthYear(d: Date): string {
  return `${cap(MONTHS[d.getMonth()])} ${d.getFullYear()}`
}

/** "1 h 20 min", "35 min" */
export function durationUntil(from: Date, to: Date): string {
  const mins = Math.max(0, Math.round((to.getTime() - from.getTime()) / 60000))
  if (mins >= 60 * 24) {
    const days = Math.round(mins / (60 * 24))
    return days === 1 ? '1 día' : `${days} días`
  }
  const h = Math.floor(mins / 60)
  const m = mins % 60
  if (h === 0) return `${m} min`
  return m === 0 ? `${h} h` : `${h} h ${m} min`
}

export function sameDay(a: Date, b: Date): boolean {
  return ymd(a) === ymd(b)
}
