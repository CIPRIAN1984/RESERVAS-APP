import { useState, type ReactNode } from 'react'
import { Link, useNavigate } from 'react-router'
import { Screen } from '../../components/Layout'
import { Avatar, BeltBar, Card, Chip, Title, cx } from '../../components/ui'
import {
  IconAward,
  IconCalendar,
  IconCard,
  IconChevron,
  IconClose,
  IconDoc,
  IconHeart,
  IconHelp,
  IconLogout,
  IconPeople,
  IconPhoneLink,
  IconPlay,
  IconReceipt,
  IconSettings,
  IconUser,
  IconUsers,
} from '../../components/icons'
import { BELT_LABEL } from '../../lib/data'
import { initials } from '../../lib/logic'
import { ageOn, useFamily, type FamilyMember } from '../../lib/profileApi'
import { useApp } from '../../lib/store'
import { ROLE_LABEL } from '../../lib/supabase'
import { useAuth } from '../auth/AuthProvider'
import { useMyAvatar } from '../auth/useMyAvatar'

type IconT = typeof IconUser

function MenuRow({ to, icon: Icon, children, hint, onClick }: { to?: string; icon: IconT; children: ReactNode; hint?: ReactNode; onClick?: () => void }) {
  const inner = (
    <>
      <Icon size={22} className="shrink-0 text-ink-2" />
      <span className="flex-1 text-left text-[16px] font-medium">{children}</span>
      {hint && <span className="text-[13px] text-muted">{hint}</span>}
      {to && <IconChevron size={18} className="text-muted" />}
    </>
  )
  const cls = 'hy-text flex min-h-[56px] w-full items-center gap-4 border-0 border-b border-line bg-transparent px-1 py-2 text-ink no-underline last:border-b-0'
  return to ? (
    <Link to={to} className={cls}>
      {inner}
    </Link>
  ) : (
    <button type="button" onClick={onClick} className={cls}>
      {inner}
    </button>
  )
}

function Tile({ to, icon: Icon, label, sub }: { to: string; icon: IconT; label: string; sub: string }) {
  return (
    <Link to={to} className="hy-text flex flex-col gap-3 rounded-[18px] bg-surface p-4 text-ink no-underline">
      <Icon size={24} className="text-ink-2" />
      <span className="flex flex-col">
        <span className="text-[16px] font-semibold">{label}</span>
        <span className="truncate text-[13px] text-muted">{sub}</span>
      </span>
    </Link>
  )
}

const isInstalled = () => typeof window !== 'undefined' && (window.matchMedia?.('(display-mode: standalone)').matches || (navigator as { standalone?: boolean }).standalone === true)

