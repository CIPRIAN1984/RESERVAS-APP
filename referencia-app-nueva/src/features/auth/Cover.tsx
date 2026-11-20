import { useCallback, useEffect, useRef, useState } from 'react'
import { drawMark } from '../../components/BrandMark'

/**
 * Portada antes de entrar: logotipo y nombre sobre fondo negro satinado.
 * Al pulsar "Entrar", el logotipo y las letras se deshacen en partículas que
 * caen en espiral hacia un agujero negro; la cámara se acerca hasta que todo
 * queda negro y aparece la pantalla de acceso.
 * Con "reducir movimiento" activado en el sistema, solo funde a negro.
 */

const DURATION = 2600 // ms hasta negro total
const HOLE_START = 450 // ms en que empieza a crecer el agujero

interface Particle {
  x: number
  y: number
  r0: number
  a0: number
  delay: number
  spin: number
  size: number
}

const easeInCubic = (u: number) => u * u * u
const easeInExpo = (u: number) => (u <= 0 ? 0 : Math.pow(2, 10 * u - 10))
const clamp01 = (u: number) => Math.min(1, Math.max(0, u))

function cssVar(name: string, fallback: string) {
  const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim()
  return v || fallback
}

/** "#F3EADB" → "243,234,219" (para usar el color de marca con transparencia) */
function rgbOf(hex: string) {
  const m = hex.replace('#', '')
  const n = parseInt(m.length === 3 ? [...m].map((c) => c + c).join('') : m, 16)
  return `${(n >> 16) & 255},${(n >> 8) & 255},${n & 255}`
}

/** Medidas de la composición para un lienzo de w × h */
function layout(w: number, h: number) {
  const r = Math.round(Math.min(90, Math.max(46, Math.min(w, h) * 0.12)))
  const cx = w / 2
  const cy = h * 0.44
  const fontSize = Math.round(r * 0.42)
  const textY = cy + r + fontSize * 1.55
  return { r, cx, cy, fontSize, textY }
}

/** Dibuja el nombre con espaciado entre letras (centrado en cx) */
function drawWord(ctx: CanvasRenderingContext2D, word: string, cx: number, y: number, fontSize: number, color: string) {
  ctx.save()
  ctx.fillStyle = color
  ctx.font = `500 ${fontSize}px Inter, system-ui, sans-serif`
  ctx.textBaseline = 'middle'
  const spacing = fontSize * 0.42
  const widths = [...word].map((c) => ctx.measureText(c).width)
  const total = widths.reduce((a, b) => a + b, 0) + spacing * (word.length - 1)
  let x = cx - total / 2
  ;[...word].forEach((c, i) => {
    ctx.fillText(c, x, y)
    x += widths[i] + spacing
  })
  ctx.restore()
}

/** Fondo negro con brillos diagonales suaves, como una tela satinada */
function paintBackground(ctx: CanvasRenderingContext2D, w: number, h: number, black: string) {
  ctx.fillStyle = black
  ctx.fillRect(0, 0, w, h)
  const bands = [
    { at: 0.18, width: 0.22, alpha: 0.06 },
    { at: 0.62, width: 0.3, alpha: 0.035 },
    { at: 0.9, width: 0.16, alpha: 0.05 },
  ]
  for (const b of bands) {
    const g = ctx.createLinearGradient(0, h * 0.15, w, h * 0.85)
    const a = Math.max(0, b.at - b.width / 2)
    const z = Math.min(1, b.at + b.width / 2)
    g.addColorStop(a, 'rgba(255,255,255,0)')
    g.addColorStop(b.at, `rgba(255,255,255,${b.alpha})`)
    g.addColorStop(z, 'rgba(255,255,255,0)')
    ctx.fillStyle = g
    ctx.fillRect(0, 0, w, h)
  }
  // viñeta
  const v = ctx.createRadialGradient(w / 2, h * 0.45, Math.min(w, h) * 0.2, w / 2, h * 0.45, Math.max(w, h) * 0.8)
  v.addColorStop(0, 'rgba(0,0,0,0)')
  v.addColorStop(1, 'rgba(0,0,0,0.55)')
  ctx.fillStyle = v
  ctx.fillRect(0, 0, w, h)
}

