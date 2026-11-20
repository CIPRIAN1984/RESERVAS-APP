import { NavLink, Outlet } from 'react-router'
import { usePendingPlanRequests } from '../lib/planRequests'
import { useNewsUnread } from '../lib/news'
import { BrandMark } from './BrandMark'
import type { ComponentType, ReactNode } from 'react'
import { useApp } from '../lib/store'
import { useAuth } from '../features/auth/AuthProvider'
import { IconCalendar, IconCard, IconHome, IconMore, IconNews, IconProfile, IconStats, IconUsers } from './icons'
import { cx } from './ui'

interface Tab {
  to: string
  label: string
  Icon: ComponentType<{ size?: number; strokeWidth?: number }>
  end?: boolean
}

/** Cuatro pestañas, como la referencia: Inicio, Estadísticas, Novedades y Perfil */
const STUDENT_TABS: Tab[] = [
  { to: '/', label: 'Inicio', Icon: IconHome, end: true },
  { to: '/estadisticas', label: 'Estadísticas', Icon: IconStats },
  { to: '/novedades', label: 'Novedades', Icon: IconNews },
  { to: '/perfil', label: 'Perfil', Icon: IconProfile },
]

const STAFF_TABS: Tab[] = [
  { to: '/staff', label: 'Pasar lista', Icon: IconHome, end: true },
  { to: '/staff/alumnos', label: 'Alumnos', Icon: IconUsers },
  { to: '/staff/horario', label: 'Horario', Icon: IconCalendar },
  { to: '/staff/tarifas', label: 'Tarifas', Icon: IconCard },
  { to: '/staff/mas', label: 'Más', Icon: IconMore },
]

/** Barra inferior: solo en móvil */
/** Punto amarillo sobre el icono: hay algo nuevo */
function Dot({ n }: { n?: boolean | number }) {
  if (typeof n === 'number')
    return (
      <span aria-hidden="true" className="absolute -right-2 -top-1.5 flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-accent px-1 text-[11px] font-bold text-on-accent ring-2 ring-bg">
        {n > 9 ? '9+' : n}
      </span>
    )
  return <span aria-hidden="true" className="absolute -right-0.5 -top-0.5 h-2.5 w-2.5 rounded-full bg-accent ring-2 ring-bg" />
}

