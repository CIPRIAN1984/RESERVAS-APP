import { useEffect, useState, type FormEvent } from 'react'
import { Screen } from '../../components/Layout'
import { Btn, Card, EmptyState, Sheet, Title, cx } from '../../components/ui'
import { IconEdit, IconThumbtack } from '../../components/icons'
import { markNewsSeen, timeAgo, useAnnouncements, type Announcement } from '../../lib/news'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../auth/AuthProvider'

const PAGE = 10
const PUBLISHERS = ['owner', 'admin', 'front_desk', 'coach']

const DEMO: Announcement[] = [
  { id: 'd1', title: 'Normas del tatami', body: 'Llega 5 minutos antes, uñas cortas y kimono limpio.\nSi estás malo, descansa: el tatami te espera.', pinned: true, publishedAt: new Date(Date.now() - 20 * 86400000), edited: false, authorName: 'ITACA', canEdit: false },
  { id: 'd2', title: 'Seminario de guardia el sábado', body: 'Sábado a las 11:00. Abierto a todos los niveles. Apúntate en recepción.', pinned: false, publishedAt: new Date(Date.now() - 2 * 86400000), edited: false, authorName: 'ITACA', canEdit: false },
]

/** Novedades: avisos del gimnasio. El personal los publica desde aquí. */
export function News() {
  const app = useApp()
  const auth = useAuth()
  const live = auth.mode === 'live'
  const gymId = auth.memberships[0]?.gymId
  const canPublish = live && auth.memberships.some((m) => m.gymId === gymId && PUBLISHERS.includes(m.role))
  const [limit, setLimit] = useState(PAGE)
  const q = useAnnouncements(live ? gymId : undefined, limit)
  const items = live ? q.items : DEMO
  const [editing, setEditing] = useState<Announcement | 'new' | null>(null)

  // Al abrir (y al llegar avisos nuevos con la pestaña abierta) se dan por vistos
  useEffect(() => {
    markNewsSeen()
  }, [items?.length])

  return (
    <Screen top={24} gap={16}>
      <header className="flex items-center justify-between gap-3">
        <Title size={44}>Novedades</Title>
        {canPublish && (
          <Btn size="sm" onClick={() => setEditing('new')}>
            Nuevo aviso
          </Btn>
        )}
      </header>

      {items === null ? (
        <p className="m-0 text-[14px] text-muted">Cargando…</p>
      ) : q.error && live ? (
        <EmptyState title="No se pudieron cargar las novedades" text="Comprueba la conexión y vuelve a intentarlo." />
      ) : items.length === 0 ? (
        <EmptyState
          title="Aún no hay novedades"
          text={canPublish ? 'Publica el primer aviso: cambios de horario, seminarios, competiciones…' : 'Aquí verás los avisos del gimnasio: cambios de horario, seminarios, competiciones…'}
        />
      ) : (
        <div className="flex flex-col gap-3">
          {items.map((a) => (
            <AnnouncementCard key={a.id} a={a} now={app.now} onEdit={() => setEditing(a)} />
          ))}
          {live && q.hasMore && (
            <Btn variant="soft" block onClick={() => setLimit((l) => l + PAGE)}>
              Ver avisos anteriores
            </Btn>
          )}
        </div>
      )}

      {editing && gymId && (
        <AnnouncementSheet
          gymId={gymId}
          initial={editing === 'new' ? null : editing}
          onClose={() => setEditing(null)}
          onDone={(msg) => {
            setEditing(null)
            q.reload()
            app.toast(msg)
          }}
        />
      )}
    </Screen>
  )
}

function AnnouncementCard({ a, now, onEdit }: { a: Announcement; now: Date; onEdit: () => void }) {
  const [open, setOpen] = useState(false)
  const long = a.body.length > 220 || a.body.split('\n').length > 4
  const edited = a.edited

  return (
    <Card className={cx('gap-2 p-4', a.pinned && 'border border-accent')}>
      <div className="flex items-start gap-3">
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          {a.pinned && (
            <span className="flex items-center gap-1 text-[12px] font-semibold text-accent">
              <IconThumbtack size={14} /> Fijado
            </span>
          )}
          <h2 className="m-0 text-[17px] font-bold leading-snug">{a.title}</h2>
          <span className="text-[12px] text-muted">
            {a.authorName} · {timeAgo(a.publishedAt, now)}
            {edited ? ' · editado' : ''}
          </span>
        </div>
        {a.canEdit && (
          <button type="button" aria-label={`Editar ${a.title}`} onClick={onEdit} className="hy -mr-2 -mt-1 flex h-10 w-10 items-center justify-center rounded-full border-0 bg-transparent text-ink-2">
            <IconEdit size={18} />
          </button>
        )}
      </div>
      {a.body && (
        <>
          <p className={cx('m-0 whitespace-pre-line text-[15px] leading-relaxed text-ink-2', long && !open && 'line-clamp-4')}>{a.body}</p>
          {long && (
            <button type="button" onClick={() => setOpen((o) => !o)} className="hy-text self-start border-0 bg-transparent p-0 text-[14px] font-semibold text-ink">
              {open ? 'Mostrar menos' : 'Mostrar más'}
            </button>
          )}
        </>
      )}
    </Card>
  )
}

