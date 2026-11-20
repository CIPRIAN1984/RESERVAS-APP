import { useEffect, useState } from 'react'
import { Avatar, Sheet } from '../../components/ui'
import { useAvatarUrls } from '../../lib/avatars'
import { ME_ID } from '../../lib/data'
import { initials } from '../../lib/logic'
import { loadAttendees } from '../../lib/remote'
import { useApp } from '../../lib/store'
import type { Session } from '../../lib/types'

interface Person {
  id: string
  name: string
  avatarPath: string | null
  isMe: boolean
}

/** Personas apuntadas a una sesión (servidor en modo real, datos de ejemplo en demo) */
function useAttendees(session: Session): Person[] | null {
  const app = useApp()
  const live = app.scheduleSource === 'live'
  const [people, setPeople] = useState<Person[] | null>(null)
  const sid = session.id
  const version = `${session.bookedCount ?? 0}`

  useEffect(() => {
    if (!live) return
    let cancelled = false
    loadAttendees(sid)
      .then((rows) => !cancelled && setPeople(rows.map((r) => ({ id: r.profileId, name: r.name, avatarPath: r.avatarPath, isMe: r.isMe }))))
      .catch(() => !cancelled && setPeople([]))
    return () => {
      cancelled = true
    }
  }, [live, sid, version])

  if (live) return people
  const mine = app.myBooking(sid)?.status === 'booked'
  const others = app.state.bookings
    .filter((b) => b.sessionId === sid && b.status === 'booked' && b.profileId !== ME_ID)
    .map((b) => ({ id: b.profileId, name: app.member(b.profileId)?.name ?? '—', avatarPath: null, isMe: false }))
  return [...(mine ? [{ id: ME_ID, name: app.me.name, avatarPath: null, isMe: true }] : []), ...others]
}

/** Fila de fotos de quién va y hoja con la lista completa */
export function Attendees({ session, waiting }: { session: Session; waiting: number }) {
  const app = useApp()
  const people = useAttendees(session)
  const urls = useAvatarUrls((people ?? []).map((p) => p.avatarPath))
  const [open, setOpen] = useState(false)
  const src = (p: Person) => (p.isMe && app.scheduleSource === 'demo' ? app.state.demoAvatar : p.avatarPath ? urls[p.avatarPath] : null)

  if (!people || people.length === 0) return null
  const me = people.some((p) => p.isMe)
  const shown = people.slice(0, 4)
  const label = me ? (people.length > 1 ? `Tú y ${people.length - 1} más` : 'Solo tú de momento') : `${people.length} apuntados`

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="flex w-full items-center gap-[10px] border-0 bg-transparent p-0 text-left"
        aria-label={`Ver quién va: ${label}`}
      >
        <span aria-hidden="true" className="flex">
          {shown.map((p, i) => (
            <Avatar
              key={p.id}
              text={initials(p.name)}
              size={32}
              tone={p.isMe ? 'ink' : 'grey'}
              src={src(p)}
              className={i > 0 ? 'border-2 border-surface -ml-2' : 'border-2 border-surface'}
            />
          ))}
        </span>
        <span className="min-w-0 truncate whitespace-nowrap text-[13px] text-muted">
          {label}
          {waiting > 0 ? ` · ${waiting} en espera` : ''}
        </span>
        <span className="ml-auto shrink-0 whitespace-nowrap text-[13px] font-semibold text-ink underline">Ver todos</span>
      </button>

      <Sheet open={open} onClose={() => setOpen(false)} title={`Quién va (${people.length})`}>
        {people.map((p) => (
          <div key={p.id} className="flex items-center gap-3 border-b border-line py-2 last:border-0">
            <Avatar text={initials(p.name)} size={40} tone={p.isMe ? 'ink' : 'surface'} src={src(p)} />
            <span className="flex-1 text-[15px] font-semibold">{p.isMe ? `${p.name} (tú)` : p.name}</span>
          </div>
        ))}
        {waiting > 0 && <p className="m-0 pt-2 text-[13px] text-muted">Además hay {waiting} en lista de espera.</p>}
      </Sheet>
    </>
  )
}
