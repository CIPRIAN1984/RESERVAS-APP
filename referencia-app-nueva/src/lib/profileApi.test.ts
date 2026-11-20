import { describe, expect, it } from 'vitest'
import { ageOn, prettyPhone } from './profileApi'

describe('ageOn', () => {
  it('cuenta los años cumplidos', () => {
    expect(ageOn('2018-03-10', new Date(2026, 2, 10))).toBe(8)
    expect(ageOn('2018-03-10', new Date(2026, 2, 9))).toBe(7)
    expect(ageOn('2018-12-31', new Date(2026, 10, 18))).toBe(7)
  })
})

describe('prettyPhone', () => {
  it('agrupa los móviles españoles y quita el prefijo', () => {
    expect(prettyPhone('+34600000000')).toBe('600 00 00 00')
    expect(prettyPhone('34600000000')).toBe('600 00 00 00')
    expect(prettyPhone('600000000')).toBe('600 00 00 00')
  })
  it('deja como está lo que no reconoce', () => {
    expect(prettyPhone('+44 20 7946 0958')).toBe('+44 20 7946 0958')
  })
})