const inputCls = 'w-full rounded-[12px] border border-border bg-surface-2 px-3 text-[16px] text-ink'

function AnnouncementSheet({ gymId, initial, onClose, onDone }: { gymId: string; initial: Announcement | null; onClose: () => void; onDone: (msg: string) => void }) {
  const auth = useAuth()
  const [title, setTitle] = useState(initial?.title ?? '')
  const [body, setBody] = useState(initial?.body ?? '')
  const [pinned, setPinned] = useState(initial?.pinned ?? false)
  const [busy, setBusy] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const save = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase || !auth.profile) return
    if (!title.trim()) return setError('Escribe un título')
    setBusy(true)
    setError(null)
    const row = { title: title.trim(), body: body.trim(), pinned }
    const { error } = initial
      ? await supabase.from('announcements').update(row).eq('id', initial.id)
      : await supabase.from('announcements').insert({ ...row, gym_id: gymId, author_profile_id: auth.profile.id })
    setBusy(false)
    if (error) return setError(error.code === '42501' ? 'No tienes permiso para publicar avisos' : 'No se pudo guardar. Inténtalo de nuevo.')
    onDone(initial ? 'Aviso actualizado' : 'Aviso publicado: los alumnos ya lo ven')
  }

  const remove = async () => {
    if (!supabase || !initial) return
    setBusy(true)
    const { error } = await supabase.from('announcements').delete().eq('id', initial.id)
    setBusy(false)
    if (error) return setError('No se pudo borrar')
    onDone('Aviso borrado')
  }

  return (
    <Sheet open onClose={onClose} title={initial ? 'Editar aviso' : 'Nuevo aviso'}>
      <form onSubmit={save} className="flex flex-col gap-3">
        <label className="flex flex-col gap-1 text-[13px] font-medium text-ink-2">
          Título
          <input className={cx(inputCls, 'h-12')} value={title} maxLength={120} onChange={(e) => setTitle(e.target.value)} placeholder="Cerrado el 8 de diciembre" required />
        </label>
        <label className="flex flex-col gap-1 text-[13px] font-medium text-ink-2">
          Texto
          <textarea className={cx(inputCls, 'min-h-[140px] py-3 leading-relaxed')} value={body} maxLength={4000} onChange={(e) => setBody(e.target.value)} placeholder="Cuéntalo con detalle: qué, cuándo y a quién afecta." />
        </label>
        <label className="flex min-h-11 items-center gap-3 text-[15px]">
          <input type="checkbox" className="h-5 w-5" checked={pinned} onChange={(e) => setPinned(e.target.checked)} />
          Fijar arriba (para avisos que deben verse siempre, como las normas)
        </label>
        {error && (
          <p role="alert" className="m-0 rounded-[12px] bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
            {error}
          </p>
        )}
        <Btn type="submit" variant="accent" size="lg" block disabled={busy}>
          {busy ? 'Guardando…' : initial ? 'Guardar cambios' : 'Publicar'}
        </Btn>
        {initial &&
          (confirmDelete ? (
            <div className="flex items-center gap-2 rounded-[12px] bg-err-bg p-3 text-err-fg">
              <span className="flex-1 text-[14px] font-medium">¿Borrar este aviso? No se puede deshacer.</span>
              <button type="button" disabled={busy} onClick={() => void remove()} className="h-10 rounded-full border-0 bg-coral px-4 text-[14px] font-semibold text-on-coral">
                Borrar
              </button>
              <button type="button" onClick={() => setConfirmDelete(false)} className="h-10 rounded-full border-0 bg-transparent px-3 text-[14px] font-semibold text-err-fg">
                No
              </button>
            </div>
          ) : (
            <button type="button" onClick={() => setConfirmDelete(true)} className="self-center border-0 bg-transparent py-2 text-[14px] font-semibold text-err-fg">
              Borrar aviso
            </button>
          ))}
      </form>
    </Sheet>
  )
}
