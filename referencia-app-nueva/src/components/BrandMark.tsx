import { useId } from 'react'

/**
 * Logotipo de ITACA (rebranding): círculo con un corte que forma una "d" y una
 * "p" unidas. Geometría en unidades del radio (círculo de radio 1 centrado en 0,0);
 * la misma geometría se usa en el SVG y en el lienzo de la portada.
 */
export const MARK = {
  hole: { cx: -0.03, cy: -0.03, r: 0.225 },
  // corte superior (a la derecha del hueco) y corte inferior (a la izquierda)
  top: { x: 0.14, w: 0.056 },
  bottom: { x: -0.255, w: 0.056 },
}

/** Dibuja el logotipo en un lienzo: centro (cx, cy) y radio r */
export function drawMark(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, color: string) {
  ctx.save()
  ctx.fillStyle = color
  ctx.beginPath()
  ctx.arc(cx, cy, r, 0, Math.PI * 2)
  ctx.fill()
  ctx.globalCompositeOperation = 'destination-out'
  const { hole, top, bottom } = MARK
  ctx.beginPath()
  ctx.arc(cx + hole.cx * r, cy + hole.cy * r, hole.r * r, 0, Math.PI * 2)
  ctx.fill()
  ctx.fillRect(cx + top.x * r, cy - r * 1.05, top.w * r, r * (1.05 + hole.cy))
  ctx.fillRect(cx + bottom.x * r, cy + hole.cy * r, bottom.w * r, r * 1.1)
  ctx.restore()
}

export function BrandMark({ size = 40, className }: { size?: number; className?: string }) {
  const { hole, top, bottom } = MARK
  const id = `itaca-mark-${useId().replace(/[^a-zA-Z0-9_-]/g, '')}`
  return (
    <svg width={size} height={size} viewBox="-1 -1 2 2" aria-hidden="true" className={className}>
      <defs>
        <mask id={id}>
          <rect x="-1" y="-1" width="2" height="2" fill="white" />
          <circle cx={hole.cx} cy={hole.cy} r={hole.r} fill="black" />
          <rect x={top.x} y={-1.05} width={top.w} height={1.05 + hole.cy} fill="black" />
          <rect x={bottom.x} y={hole.cy} width={bottom.w} height={1.1} fill="black" />
        </mask>
      </defs>
      <circle r="1" fill="currentColor" mask={`url(#${id})`} />
    </svg>
  )
}
