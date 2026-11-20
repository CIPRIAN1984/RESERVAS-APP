import { Link } from 'react-router'
import type { ReactNode } from 'react'
import { Screen } from '../../components/Layout'
import { Chip, Eyebrow, Title } from '../../components/ui'
import { IconAward, IconCalendar, IconChart, IconChevron, IconNews, IconPeople, IconProfile, IconQr, IconUser } from '../../components/icons'

type IconT = typeof IconUser

function Item({ to, icon: Icon, children, sub, soon }: { to?: string; icon: IconT; children: ReactNode; sub: string; soon?: boolean }) {
  const inner = (
    <>
      <Icon size={22} className="shrink-0 text-ink-2" />
      <span className="flex flex-1 flex-col gap-[2px]">
        <span className="text-[16px] font-medium">{children}</span>
        <span className="text-[13px] text-muted">{sub}</span>
      </span>
      {soon ? <Chip tone="neutral">Próximamente</Chip> : <IconChevron size={18} className="text-muted" />}
    </>
  )
  const cls = 'flex min-h-[64px] items-center gap-4 border-b border-line py-2 text-ink no-underline last:border-0'
  return to ? (
    <Link to={to} className={`hy-text ${cls}`}>
      {inner}
    </Link>
  ) : (
    <div className={`${cls} opacity-70`} aria-disabled="true">
      {inner}
    </div>
  )
}

/** Más (personal): herramientas del gimnasio, en el mismo estilo que el menú del perfil */
export function More() {
  return (
    <Screen top={24} gap={16}>
      <Title size={44}>Más</Title>

      <div className="flex flex-col gap-2">
        <Eyebrow>Gimnasio</Eyebrow>
        <nav className="flex flex-col rounded-[18px] bg-surface px-4 py-1">
          <Item to="/staff/horario/editor" icon={IconCalendar} sub="Clases semanales, clases de un día, festivos y cierres">
            Clases y cierres
          </Item>
          <Item to="/novedades" icon={IconNews} sub="Publicar, fijar, editar y borrar avisos para los alumnos">
            Novedades
          </Item>
          <Item to="/staff/monitores" icon={IconPeople} sub="Clases, horas y currículo de cada monitor">
            Monitores
          </Item>
          <Item to="/staff/kiosco" icon={IconQr} sub="QR de check-in para la tablet de la entrada o para imprimir">
            Modo kiosco
          </Item>
        </nav>
      </div>

      <div className="flex flex-col gap-2">
        <Eyebrow>Próximamente</Eyebrow>
        <nav className="flex flex-col rounded-[18px] bg-surface px-4 py-1">
          <Item icon={IconAward} sub="Alumnos que cumplen las reglas de su siguiente grado" soon>
            Graduaciones
          </Item>
          <Item icon={IconChart} sub="Retención y clases más concurridas por franja" soon>
            Analítica
          </Item>
        </nav>
      </div>

      <nav className="flex flex-col rounded-[18px] bg-surface px-4 py-1">
        <Item to="/" icon={IconProfile} sub="Volver a las pantallas del alumno">
          Vista de alumno
        </Item>
      </nav>
    </Screen>
  )
}
