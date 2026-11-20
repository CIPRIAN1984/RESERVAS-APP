import { describe, expect, it } from 'vitest'
import { effectivePresence, isNetworkError, OfflineQueue, type KeyValueStore, type QueuedOp, type SendResult } from './offlineQueue'

class MemStore implements KeyValueStore {
  data = new Map<string, string>()
  getItem(k: string) {
    return this.data.get(k) ?? null
  }
  setItem(k: string, v: string) {
    this.data.set(k, v)
  }
}

/** Servidor falso con la misma regla de idempotencia que check_in / uncheck */
function fakeServer() {
  const marks = new Map<string, { profileId: string; sessionId: string; voided: boolean }>()
  const voids = new Set<string>()
  let online = true
  const send = async (op: QueuedOp): Promise<SendResult> => {
    if (!online) return { status: 'retry' }
    if (op.kind === 'mark') {
      if (marks.has(op.clientId)) return { status: 'ok' }
      const active = [...marks.values()].some((m) => m.sessionId === op.sessionId && m.profileId === op.profileId && !m.voided)
      if (!active) marks.set(op.clientId, { profileId: op.profileId, sessionId: op.sessionId, voided: false })
      return { status: 'ok' }
    }
    if (op.kind === 'unmark') {
      if (voids.has(op.clientId)) return { status: 'ok' }
      voids.add(op.clientId)
      for (const m of marks.values()) if (m.sessionId === op.sessionId && m.profileId === op.profileId) m.voided = true
      return { status: 'ok' }
    }
    return { status: 'drop', message: 'no usado' }
  }
  return {
    send,
    setOnline: (v: boolean) => (online = v),
    present: (sid: string) => [...marks.values()].filter((m) => m.sessionId === sid && !m.voided).map((m) => m.profileId).sort(),
    rows: () => marks.size,
  }
}

const mark = (clientId: string, profileId: string, sessionId = 's1'): QueuedOp => ({ kind: 'mark', clientId, sessionId, profileId, method: 'coach', at: '2026-11-16T18:00:00Z' })
const unmark = (clientId: string, profileId: string, sessionId = 's1'): QueuedOp => ({ kind: 'unmark', clientId, sessionId, profileId, at: '2026-11-16T18:05:00Z' })

describe('cola sin conexión', () => {
  it('en modo avión guarda las marcas y las envía al volver la red', async () => {
    const srv = fakeServer()
    const q = new OfflineQueue('q', new MemStore(), srv.send)
    srv.setOnline(false)
    q.enqueue(mark('c1', 'ana'))
    q.enqueue(mark('c2', 'luis'))
    q.enqueue(mark('c3', 'eva'))
    const r1 = await q.flush()
    expect(r1.offline).toBe(true)
    expect(q.pending()).toHaveLength(3)
    expect(srv.present('s1')).toEqual([])

    srv.setOnline(true)
    const r2 = await q.flush()
    expect(r2.sent).toBe(3)
    expect(q.pending()).toHaveLength(0)
    expect(srv.present('s1')).toEqual(['ana', 'eva', 'luis'])
  })

  it('reenviar la cola entera (p. ej. la respuesta se perdió) no duplica', async () => {
    const srv = fakeServer()
    const store = new MemStore()
    const ops = [mark('c1', 'ana'), mark('c2', 'luis')]
    const q1 = new OfflineQueue('q', store, srv.send)
    ops.forEach((o) => q1.enqueue(o))
    await q1.flush()
    // Otro dispositivo, o el mismo tras reiniciar, reenvía exactamente lo mismo
    const q2 = new OfflineQueue('q2', new MemStore(), srv.send)
    ops.forEach((o) => q2.enqueue(o))
    await q2.flush()
    expect(srv.rows()).toBe(2)
    expect(srv.present('s1')).toEqual(['ana', 'luis'])
  })

  it('respeta el orden: marcar y luego quitar deja a la persona ausente', async () => {
    const srv = fakeServer()
    const q = new OfflineQueue('q', new MemStore(), srv.send)
    srv.setOnline(false)
    q.enqueue(mark('c1', 'ana'))
    q.enqueue(unmark('c2', 'ana'))
    q.enqueue(mark('c3', 'luis'))
    srv.setOnline(true)
    await q.flush()
    expect(srv.present('s1')).toEqual(['luis'])
  })

  it('la cola sobrevive a cerrar la app (se guarda en el dispositivo)', async () => {
    const srv = fakeServer()
    const store = new MemStore()
    srv.setOnline(false)
    const q1 = new OfflineQueue('q', store, srv.send)
    q1.enqueue(mark('c1', 'ana'))
    await q1.flush()
    const q2 = new OfflineQueue('q', store, srv.send)
    expect(q2.pending()).toHaveLength(1)
    srv.setOnline(true)
    await q2.flush()
    expect(srv.present('s1')).toEqual(['ana'])
  })

  it('no encola dos veces la misma operación', () => {
    const q = new OfflineQueue('q', new MemStore(), fakeServer().send)
    q.enqueue(mark('c1', 'ana'))
    q.enqueue(mark('c1', 'ana'))
    expect(q.pending()).toHaveLength(1)
  })

  it('un rechazo del servidor se descarta y no bloquea lo demás', async () => {
    let n = 0
    const q = new OfflineQueue('q', new MemStore(), async () => (n++ === 0 ? { status: 'drop', message: 'Clase cancelada' } : { status: 'ok' }))
    q.enqueue(mark('c1', 'ana'))
    q.enqueue(mark('c2', 'luis'))
    const r = await q.flush()
    expect(r.dropped).toHaveLength(1)
    expect(r.sent).toBe(1)
    expect(q.pending()).toHaveLength(0)
  })

  it('una excepción al enviar cuenta como sin red y se reintenta', async () => {
    const q = new OfflineQueue('q', new MemStore(), async () => {
      throw new TypeError('Failed to fetch')
    })
    q.enqueue(mark('c1', 'ana'))
    const r = await q.flush()
    expect(r.offline).toBe(true)
    expect(q.pending()).toHaveLength(1)
  })

  it('dos envíos a la vez no mandan nada dos veces', async () => {
    let calls = 0
    const q = new OfflineQueue('q', new MemStore(), async () => {
      calls++
      await new Promise((r) => setTimeout(r, 5))
      return { status: 'ok' }
    })
    q.enqueue(mark('c1', 'ana'))
    q.enqueue(mark('c2', 'luis'))
    await Promise.all([q.flush(), q.flush()])
    expect(calls).toBe(2)
  })
})

describe('presencia que ve el profesor', () => {
  it('combina lo del servidor con lo pendiente', () => {
    const p = effectivePresence(['ana', 'luis'], [mark('c1', 'eva'), unmark('c2', 'luis'), mark('c3', 'otro', 's2')], 's1')
    expect([...p].sort()).toEqual(['ana', 'eva'])
  })
})

describe('clasificación de errores', () => {
  it('distingue red de rechazo', () => {
    expect(isNetworkError(new TypeError('Failed to fetch'))).toBe(true)
    expect(isNetworkError({ message: 'Load failed' })).toBe(true)
    expect(isNetworkError({ status: 503, message: 'x' })).toBe(true)
    expect(isNetworkError({ code: '42501', message: 'Solo el personal marca la asistencia de otros' })).toBe(false)
    expect(isNetworkError({ code: 'P0001', message: 'La clase está cancelada' })).toBe(false)
  })
})
