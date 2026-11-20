import { useEffect, type ButtonHTMLAttributes, type ReactNode } from 'react'
import { useNavigate } from 'react-router'
import { BELT_COLOR, BELT_LABEL } from '../lib/data'
import type { Belt } from '../lib/types'
import { IconBack, IconClose } from './icons'

const cx = (...c: (string | false | null | undefined)[]) => c.filter(Boolean).join(' ')

/**
 * Titular de pantalla: negrita, en minúsculas normales ("Estadísticas").
 * `size` se conserva por compatibilidad; los titulares viejos de 48 px pasan a 32 px.
 */
export function Title({ children, size = 48, as: As = 'h1' }: { children: ReactNode; size?: number; as?: 'h1' | 'h2' }) {
  const px = Math.round(Math.min(size, 56) * 0.66)
  return (
    <As className="m-0 font-sans font-bold leading-[1.1] tracking-[-0.02em]" style={{ fontSize: px }}>
      {children}
    </As>
  )
}

/** Etiqueta pequeña en mayúsculas y letra de máquina ("NOVIEMBRE 2026 · MADRID") */
export function Eyebrow({ children, onInk }: { children: ReactNode; onInk?: boolean }) {
  return (
    <span className={cx('font-mono text-[11px] font-medium uppercase tracking-[0.06em]', onInk ? 'text-muted-on-ink' : 'text-muted')}>
      {children}
    </span>
  )
}

export function Card({ children, className, radius = 18 }: { children: ReactNode; className?: string; radius?: number }) {
  return (
    <div className={cx('bg-surface flex flex-col', className)} style={{ borderRadius: radius }}>
      {children}
    </div>
  )
}

type ChipTone = 'ok' | 'warn' | 'err' | 'neutral' | 'accent' | 'surface'
const chipTone: Record<ChipTone, string> = {
  ok: 'bg-ok-bg text-ok-fg',
  warn: 'bg-warn-bg text-warn-fg',
  err: 'bg-err-bg text-err-fg',
  neutral: 'bg-neutral text-ink-2',
  accent: 'bg-accent text-on-accent',
  surface: 'bg-surface-2 text-ink',
}
export function Chip({ tone, children, small }: { tone: ChipTone; children: ReactNode; small?: boolean }) {
  return (
    <span
      className={cx(
        'inline-flex items-center whitespace-nowrap rounded-full font-semibold',
        small ? 'px-[9px] py-[5px] text-[11px]' : 'px-[10px] py-[5px] text-[12px]',
        chipTone[tone],
      )}
    >
      {children}
    </span>
  )
}

/**
 * Botones. "accent" e "ink" son el botón principal: blanco con texto negro en
 * oscuro, negro con texto blanco en claro. El amarillo queda para "highlight".
 */
type BtnVariant = 'accent' | 'ink' | 'outline' | 'ghost' | 'soft' | 'highlight' | 'coral'
// Al pasar el ratón (solo en dispositivos con ratón), los botones se ponen amarillos.
// Cancelar (coral) no: es una acción destructiva y se oscurece un poco.
const HOVER = 'enabled:hover:bg-accent enabled:hover:text-on-accent enabled:hover:border-accent'
const btnVariant: Record<BtnVariant, string> = {
  accent: `bg-ink text-on-ink font-semibold border-0 ${HOVER}`,
  ink: `bg-ink text-on-ink font-semibold border-0 ${HOVER}`,
  highlight: 'bg-accent text-on-accent font-semibold border-0',
  coral: 'bg-coral text-on-coral font-semibold border-0 enabled:hover:brightness-110',
  outline: `bg-transparent text-ink font-semibold border border-border ${HOVER}`,
  ghost: 'bg-transparent text-ink font-semibold border-0 underline underline-offset-4 enabled:hover:text-accent',
  soft: `bg-surface-2 text-ink font-semibold border-0 ${HOVER}`,
}
export function Btn({
  variant = 'ink',
  size = 'md',
  block,
  className,
  children,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: BtnVariant; size?: 'sm' | 'md' | 'lg'; block?: boolean }) {
  const sizes = { sm: 'h-11 px-4 text-[14px]', md: 'h-12 px-5 text-[15px]', lg: 'h-[52px] px-6 text-[16px]' }
  return (
    <button
      className={cx(
        'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-[12px] transition-[transform,opacity,background-color,color,border-color,filter] duration-300 active:scale-[0.98] disabled:opacity-40',
        sizes[size],
        btnVariant[variant],
        block && 'w-full',
        className,
      )}
      {...rest}
    >
      {children}
    </button>
  )
}

export function FilterChip({ active, children, onClick }: { active: boolean; children: ReactNode; onClick: () => void }) {
  return (
    <button
      aria-pressed={active}
      onClick={onClick}
      className={cx(
        'h-10 shrink-0 rounded-full border-0 px-4 text-[14px] transition-colors duration-200 hover:bg-accent hover:text-on-accent',
        active ? 'bg-ink text-on-ink font-semibold' : 'bg-surface-2 text-muted font-medium',
      )}
    >
      {children}
    </button>
  )
}

