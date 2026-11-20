/**
 * Estadísticas de asistencia a partir de un mapa día → clases.
 * Funciones puras: las usan Hoy y Progreso, en modo real y en demo.
 */
import { addDays, isoWeekday, startOfWeek, ymd } from './dates'

/** 'YYYY-MM-DD' → número de clases ese día */
export type DayCounts = Record<string, number>

export function monthlyTotals(days: DayCounts, year: number): number[] {
  const out = Array(12).fill(0) as number[]
  for (const [d, n] of Object.entries(days)) {
    const [y, m] = d.split('-').map(Number)
    if (y === year) out[m - 1] += n
  }
  return out
}

export function countBetween(days: DayCounts, from: Date, to: Date): number {
  const a = ymd(from)
  const b = ymd(to)
  let n = 0
  for (const [d, c] of Object.entries(days)) if (d >= a && d <= b) n += c
  return n
}

/** Semanas seguidas (de lunes a domingo) con al menos una clase, contando hasta la actual.
 *  Si esta semana aún no hay clase, la racha sigue viva desde la anterior. */
export function weekStreak(days: DayCounts, today: Date): number {
  const weekHas = (monday: Date) => countBetween(days, monday, addDays(monday, 6)) > 0
  let monday = startOfWeek(today)
  let streak = 0
  if (!weekHas(monday)) monday = addDays(monday, -7)
  while (weekHas(monday)) {
    streak++
    monday = addDays(monday, -7)
  }
  return streak
}

/** Celdas del calendario de un mes (semanas de lunes a domingo); null = hueco */
export function monthGrid(year: number, month: number): (Date | null)[] {
  const first = new Date(year, month, 1)
  const daysInMonth = new Date(year, month + 1, 0).getDate()
  const cells: (Date | null)[] = Array(isoWeekday(first) - 1).fill(null)
  for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(year, month, d))
  while (cells.length % 7) cells.push(null)
  return cells
}

/** Hash estable (para datos de ejemplo reproducibles) */
function h(s: string): number {
  let x = 2166136261
  for (let i = 0; i < s.length; i++) {
    x ^= s.charCodeAt(i)
    x = Math.imul(x, 16777619)
  }
  return x >>> 0
}

/**
 * Datos de ejemplo: reparte el total de cada mes en días de entreno plausibles
 * (de lunes a sábado), sin pasar de hoy. La suma por mes coincide con `monthly`.
 */
export function demoDays(year: number, monthly: number[], today: Date): DayCounts {
  const out: DayCounts = {}
  monthly.forEach((total, m) => {
    const candidates: string[] = []
    const last = new Date(year, m + 1, 0).getDate()
    for (let d = 1; d <= last; d++) {
      const date = new Date(year, m, d)
      if (date > today) break
      if (isoWeekday(date) <= 6) candidates.push(ymd(date))
    }
    if (!candidates.length) return
    candidates.sort((a, b) => h(a) - h(b))
    for (let i = 0; i < total; i++) {
      const day = candidates[i % candidates.length]
      out[day] = (out[day] ?? 0) + 1
    }
  })
  return out
}

export type PeriodKind = 'week' | 'month' | 'year'

export interface PeriodRange {
  from: Date
  to: Date
  prevFrom: Date
  prevTo: Date
  /** "esta semana", "noviembre", "2026" */
  label: string
  /** "la semana pasada", "octubre", "2025" */
  prevLabel: string
}

const MONTHS_ES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']

/** Periodo actual (semana de lunes a domingo, mes natural o año) y el anterior */
export function periodRange(kind: PeriodKind, today: Date): PeriodRange {
  if (kind === 'week') {
    const from = startOfWeek(today)
    return { from, to: addDays(from, 6), prevFrom: addDays(from, -7), prevTo: addDays(from, -1), label: 'esta semana', prevLabel: 'la semana pasada' }
  }
  if (kind === 'month') {
    const y = today.getFullYear()
    const m = today.getMonth()
    return {
      from: new Date(y, m, 1),
      to: new Date(y, m + 1, 0),
      prevFrom: new Date(y, m - 1, 1),
      prevTo: new Date(y, m, 0),
      label: MONTHS_ES[m],
      prevLabel: MONTHS_ES[(m + 11) % 12],
    }
  }
  const y = today.getFullYear()
  return { from: new Date(y, 0, 1), to: new Date(y, 11, 31), prevFrom: new Date(y - 1, 0, 1), prevTo: new Date(y - 1, 11, 31), label: String(y), prevLabel: String(y - 1) }
}

/** Días distintos con al menos una clase entre dos fechas */
export function daysTrained(days: DayCounts, from: Date, to: Date): number {
  const a = ymd(from)
  const b = ymd(to)
  return Object.entries(days).filter(([d, n]) => d >= a && d <= b && n > 0).length
}

/** Clases de las últimas `weeks` semanas (de lunes a domingo), de la más antigua a la actual */
export function weeklyTrend(days: DayCounts, today: Date, weeks = 8): { monday: Date; count: number }[] {
  const current = startOfWeek(today)
  return Array.from({ length: weeks }, (_, i) => {
    const monday = addDays(current, (i - weeks + 1) * 7)
    return { monday, count: countBetween(days, monday, addDays(monday, 6)) }
  })
}

/** Último día del periodo anterior comparable con hoy: el mismo punto del periodo (p. ej. 18 de octubre si hoy es 18 de noviembre) */
export function samePointInPrev(r: PeriodRange, today: Date): Date {
  if (today < r.from || today > r.to) return r.prevTo
  if (r.from.getMonth() === 0 && r.from.getDate() === 1 && r.to.getMonth() === 11) {
    // año: mismo día del año anterior
    const d = new Date(today.getFullYear() - 1, today.getMonth(), today.getDate())
    return d > r.prevTo ? r.prevTo : d
  }
  if (r.from.getDate() === 1 && r.to.getDate() >= 28) {
    // mes: mismo número de día, sin pasar del último del mes anterior
    const d = new Date(r.prevFrom.getFullYear(), r.prevFrom.getMonth(), today.getDate())
    return d > r.prevTo ? r.prevTo : d
  }
  return addDays(r.prevFrom, Math.round((today.getTime() - r.from.getTime()) / 86400000))
}
