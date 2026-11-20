import { useEffect, useRef, useState } from 'react'
import jsQR from 'jsqr'

/**
 * Lector de QR con la cámara trasera. El escáner va dentro de la app porque,
 * en iPhone, escanear con la cámara del sistema abre Safari y no la app instalada.
 */
export function QrScanner({ onResult, paused }: { onResult: (text: string) => void; paused?: boolean }) {
  const video = useRef<HTMLVideoElement>(null)
  const canvas = useRef<HTMLCanvasElement>(null)
  const [error, setError] = useState<string | null>(null)
  const onResultRef = useRef(onResult)
  onResultRef.current = onResult
  const pausedRef = useRef(paused)
  pausedRef.current = paused

  useEffect(() => {
    let stream: MediaStream | null = null
    let raf = 0
    let last = 0
    let stopped = false

    const tick = (t: number) => {
      if (stopped) return
      raf = requestAnimationFrame(tick)
      if (pausedRef.current || t - last < 150) return
      last = t
      const v = video.current
      const c = canvas.current
      if (!v || !c || v.readyState < 2) return
      const w = Math.min(640, v.videoWidth)
      const h = Math.round((v.videoHeight / v.videoWidth) * w)
      c.width = w
      c.height = h
      const ctx = c.getContext('2d', { willReadFrequently: true })
      if (!ctx) return
      ctx.drawImage(v, 0, 0, w, h)
      const img = ctx.getImageData(0, 0, w, h)
      const code = jsQR(img.data, w, h, { inversionAttempts: 'dontInvert' })
      if (code?.data) onResultRef.current(code.data)
    }

    ;(async () => {
      if (!navigator.mediaDevices?.getUserMedia) {
        setError('Este navegador no permite usar la cámara.')
        return
      }
      try {
        stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false })
        if (stopped) {
          stream.getTracks().forEach((t) => t.stop())
          return
        }
        if (video.current) {
          video.current.srcObject = stream
          await video.current.play().catch(() => undefined)
        }
        raf = requestAnimationFrame(tick)
      } catch (e) {
        const name = (e as { name?: string }).name
        setError(
          name === 'NotAllowedError'
            ? 'No hay permiso para usar la cámara. Actívalo en los ajustes del navegador.'
            : 'No se encuentra ninguna cámara en este dispositivo.',
        )
      }
    })()

    return () => {
      stopped = true
      cancelAnimationFrame(raf)
      stream?.getTracks().forEach((t) => t.stop())
    }
  }, [])

  if (error) {
    return <p className="m-0 w-full rounded-2xl bg-warn-bg px-4 py-3 text-[14px] font-medium text-warn-fg">{error}</p>
  }
  return (
    <div className="relative aspect-square w-full max-w-[300px] overflow-hidden rounded-[28px] bg-[#0A0A0A]">
      <video ref={video} playsInline muted className="h-full w-full object-cover" />
      <span aria-hidden="true" className="absolute inset-6 rounded-2xl border-2 border-dashed border-accent" />
      <canvas ref={canvas} className="hidden" />
    </div>
  )
}

/** Extrae el código de la sede de un QR de ITACA ("itaca:checkin:<código>") */
export function parseCheckinQr(text: string): string | null {
  const m = /^itaca:checkin:([A-Za-z0-9_-]{4,64})$/.exec(text.trim())
  return m ? m[1] : null
}

/** Pitido corto de confirmación */
export function beep() {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext
    const ctx = new Ctx()
    const o = ctx.createOscillator()
    const g = ctx.createGain()
    o.frequency.value = 880
    g.gain.setValueAtTime(0.15, ctx.currentTime)
    g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.25)
    o.connect(g).connect(ctx.destination)
    o.start()
    o.stop(ctx.currentTime + 0.25)
  } catch {
    /* sin audio */
  }
}
