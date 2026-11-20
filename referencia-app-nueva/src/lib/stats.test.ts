import { describe, expect, it } from 'vitest'
import { countBetween, daysTrained, demoDays, monthGrid, monthlyTotals, periodRange, samePointInPrev, weeklyTrend, weekStreak } from './stats'
import { ymd } from './dates'

describe('estadísticas de asistencia', () => {
  const days = {
    '2026-11-02': 1, // lunes, semana 45
    '2026-11-04': 2,
    '2026-11-10': 1, // semana 46
    '2026-11-16': 1, // semana 47 (lunes)
    '2026-10-30': 1,
    '2025-11-16': 3, // otro año
  }

  it('suma por meses del año pedido', () => {
    const m = monthlyTotals(days, 2026)
    expect(m[10]).toBe(5)
    expect(m[9]).toBe(1)
    expect(m.reduce((a, b) => a + b, 0)).toBe(6)
  })

  it('cuenta las clases entre dos fechas, ambas incluidas', () => {
    expect(countBetween(days, new Date(2026, 10, 2), new Date(2026, 10, 4))).toBe(3)
  })

  it('racha de semanas seguidas con al menos una clase', () => {
    expect(weekStreak(days, new Date(2026, 10, 18))).toBe(4) // semanas 44 (30 oct), 45, 46 y 47
  })

  it('si esta semana aún no hay clase, la racha cuenta desde la anterior', () => {
    const d = { '2026-11-10': 1, '2026-11-03': 1 }
    expect(weekStreak(d, new Date(2026, 10, 18))).toBe(2)
  })

  it('una semana sin clases corta la racha', () => {
    const d = { '2026-11-16': 1, '2026-11-02': 1 }
    expect(weekStreak(d, new Date(2026, 10, 18))).toBe(1)
  })

  it('el calendario de noviembre de 2026 empieza en domingo (6 huecos) y tiene semanas completas', () => {
    const g = monthGrid(2026, 10)
    expect(g.slice(0, 6).every((c) => c === null)).toBe(true)
    expect(g[6]?.getDate()).toBe(1)
    expect(g.length % 7).toBe(0)
    expect(g.filter(Boolean)).toHaveLength(30)
  })

  it('los datos de ejemplo respetan el total de cada mes y no pasan de hoy', () => {
    const monthly = [8, 10, 12, 9, 11, 10, 6, 4, 12, 13, 9]
    const today = new Date(2026, 10, 15)
    const d = demoDays(2026, monthly, today)
    expect(monthlyTotals(d, 2026).slice(0, 11)).toEqual(monthly)
    expect(Object.keys(d).every((k) => k <= '2026-11-15')).toBe(true)
    expect(Object.keys(d).every((k) => new Date(k + 'T12:00:00').getDay() !== 0)).toBe(true)
  })
})

describe('periodRange', () => {
  const today = new Date(2026, 10, 18) // miércoles 18 de noviembre de 2026
  it('semana de lunes a domingo y la anterior', () => {
    const r = periodRange('week', today)
    expect(ymd(r.from)).toBe('2026-11-16')
    expect(ymd(r.to)).toBe('2026-11-22')
    expect(ymd(r.prevFrom)).toBe('2026-11-09')
    expect(ymd(r.prevTo)).toBe('2026-11-15')
  })
  it('mes natural y el anterior, también en enero', () => {
    const r = periodRange('month', today)
    expect([ymd(r.from), ymd(r.to), ymd(r.prevFrom), ymd(r.prevTo)]).toEqual(['2026-11-01', '2026-11-30', '2026-10-01', '2026-10-31'])
    expect(r.prevLabel).toBe('octubre')
    const jan = periodRange('month', new Date(2027, 0, 5))
    expect([ymd(jan.prevFrom), ymd(jan.prevTo), jan.prevLabel]).toEqual(['2026-12-01', '2026-12-31', 'diciembre'])
  })
  it('año', () => {
    const r = periodRange('year', today)
    expect([ymd(r.from), ymd(r.to), r.prevLabel]).toEqual(['2026-01-01', '2026-12-31', '2025'])
  })
})

describe('weeklyTrend y daysTrained', () => {
  const days = { '2026-11-16': 2, '2026-11-18': 1, '2026-11-10': 1, '2026-10-01': 3 }
  it('cuenta por semanas, la actual la última', () => {
    const t = weeklyTrend(days, new Date(2026, 10, 18), 3)
    expect(t.map((w) => [ymd(w.monday), w.count])).toEqual([
      ['2026-11-02', 0],
      ['2026-11-09', 1],
      ['2026-11-16', 3],
    ])
  })
  it('días distintos entrenados', () => {
    expect(daysTrained(days, new Date(2026, 10, 1), new Date(2026, 10, 30))).toBe(3)
  })
})

describe('samePointInPrev', () => {
  it('mismo día del mes anterior, sin pasarse', () => {
    expect(ymd(samePointInPrev(periodRange('month', new Date(2026, 10, 18)), new Date(2026, 10, 18)))).toBe('2026-10-18')
    expect(ymd(samePointInPrev(periodRange('month', new Date(2026, 2, 31)), new Date(2026, 2, 31)))).toBe('2026-02-28')
  })
  it('mismo día de la semana anterior y del año anterior', () => {
    expect(ymd(samePointInPrev(periodRange('week', new Date(2026, 10, 18)), new Date(2026, 10, 18)))).toBe('2026-11-11')
    expect(ymd(samePointInPrev(periodRange('year', new Date(2026, 10, 18)), new Date(2026, 10, 18)))).toBe('2025-11-18')
  })
})

describe('timeAgo', () => {
  const now = new Date(2026, 10, 19, 12, 0)
  it('dice cuánto hace de forma corta', async () => {
    const { timeAgo } = await import('./news')
    expect(timeAgo(new Date(2026, 10, 19, 11, 59, 30), now)).toBe('ahora')
    expect(timeAgo(new Date(2026, 10, 19, 11, 55), now)).toBe('hace 5 min')
    expect(timeAgo(new Date(2026, 10, 19, 9, 0), now)).toBe('hace 3 h')
    expect(timeAgo(new Date(2026, 10, 18, 10, 0), now)).toBe('ayer')
    expect(timeAgo(new Date(2026, 10, 15, 10, 0), now)).toBe('hace 4 días')
    expect(timeAgo(new Date(2026, 10, 2, 10, 0), now)).toBe('2 nov')
  })
})