function BottomNav({ tabs, label, dots = {} }: { tabs: Tab[]; label: string; dots?: Record<string, boolean | number> }) {
  return (
    <nav aria-label={label} className="pb-safe sticky bottom-0 z-20 border-t border-line bg-bg md:hidden">
      <div className="flex h-[64px] px-2">
        {tabs.map(({ to, label, Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            aria-label={typeof dots[to] === 'number' && dots[to] ? `${label} (${dots[to]} por aprobar)` : dots[to] ? `${label} (hay novedades)` : label}
            className={({ isActive }) =>
              cx('flex flex-1 items-center justify-center no-underline', isActive ? 'text-nav-active' : 'text-muted')
            }
          >
            {({ isActive }) => (
              <span className="relative">
                <Icon size={26} strokeWidth={isActive ? 2.2 : 1.8} />
                {!!dots[to] && (typeof dots[to] === 'number' || !isActive) && <Dot n={dots[to]} />}
              </span>
            )}
          </NavLink>
        ))}
      </div>
    </nav>
  )
}

/** Menú lateral: tablet y portátil */
function SideNav({ tabs, label, other, dots = {} }: { tabs: Tab[]; label: string; other?: { to: string; label: string }; dots?: Record<string, boolean | number> }) {
  return (
    <nav
      aria-label={label}
      className="sticky top-0 hidden h-dvh w-[200px] shrink-0 flex-col gap-1 border-r border-line bg-bg px-3 py-6 md:flex lg:w-[232px]"
    >
      <span className="mb-6 flex items-center gap-2 px-3">
        <BrandMark size={36} className="text-ink" />
        <span className="flex flex-col leading-tight">
          <span className="text-[16px] font-bold tracking-[0.18em]">ITACA</span>
          <span className="font-mono text-[10px] uppercase tracking-[0.12em] text-muted">Jiu Jitsu</span>
        </span>
      </span>
      {tabs.map(({ to, label, Icon, end }) => (
        <NavLink
          key={to}
          to={to}
          end={end}
          className={({ isActive }) =>
            cx(
              'flex h-12 items-center gap-3 rounded-[12px] px-3 text-[15px] no-underline',
              isActive ? 'bg-surface font-semibold text-ink [&>svg]:text-nav-active' : 'font-medium text-muted hover:bg-surface hover:text-ink',
            )
          }
        >
          {({ isActive }) => (
            <>
              <Icon size={22} strokeWidth={isActive ? 2.4 : 2} />
              {label}
              {typeof dots[to] === 'number' && dots[to] ? (
                <span aria-label={`${dots[to]} por aprobar`} className="ml-auto flex h-[20px] min-w-[20px] items-center justify-center rounded-full bg-accent px-1.5 text-[12px] font-bold text-on-accent">
                  {dots[to]}
                </span>
              ) : (
                dots[to] === true && !isActive && <span aria-label="hay novedades" className="ml-auto h-2.5 w-2.5 rounded-full bg-accent" />
              )}
            </>
          )}
        </NavLink>
      ))}
      {other && (
        <NavLink to={other.to} className="mt-auto flex h-11 items-center rounded-2xl px-3 text-[13px] font-semibold text-muted no-underline hover:bg-surface hover:text-ink">
          {other.label}
        </NavLink>
      )}
    </nav>
  )
}

function Toasts() {
  const { toasts } = useApp()
  return (
    <div aria-live="polite" className="pointer-events-none fixed inset-x-0 bottom-[104px] z-50 flex flex-col items-center gap-2 px-4 md:bottom-8">
      {toasts.map((t) => (
        <div key={t.id} className="max-w-[440px] rounded-[14px] bg-ink px-4 py-3 text-[14px] font-medium text-on-ink shadow-lg">
          {t.text}
        </div>
      ))}
    </div>
  )
}

/**
 * Marco de la app. En móvil, columna a pantalla completa; en tablet y
 * portátil, menú lateral y contenido centrado con un ancho cómodo.
 */
export function Frame({ children, side }: { children: ReactNode; side?: ReactNode }) {
  return (
    <div className="flex min-h-dvh justify-center bg-page">
      <div className="relative flex min-h-dvh w-full max-w-[480px] bg-bg text-ink md:max-w-[1280px]">
        {side}
        <div className="flex min-w-0 flex-1 flex-col">{children}</div>
      </div>
      <Toasts />
    </div>
  )
}

/** Ancho del contenido en pantallas grandes */
const CONTENT = 'mx-auto flex w-full flex-1 flex-col md:max-w-[880px]'

export function StudentLayout() {
  const { isStaff, memberships, mode } = useAuth()
  const unread = useNewsUnread(mode === 'live' ? memberships[0]?.gymId : undefined)
  usePlanRequestAlerts()
  const dots = { '/novedades': unread }
  return (
    <Frame side={<SideNav tabs={STUDENT_TABS} label="Navegación principal" dots={dots} other={isStaff ? { to: '/staff', label: 'Vista del personal →' } : undefined} />}>
      <main className={CONTENT}>
        <Outlet />
      </main>
      <BottomNav tabs={STUDENT_TABS} label="Navegación principal" dots={dots} />
    </Frame>
  )
}

/**
 * Aviso al personal (recepción y administración) cuando un alumno pide una tarifa:
 * mensaje emergente al momento y el número de solicitudes por aprobar.
 */
function usePlanRequestAlerts(): number {
  const { memberships, mode } = useAuth()
  const app = useApp()
  const gym = memberships[0]
  const can = mode === 'live' && !!gym && ['owner', 'admin', 'front_desk'].includes(gym.role)
  const { items } = usePendingPlanRequests(can ? gym.gymId : undefined, (r) =>
    app.toast(`Nueva solicitud: ${r.fullName.split(' ')[0]} pide ${r.planName}. Apruébala en Tarifas`),
  )
  return items?.length ?? 0
}

export function StaffLayout() {
  const pending = usePlanRequestAlerts()
  const dots = { '/staff/tarifas': pending }
  return (
    <Frame side={<SideNav tabs={STAFF_TABS} label="Navegación del personal" dots={dots} other={{ to: '/', label: '← Vista de alumno' }} />}>
      <main className={CONTENT}>
        <Outlet />
      </main>
      <BottomNav tabs={STAFF_TABS} label="Navegación del personal" dots={dots} />
    </Frame>
  )
}

/** Pantalla sin barra inferior (detalle de clase, vídeo, ficha) */
export function BareLayout() {
  return (
    <Frame>
      <main className={CONTENT}>
        <Outlet />
      </main>
    </Frame>
  )
}

/** Contenido de una pantalla con los márgenes del diseño */
export function Screen({ children, gap = 16, top = 56, className }: { children: ReactNode; gap?: number; top?: number; className?: string }) {
  return (
    <div
      className={cx('flex flex-1 flex-col px-5 pb-6 md:px-8 md:!pt-10 md:pb-10', className)}
      style={{ gap, paddingTop: `calc(${top}px + env(safe-area-inset-top))` }}
    >
      {children}
    </div>
  )
}

/** Barra de acciones fija abajo en pantallas de detalle */
export function ActionBar({ children, row }: { children: ReactNode; row?: boolean }) {
  return (
    <div className="pb-safe sticky bottom-0 z-20 border-t border-line bg-bg">
      <div className={cx('flex gap-2 px-5 pt-3 pb-[30px]', row ? 'flex-row' : 'flex-col')}>{children}</div>
    </div>
  )
}