/** Perfil: tarjeta (con los perfiles de la familia), accesos y menú de la cuenta */
export function Profile() {
  const app = useApp()
  const nav = useNavigate()
  const auth = useAuth()
  const live = auth.mode === 'live'
  const avatar = useMyAvatar()
  const family = useFamily(live ? auth.profile?.id : undefined)
  const kids = family.data ?? []
  const [selected, setSelected] = useState<string>('me')
  const [hideInstall, setHideInstall] = useState(() => {
    try {
      return isInstalled() || localStorage.getItem('itaca-ocultar-instalar') === '1'
    } catch {
      return isInstalled()
    }
  })

  const displayName = auth.profile?.fullName ?? app.me.name
  const plan = app.myPlan
  const kid = kids.find((k) => k.id === selected)
  const roles = live ? auth.memberships.filter((m) => m.role !== 'member').map((m) => ROLE_LABEL[m.role]) : []

  const dismissInstall = () => {
    setHideInstall(true)
    try {
      localStorage.setItem('itaca-ocultar-instalar', '1')
    } catch {
      /* sin almacenamiento: se vuelve a mostrar la próxima vez */
    }
  }

  return (
    <Screen top={24} gap={18}>
      <header className="flex items-center justify-between">
        <Title size={44}>Perfil</Title>
        <Link to="/ajustes" aria-label="Ajustes de la app" className="-mr-2 flex h-11 w-11 items-center justify-center rounded-full text-ink">
          <IconSettings size={22} />
        </Link>
      </header>

      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] lg:items-start">
        <div className="flex flex-col gap-4">
          {kid ? (
            <KidCard kid={kid} />
          ) : (
            <Card radius={24} className="gap-4 p-5">
              <div className="flex items-center gap-4">
                <Avatar text={initials(displayName)} src={avatar} size={72} tone="grey" className="text-[22px]" />
                <div className="flex min-w-0 flex-1 flex-col gap-1">
                  <span className="truncate text-[22px] font-bold leading-tight">{displayName}</span>
                  <span className="text-[13px] text-muted">
                    {live && !auth.rank ? 'Cinturón sin indicar' : `Cinturón ${BELT_LABEL[app.me.belt].toLowerCase()} · ${app.me.stripes} ${app.me.stripes === 1 ? 'grado' : 'grados'}`}
                  </span>
                  {roles.length > 0 && (
                    <span className="flex flex-wrap gap-1">
                      {roles.map((r) => (
                        <Chip key={r} tone="neutral" small>
                          {r}
                        </Chip>
                      ))}
                    </span>
                  )}
                </div>
              </div>
              {(!live || auth.rank) && <BeltBar belt={app.me.belt} stripes={app.me.stripes} />}
              <Link to="/perfil/editar" className="hy inline-flex h-11 items-center justify-center rounded-[12px] bg-surface-2 text-[15px] font-semibold text-ink no-underline">
                Editar perfil
              </Link>
            </Card>
          )}

          {kids.length > 0 && (
            <div role="tablist" aria-label="Perfiles de la familia" className="-mt-1 flex gap-2 overflow-x-auto">
              {[{ id: 'me', fullName: displayName }, ...kids].map((p) => (
                <button
                  key={p.id}
                  type="button"
                  role="tab"
                  aria-selected={selected === p.id}
                  onClick={() => setSelected(p.id)}
                  className={cx(
                    'h-9 shrink-0 rounded-full border-0 px-4 text-[14px]',
                    selected === p.id ? 'bg-ink font-semibold text-on-ink' : 'bg-surface-2 font-medium text-muted',
                  )}
                >
                  {p.id === 'me' ? 'Tú' : p.fullName.split(' ')[0]}
                </button>
              ))}
            </div>
          )}

          <div className="grid grid-cols-2 gap-3">
            <Tile to="/tarifas" icon={IconCard} label="Membresías" sub={app.planStatus?.planName ?? plan?.name ?? 'Ver tarifas'} />
            <Tile to="/documentos" icon={IconDoc} label="Documentos" sub="Normas y autorizaciones" />
          </div>

          {!hideInstall && (
            <div className="flex items-center gap-3 rounded-[18px] border border-border p-4">
              <IconPhoneLink size={24} className="shrink-0 text-ink" />
              <Link to="/instalar" className="flex flex-1 flex-col text-ink no-underline">
                <span className="text-[15px] font-semibold">Conecta tu móvil</span>
                <span className="text-[13px] text-muted">Instala la app para reservar y fichar más rápido.</span>
              </Link>
              <button type="button" aria-label="Ocultar aviso" onClick={dismissInstall} className="hy flex h-9 w-9 items-center justify-center rounded-full border-0 bg-transparent text-muted">
                <IconClose size={18} />
              </button>
            </div>
          )}
        </div>

        <nav aria-label="Menú del perfil" className="flex flex-col rounded-[18px] bg-surface px-4 py-1">
          <MenuRow to="/cuenta" icon={IconUser}>
            Configuración de la cuenta
          </MenuRow>
          <MenuRow to="/perfil/perfiles" icon={IconUsers} hint={kids.length > 0 ? `${kids.length + 1}` : undefined}>
            Perfiles
          </MenuRow>
          <MenuRow to="/reservas" icon={IconCalendar}>
            Mis reservas
          </MenuRow>
          <MenuRow to="/perfil/facturacion" icon={IconReceipt}>
            Facturación y pago
          </MenuRow>
          <MenuRow to="/perfil/promociones" icon={IconAward}>
            Promociones
          </MenuRow>
          <MenuRow to="/perfil/emergencia" icon={IconHeart}>
            Contacto de emergencia
          </MenuRow>
          <MenuRow to="/itaca" icon={IconPlay} hint={app.itacaPlus ? 'Suscrito' : undefined}>
            ITACA+
          </MenuRow>
          <MenuRow to="/perfil/soporte" icon={IconHelp}>
            Contactar con soporte
          </MenuRow>
          <MenuRow to="/ajustes" icon={IconSettings}>
            Ajustes de la app
          </MenuRow>
          {(auth.isStaff || !live) && (
            <MenuRow to="/staff" icon={IconPeople}>
              Vista del personal
            </MenuRow>
          )}
          {live && (
            <MenuRow icon={IconLogout} onClick={() => void auth.signOut().then(() => nav('/entrar'))}>
              Cerrar sesión
            </MenuRow>
          )}
        </nav>
      </div>
    </Screen>
  )
}

function KidCard({ kid }: { kid: FamilyMember }) {
  return (
    <Card radius={24} className="gap-4 p-5">
      <div className="flex items-center gap-4">
        <Avatar text={initials(kid.fullName)} size={72} tone="grey" className="text-[22px]" />
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <span className="truncate text-[22px] font-bold leading-tight">{kid.fullName}</span>
          <span className="text-[13px] text-muted">{kid.birthDate ? `${ageOn(kid.birthDate)} años · ` : ''}A tu cargo</span>
        </div>
      </div>
      <Link to={`/perfil/perfiles/${kid.id}`} className="hy inline-flex h-11 items-center justify-center rounded-[12px] bg-surface-2 text-[15px] font-semibold text-ink no-underline">
        Editar perfil
      </Link>
    </Card>
  )
}
