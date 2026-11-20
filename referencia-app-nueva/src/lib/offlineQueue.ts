/**
 * Cola sin conexión para pasar lista y check-in (principio 3 del plan).
 *
 * - Cada marca lleva un clientId generado en el móvil; el servidor lo usa para
 *   no duplicar si la misma marca llega dos veces.
 * - La cola se guarda en el dispositivo y se envía en orden al volver la red.
 * - Un fallo de red deja la operación en cola; un rechazo del servidor
 *   (permiso, clase cancelada…) la descarta y se avisa.
 */

export type QueuedOp =
  | { kind: 'mark'; clientId: string; sessionId: string; profileId: string; method: 'coach' | 'kiosk'; at: string }
  | { kind: 'unmark'; clientId: string; sessionId: string; profileId: string; at: string }
  | { kind: 'code'; clientId: string; code: string; at: string }

/** ok: aceptada · retry: sin red, reintentar · drop: rechazada, descartar */
export type SendResult = { status: 'ok' } | { status: 'retry' } | { status: 'drop'; message: string }
export type Sender = (op: QueuedOp) => Promise<SendResult>

export interface KeyValueStore {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
}

export class OfflineQueue {
  private ops: QueuedOp[]
  private flushing: Promise<FlushReport> | null = null
  private listeners = new Set<() => void>()

  constructor(
    private readonly key: string,
    private readonly storage: KeyValueStore | null,
    private readonly send: Sender,
  ) {
    this.ops = this.read()
  }

  private read(): QueuedOp[] {
    try {
      const raw = this.storage?.getItem(this.key)
      return raw ? (JSON.parse(raw) as QueuedOp[]) : []
    } catch {
      return []
    }
  }

  private write() {
    try {
      this.storage?.setItem(this.key, JSON.stringify(this.ops))
    } catch {
      /* sin almacenamiento: la cola vive en memoria */
    }
    this.listeners.forEach((l) => l())
  }

  subscribe(fn: () => void): () => void {
    this.listeners.add(fn)
    return () => this.listeners.delete(fn)
  }

  pending(): readonly QueuedOp[] {
    return this.ops
  }

  enqueue(op: QueuedOp) {
    if (this.ops.some((o) => o.clientId === op.clientId)) return
    this.ops = [...this.ops, op]
    this.write()
  }

  /** Envía en orden. Se detiene en el primer fallo de red para respetar el orden. */
  flush(): Promise<FlushReport> {
    if (this.flushing) return this.flushing
    this.flushing = (async () => {
      const report: FlushReport = { sent: 0, dropped: [], offline: false }
      while (this.ops.length) {
        const op = this.ops[0]
        let r: SendResult
        try {
          r = await this.send(op)
        } catch {
          r = { status: 'retry' }
        }
        if (r.status === 'retry') {
          report.offline = true
          break
        }
        if (r.status === 'drop') report.dropped.push({ op, message: r.message })
        else report.sent++
        this.ops = this.ops.slice(1)
        this.write()
      }
      return report
    })().finally(() => {
      this.flushing = null
    })
    return this.flushing
  }
}

export interface FlushReport {
  sent: number
  dropped: { op: QueuedOp; message: string }[]
  offline: boolean
}

/**
 * Lo que debe ver el profesor: lo confirmado por el servidor más lo que aún
 * está en cola (una marca o un "quitar" pendientes ganan al dato del servidor).
 */
export function effectivePresence(serverPresent: Iterable<string>, ops: readonly QueuedOp[], sessionId: string): Set<string> {
  const present = new Set(serverPresent)
  for (const op of ops) {
    if (op.kind === 'code' || op.sessionId !== sessionId) continue
    if (op.kind === 'mark') present.add(op.profileId)
    else present.delete(op.profileId)
  }
  return present
}

/** Un error de red (sin cobertura, servidor caído) se reintenta; el resto se descarta */
export function isNetworkError(e: unknown): boolean {
  if (!e) return false
  const err = e as { message?: string; status?: number; code?: string; name?: string }
  if (err.name === 'TypeError') return true
  const msg = (err.message ?? '').toLowerCase()
  if (msg.includes('failed to fetch') || msg.includes('network') || msg.includes('load failed') || msg.includes('fetch')) return true
  if (typeof err.status === 'number' && (err.status === 0 || err.status >= 500)) return true
  return false
}

export function newClientId(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID()
  // Respaldo para navegadores antiguos (UUID v4)
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16)
  })
}
