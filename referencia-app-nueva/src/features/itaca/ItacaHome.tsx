import { useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { Screen } from '../../components/Layout'
import { Btn, Chip, Eyebrow, FilterChip, ProgressBar, Title } from '../../components/ui'
import { IconLock, IconPlayFill } from '../../components/icons'
import { CURRICULA, VIDEOS } from '../../lib/data'
import { useApp } from '../../lib/store'
import type { Video } from '../../lib/types'

type Tab = 'todo' | 'clases' | 'tecnicas' | 'curriculos'

export function Thumb({ w, h, locked, radius = 14 }: { w: number; h: number; locked?: boolean; radius?: number }) {
  return (
    <div role="img" aria-label="Miniatura del vídeo" className="flex shrink-0 items-center justify-center bg-video text-white" style={{ width: w, height: h, borderRadius: radius }}>
      {locked ? <IconLock size={20} /> : <IconPlayFill size={22} />}
    </div>
  )
}

const norm = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

export function ItacaHome() {
  const app = useApp()
  const nav = useNavigate()
  const [q, setQ] = useState('')
  const [tab, setTab] = useState<Tab>('todo')
  const subscribed = app.itacaPlus
  const progress = app.state.videoProgress

  const curriculumOf = (v: Video) => CURRICULA.find((c) => c.id === v.curriculumId)
  const matches = (v: Video) => !q || norm([v.title, ...v.tags, curriculumOf(v)?.name ?? ''].join(' ')).includes(norm(q))

  const inProgress = VIDEOS.filter((v) => (progress[v.id] ?? 0) > 0 && (progress[v.id] ?? 0) < 100)
  const classes = VIDEOS.filter((v) => v.kind === 'clase' && matches(v))
  const techniques = VIDEOS.filter((v) => v.kind === 'tecnica' && matches(v))
  const curricula = CURRICULA.map((c) => {
    const vids = VIDEOS.filter((v) => v.curriculumId === c.id)
    const seen = vids.filter((v) => (progress[v.id] ?? 0) >= 100).length
    return { c, total: vids.length, seen }
  }).filter((x) => x.total > 0 && (!q || norm(x.c.name).includes(norm(q))))

  const show = (t: Tab) => tab === 'todo' || tab === t

  return (
    <Screen gap={12}>
      <div className="flex items-center justify-between">
        <Title>ITACA+</Title>
        {subscribed ? <Chip tone="ok">Suscrito</Chip> : <Chip tone="neutral">Sin suscripción</Chip>}
      </div>

      {!subscribed && (
        <div className="flex flex-col gap-2 rounded-[18px] border border-accent/40 bg-surface p-4 text-ink">
          <span className="text-[15px] font-bold">Vídeos de las clases y currículos completos</span>
          <span className="text-[13px]">Puedes ver las fichas; para reproducir hace falta la suscripción.</span>
          <button onClick={() => nav('/tarifas')} className="hy mt-1 h-11 rounded-[12px] border-0 bg-ink text-[14px] font-semibold text-on-ink">
            Ver ITACA+
          </button>
        </div>
      )}

      <input
        type="search"
        aria-label="Buscar técnica, posición o clase"
        placeholder="Buscar técnica, posición o clase"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        className="h-[46px] rounded-[14px] border-[1.5px] border-border bg-bg px-[14px] text-[15px] text-ink placeholder:text-muted"
      />
      <div className="no-scrollbar -mx-5 flex gap-2 overflow-x-auto px-5">
        {(
          [
            ['todo', 'Todo'],
            ['clases', 'Clases'],
            ['tecnicas', 'Técnicas'],
            ['curriculos', 'Currículos'],
          ] as [Tab, string][]
        ).map(([id, label]) => (
          <FilterChip key={id} active={tab === id} onClick={() => setTab(id)}>
            {label}
          </FilterChip>
        ))}
      </div>

      {tab === 'todo' && !q && inProgress.length > 0 && (
        <>
          <Eyebrow>Seguir viendo</Eyebrow>
          {inProgress.map((v) => {
            const c = curriculumOf(v)
            return (
              <Link key={v.id} to={`/itaca/video/${v.id}`} className="flex items-center gap-3 rounded-[20px] bg-surface p-3 text-ink no-underline">
                <Thumb w={112} h={72} locked={!subscribed} />
                <div className="flex flex-1 flex-col gap-[6px]">
                  <span className="text-[15px] font-bold leading-[1.25]">{v.title}</span>
                  <span className="text-[12px] text-muted">
                    {c?.name} · {v.order} de {VIDEOS.filter((x) => x.curriculumId === v.curriculumId).length}
                  </span>
                  <ProgressBar value={progress[v.id] ?? 0} height={6} accent label={`Visto el ${progress[v.id]} por ciento`} />
                </div>
              </Link>
            )
          })}
        </>
      )}

      {show('clases') && classes.length > 0 && (
        <>
          <Eyebrow>Clases que te perdiste</Eyebrow>
          <div className="flex flex-col gap-[10px]">
            {classes.map((v) => (
              <Link key={v.id} to={`/itaca/video/${v.id}`} className="flex items-center gap-3 text-ink no-underline">
                <Thumb w={84} h={52} radius={12} locked={!subscribed} />
                <div className="flex flex-1 flex-col gap-[2px]">
                  <span className="text-[15px] font-semibold">{v.title}</span>
                  <span className="text-[13px] text-muted">
                    {v.classLabel} · explicación de {v.minutes} min
                  </span>
                </div>
              </Link>
            ))}
          </div>
        </>
      )}

      {show('curriculos') && curricula.length > 0 && (
        <>
          <Eyebrow>Currículos</Eyebrow>
          <div className="flex gap-[10px]">
            {curricula.map(({ c, total, seen }) => {
              const first = VIDEOS.find((v) => v.curriculumId === c.id && (progress[v.id] ?? 0) < 100) ?? VIDEOS.find((v) => v.curriculumId === c.id)!
              return (
                <Link key={c.id} to={`/itaca/video/${first.id}`} className="flex flex-1 flex-col gap-2 rounded-[20px] bg-surface p-[14px] text-ink no-underline">
                  <span className="text-[18px] font-bold leading-tight tracking-[-0.01em]">{c.name}</span>
                  <span className="text-[12px] text-muted">
                    {total} vídeos · {seen ? `${seen} vistos` : 'sin empezar'}
                  </span>
                  <ProgressBar value={(seen / total) * 100} height={6} />
                </Link>
              )
            })}
          </div>
        </>
      )}

      {(tab === 'tecnicas' || q) && techniques.length > 0 && (
        <>
          <Eyebrow>Técnicas</Eyebrow>
          <div className="flex flex-col gap-[10px]">
            {techniques.map((v) => (
              <Link key={v.id} to={`/itaca/video/${v.id}`} className="flex items-center gap-3 text-ink no-underline">
                <Thumb w={84} h={52} radius={12} locked={!subscribed} />
                <div className="flex flex-1 flex-col gap-[2px]">
                  <span className="text-[15px] font-semibold">{v.title}</span>
                  <span className="text-[13px] text-muted">
                    {v.tags.slice(0, 2).join(' · ')} · {v.minutes} min
                  </span>
                </div>
                {(progress[v.id] ?? 0) >= 100 && <Chip tone="ok">Visto</Chip>}
              </Link>
            ))}
          </div>
        </>
      )}

      {q && classes.length + techniques.length + curricula.length === 0 && (
        <div className="flex flex-col items-start gap-2 py-4">
          <p className="m-0 text-[14px] text-muted">No hay vídeos que coincidan con «{q}».</p>
          <Btn size="sm" variant="outline" onClick={() => setQ('')}>
            Borrar búsqueda
          </Btn>
        </div>
      )}
    </Screen>
  )
}