export function Avatar({
  text,
  size = 40,
  tone = 'surface',
  className,
  src,
}: {
  text: string
  size?: number
  tone?: 'ink' | 'surface' | 'grey'
  className?: string
  /** Foto de perfil; si no hay, se muestran las iniciales */
  src?: string | null
}) {
  const tones = { ink: 'bg-ink text-on-ink', surface: 'bg-surface-2 text-ink', grey: 'bg-avatar text-ink' }
  if (src) {
    return (
      <img
        src={src}
        alt=""
        aria-hidden="true"
        className={cx('shrink-0 rounded-full object-cover', className)}
        style={{ width: size, height: size }}
      />
    )
  }
  return (
    <span
      aria-hidden="true"
      className={cx('inline-flex shrink-0 items-center justify-center rounded-full font-bold', tones[tone], className)}
      style={{ width: size, height: size, fontSize: size <= 32 ? 11 : size <= 40 ? 13 : 14 }}
    >
      {text}
    </span>
  )
}

export function ProgressBar({
  value,
  height = 8,
  accent,
  label,
  track = 'bg-track',
}: {
  value: number
  height?: number
  accent?: boolean
  label?: string
  track?: string
}) {
  const pct = Math.max(0, Math.min(100, value))
  return (
    <div
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      className={cx('overflow-hidden rounded-full', track)}
      style={{ height }}
    >
      <div
        className={cx('h-full rounded-full', accent ? 'bg-accent' : 'bg-ink')}
        style={{ width: `${pct}%` }}
      />
    </div>
  )
}

/** Cinturón con su barra negra y grados */
export function BeltBar({ belt, stripes, height = 22 }: { belt: Belt; stripes: number; height?: number }) {
  const tip = belt === 'negro' ? '#B3261E' : '#0A0A0A'
  const stripeW = height > 24 ? 8 : 6
  return (
    <div
      role="img"
      aria-label={`Cinturón ${BELT_LABEL[belt].toLowerCase()}${stripes ? ` con ${stripes} ${stripes === 1 ? 'grado' : 'grados'}` : ''}`}
      className="flex justify-end overflow-hidden"
      style={{
        height,
        borderRadius: height > 24 ? 8 : 6,
        background: BELT_COLOR[belt],
        // borde sutil: en el tema oscuro, el negro y el blanco se confunden con el fondo
        boxShadow: 'inset 0 0 0 1px var(--border)',
      }}
    >
      <div className="flex h-full items-center justify-center" style={{ width: height > 24 ? 96 : 76, background: tip, gap: height > 24 ? 10 : 8 }}>
        {Array.from({ length: stripes }).map((_, i) => (
          <div key={i} className="h-full bg-white" style={{ width: stripeW }} />
        ))}
      </div>
    </div>
  )
}

export function Stat({ value, label, size = 36, compact }: { value: ReactNode; label: string; size?: number; compact?: boolean }) {
  return (
    <div className={cx('flex flex-1 flex-col gap-1 bg-surface', compact ? 'rounded-2xl px-3 py-3' : 'rounded-[18px] p-4')}>
      <span className="font-sans font-bold leading-none tracking-[-0.02em]" style={{ fontSize: Math.round(size * 0.8) }}>
        {value}
      </span>
      <span className={cx('text-muted', compact ? 'text-[11px]' : 'text-[13px]')}>{label}</span>
    </div>
  )
}

export function BackButton({ label, to }: { label: string; to?: string }) {
  const nav = useNavigate()
  return (
    <button
      aria-label={label}
      onClick={() => (to ? nav(to) : window.history.length > 1 ? nav(-1) : nav('/'))}
      className="-ml-2 flex h-11 w-11 shrink-0 items-center justify-center rounded-full border-0 bg-transparent text-ink"
    >
      <IconBack size={24} />
    </button>
  )
}

export function Row({ label, value, last }: { label: string; value: ReactNode; last?: boolean }) {
  return (
    <div className={cx('flex justify-between gap-4 py-3', !last && 'border-b border-line')}>
      <span className="text-[14px] text-muted">{label}</span>
      <span className="text-right text-[14px] font-semibold">{value}</span>
    </div>
  )
}

/** Hoja inferior modal */
export function Sheet({ open, onClose, title, children }: { open: boolean; onClose: () => void; title: string; children: ReactNode }) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])
  if (!open) return null
  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center md:items-center md:p-6" role="dialog" aria-modal="true" aria-label={title}>
      <button aria-label="Cerrar" className="absolute inset-0 border-0 bg-black/60" onClick={onClose} />
      <div className="pb-safe relative w-full max-w-[480px] rounded-t-[24px] border-t border-line bg-surface px-5 pt-5 shadow-2xl md:max-w-[560px] md:rounded-[24px] md:border md:px-6 md:pt-6">
        <div className="mb-4 flex items-center justify-between gap-3">
          <h2 className="m-0 text-[20px] font-bold">{title}</h2>
          <button aria-label="Cerrar" onClick={onClose} className="flex h-11 w-11 items-center justify-center rounded-full border-0 bg-surface-2 text-ink">
            <IconClose size={20} />
          </button>
        </div>
        <div className="flex max-h-[70vh] flex-col gap-2 overflow-y-auto pb-6">{children}</div>
      </div>
    </div>
  )
}

export function EmptyState({ title, text, action }: { title: string; text: string; action?: ReactNode }) {
  return (
    <Card className="items-start gap-2 p-5">
      <span className="text-[17px] font-bold">{title}</span>
      <p className="m-0 text-[14px] text-muted">{text}</p>
      {action && <div className="mt-2">{action}</div>}
    </Card>
  )
}

export { cx }