export function Cover({ onDone }: { onDone: () => void }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [phase, setPhase] = useState<'idle' | 'going'>('idle')
  const state = useRef<{ w: number; h: number; dpr: number; bg: HTMLCanvasElement | null; particles: Particle[]; raf: number }>({
    w: 0,
    h: 0,
    dpr: 1,
    bg: null,
    particles: [],
    raf: 0,
  })

  // Composición estática (y al cambiar el tamaño de la ventana)
  const paintStatic = useCallback(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const s = state.current
    const dpr = Math.min(2, window.devicePixelRatio || 1)
    const w = window.innerWidth
    const h = window.innerHeight
    s.w = w
    s.h = h
    s.dpr = dpr
    canvas.width = Math.round(w * dpr)
    canvas.height = Math.round(h * dpr)
    canvas.style.width = `${w}px`
    canvas.style.height = `${h}px`

    const bg = document.createElement('canvas')
    bg.width = canvas.width
    bg.height = canvas.height
    const bctx = bg.getContext('2d')!
    bctx.scale(dpr, dpr)
    paintBackground(bctx, w, h, cssVar('--brand-black', '#080808'))
    s.bg = bg

    const ctx = canvas.getContext('2d')!
    ctx.setTransform(1, 0, 0, 1, 0, 0)
    ctx.drawImage(bg, 0, 0)
    ctx.scale(dpr, dpr)
    const L = layout(w, h)
    const cream = cssVar('--brand-cream', '#F3EADB')
    drawMark(ctx, L.cx, L.cy, L.r, cream)
    drawWord(ctx, 'ITACA', L.cx, L.textY, L.fontSize, cream)
  }, [])

  useEffect(() => {
    let alive = true
    const draw = () => alive && state.current.raf === 0 && paintStatic()
    void (document.fonts?.ready ?? Promise.resolve()).then(draw)
    draw()
    window.addEventListener('resize', draw)
    return () => {
      alive = false
      window.removeEventListener('resize', draw)
      cancelAnimationFrame(state.current.raf)
    }
  }, [paintStatic])

  const start = () => {
    if (phase !== 'idle') return
    setPhase('going')
    const reduce = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
    if (reduce) {
      setTimeout(onDone, 350)
      return
    }
    const canvas = canvasRef.current
    if (!canvas) return onDone()
    const s = state.current
    const { w, h, dpr } = s
    const L = layout(w, h)
    const cream = cssVar('--brand-cream', '#F3EADB')
    const black = cssVar('--brand-black', '#080808')
    const creamRgb = rgbOf(cream)

    // Partículas: se toman los píxeles del logotipo y del nombre
    const off = document.createElement('canvas')
    off.width = w
    off.height = h
    const octx = off.getContext('2d', { willReadFrequently: true })!
    drawMark(octx, L.cx, L.cy, L.r, '#fff')
    drawWord(octx, 'ITACA', L.cx, L.textY, L.fontSize, '#fff')
    const x0 = Math.floor(L.cx - L.r * 2.2)
    const y0 = Math.floor(L.cy - L.r * 1.1)
    const bw = Math.ceil(L.r * 4.4)
    const bh = Math.ceil(L.textY + L.fontSize - y0)
    const data = octx.getImageData(x0, y0, bw, bh).data
    const filled = (L.r * L.r * Math.PI * 0.8 + bw * L.fontSize * 0.25) || 1
    const step = Math.max(2, Math.round(Math.sqrt(filled / 4500)))
    const particles: Particle[] = []
    for (let y = 0; y < bh; y += step) {
      for (let x = 0; x < bw; x += step) {
        if (data[(y * bw + x) * 4 + 3] < 120) continue
        const px = x0 + x
        const py = y0 + y
        const dx = px - L.cx
        const dy = py - L.cy
        const rnd = Math.random()
        particles.push({
          x: px,
          y: py,
          r0: Math.hypot(dx, dy),
          a0: Math.atan2(dy, dx),
          // se deshace de fuera hacia dentro, con algo de azar
          delay: 120 + 520 * rnd + 160 * (1 - Math.min(1, Math.hypot(dx, dy) / (L.r * 2.4))),
          spin: 1.6 + Math.random() * 1.6,
          size: step * (0.8 + Math.random() * 0.5),
        })
      }
    }
    s.particles = particles

    const ctx = canvas.getContext('2d')!
    const diag = Math.hypot(w, h)
    const t0 = performance.now()

    const frame = (now: number, still = false) => {
      const t = now - t0
      const k = clamp01(t / DURATION)
      // Cámara: se acerca al centro del logotipo
      const zoom = 1 + 2.2 * easeInCubic(k) + 4 * easeInExpo(k)
      ctx.setTransform(1, 0, 0, 1, 0, 0)
      ctx.fillStyle = black
      ctx.fillRect(0, 0, canvas.width, canvas.height)
      ctx.setTransform(dpr * zoom, 0, 0, dpr * zoom, dpr * L.cx * (1 - zoom), dpr * L.cy * (1 - zoom))
      if (s.bg) ctx.drawImage(s.bg, 0, 0, w, h)

      // Partículas en espiral hacia el centro
      ctx.fillStyle = cream
      for (const p of s.particles) {
        const u = clamp01((t - p.delay) / 1300)
        if (u >= 1) continue
        let x = p.x
        let y = p.y
        let alpha = 1
        let size = p.size
        if (u > 0) {
          const pull = easeInCubic(u)
          const lift = Math.sin(Math.PI * Math.min(1, u * 1.6)) * 0.18 // se separa un poco antes de caer
          const r = p.r0 * (1 + lift) * (1 - pull)
          const a = p.a0 + p.spin * pull * (1 + 2.5 * pull)
          x = L.cx + Math.cos(a) * r
          y = L.cy + Math.sin(a) * r
          alpha = 1 - u * u
          size = p.size * (1 - 0.6 * u)
        }
        ctx.globalAlpha = alpha
        ctx.fillRect(x - size / 2, y - size / 2, size, size)
      }
      ctx.globalAlpha = 1

      // Agujero negro (en pantalla): disco que crece con un halo
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      const hk = clamp01((t - HOLE_START) / (DURATION - HOLE_START))
      const rb = 2 + diag * 0.62 * easeInExpo(hk) + L.r * 0.35 * Math.sin(Math.PI * Math.min(1, hk * 2))
      if (t > HOLE_START) {
        const glow = ctx.createRadialGradient(L.cx, L.cy, rb * 0.9, L.cx, L.cy, rb * 2.2 + 30)
        glow.addColorStop(0, `rgba(${creamRgb},0.45)`)
        glow.addColorStop(0.18, `rgba(${creamRgb},0.14)`)
        glow.addColorStop(1, `rgba(${creamRgb},0)`)
        ctx.fillStyle = glow
        ctx.fillRect(0, 0, w, h)
        ctx.fillStyle = black
        ctx.beginPath()
        ctx.arc(L.cx, L.cy, rb, 0, Math.PI * 2)
        ctx.fill()
        // anillo fino (borde del horizonte)
        ctx.strokeStyle = `rgba(${creamRgb},${0.5 * (1 - hk)})`
        ctx.lineWidth = 1.5
        ctx.stroke()
      }

      if (still) return
      if (t < DURATION) {
        s.raf = requestAnimationFrame((n) => frame(n))
      } else {
        ctx.setTransform(1, 0, 0, 1, 0, 0)
        ctx.fillStyle = black
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        s.raf = 0
        setTimeout(onDone, 180)
      }
    }
    // Solo en desarrollo: congelar la animación para revisarla fotograma a fotograma
    const w8 = window as unknown as { __portadaPausa?: boolean; __portadaVer?: (ms: number) => void }
    if (import.meta.env.DEV && w8.__portadaPausa) {
      w8.__portadaVer = (ms: number) => frame(t0 + ms, true)
      frame(t0, true)
      return
    }
    s.raf = requestAnimationFrame((n) => frame(n))
  }

  return (
    <div className="fixed inset-0 z-50 overflow-hidden bg-brand-black">
      <h1 className="sr-only">ITACA</h1>
      <canvas ref={canvasRef} aria-hidden="true" className="absolute inset-0" />
      <div
        className="absolute inset-x-0 flex justify-center px-8 transition-opacity duration-300"
        style={{ bottom: 'calc(56px + env(safe-area-inset-bottom))', opacity: phase === 'idle' ? 1 : 0 }}
      >
        <button
          type="button"
          onClick={start}
          disabled={phase !== 'idle'}
          className="h-14 w-full max-w-[360px] rounded-full border-0 bg-brand-cream text-[18px] font-bold text-brand-black shadow-[0_8px_30px_rgba(0,0,0,0.5)] active:scale-[0.98]"
        >
          Entrar
        </button>
      </div>
      {/* Con "reducir movimiento": fundido a negro */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 bg-brand-black transition-opacity duration-300"
        style={{ opacity: phase === 'going' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 1 : 0 }}
      />
    </div>
  )
}
