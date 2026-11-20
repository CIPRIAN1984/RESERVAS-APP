import { describe, expect, it } from 'vitest'
import { planSessions, planUsageText } from './data'

describe('planUsageText', () => {
  it('cuenta lo que queda en el periodo', () => {
    expect(planUsageText({ period: 'month', limit: 4, used: 1 })).toBe('Te quedan 3 de 4 clases este mes')
    expect(planUsageText({ period: 'week', limit: 1, used: 0 })).toBe('Te queda 1 de 1 clase esta semana')
    expect(planUsageText({ period: 'total', limit: 10, used: 9 })).toBe('Te queda 1 de 10 clases en tu bono')
  })
  it('avisa cuando ya no quedan', () => {
    expect(planUsageText({ period: 'week', limit: 1, used: 1 })).toBe('Ya has usado tu clase de esta semana')
    expect(planUsageText({ period: 'month', limit: 4, used: 5 })).toBe('Ya has usado tus 4 clases de este mes')
  })
  it('hablando de otra persona (vista del personal)', () => {
    expect(planUsageText({ period: 'month', limit: 4, used: 3 }, true)).toBe('Le queda 1 de 4 clases este mes')
    expect(planUsageText({ period: 'week', limit: 1, used: 1 }, true)).toBe('Ha usado su clase de esta semana')
    expect(planUsageText({ period: 'total', limit: 10, used: 2 }, true)).toBe('Le quedan 8 de 10 clases en su bono')
  })
  it('sin límite no dice nada', () => {
    expect(planUsageText({ period: 'none', limit: null, used: null })).toBeNull()
    expect(planUsageText(null)).toBeNull()
  })
})

describe('planSessions', () => {
  it('muestra el límite semanal', () => {
    expect(planSessions({ sessions: null, sessionsPerMonth: true, weeklySessions: 1 })).toBe('1 sesión/semana')
    expect(planSessions({ sessions: 4, sessionsPerMonth: true })).toBe('4 sesiones/mes')
  })
})
