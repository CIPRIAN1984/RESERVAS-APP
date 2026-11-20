import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router'
import { ActionBar } from '../../components/Layout'
import { Btn, Chip, EmptyState, Eyebrow, cx } from '../../components/ui'
import { IconBack, IconCheck, IconLock, IconPlayFill } from '../../components/icons'
import { CURRICULA, ME_ID, TEMPLATES, VIDEOS, classTitle } from '../../lib/data'
import { addDays, mediumDay, shortDay } from '../../lib/dates'
import { isPresent } from '../../lib/logic'
import { useApp } from '../../lib/store'

const mmss = (sec: number) => `${Math.floor(sec / 60)}:${String(Math.floor(sec % 60)).padStart(2, '0')}`

/**
 * Ficha y reproductor. El vídeo real se servirá desde Bunny Stream con una
 * dirección firmada (paso 10); aquí el reproductor simula el avance.
 */
export function ItacaVideo() {
  const { id = '' } = useParams()
  const app = useApp()
  const nav = useNavigate()
  const video = VIDEOS.find((v) => v.id === id)
  const [playing, setPlaying] = useState(false)
  const timer = useRef<ReturnType<typeof setInterval> | null>(null)
  const pct = video ? app.state.videoProgress[video.id] ?? 0 : 0
  const subscribed = app.itacaPlus

  useEffect(() => {
    setPlaying(false)
  }, [id])

  useEffect(() => {
    if (!playing || !video) return
    timer.current = setInterval(() => {
      const cur = app.state.videoProgress[video.id] ?? 0
      const next = Math.min(100, cur + 2)
      app.setVideoProgress(video.id, next)
      if (next >= 100) setPlaying(false)
    }, 500)
    return () => {
      if (timer.current) clearInterval(timer.current)
    }
  }, [playing, video, app])

  if (!video) {
    return (
      <div className="flex flex-col gap-4 p-5 pt-14">
        <EmptyState title="Vídeo no encontrado" text="Puede que se haya retirado de la biblioteca." action={<Btn size="sm" onClick={() => nav('/itaca')}>Volver a ITACA+</Btn>} />
      </div>
    )
  }

  const curriculum = CURRICULA.find((c) => c.id === video.curriculumId)
  const siblings = VIDEOS.filter((v) => v.curriculumId && v.curriculumId === video.curriculumId).sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
  const idx = siblings.findIndex((v) => v.id === video.id)
  const nearby = siblings.slice(Math.max(0, idx - 1), Math.max(0, idx - 1) + 4)
  const total = video.minutes * 60
  const coach = app.coaches[0]

  // Clase en la que se dio esta técnica (la sesión más reciente de una clase con este currículo)
  const tplWithCur = app.state.assignments.find((a) => a.curriculumId === video.curriculumId)
  let givenIn: { label: string; date: Date; attended: boolean } | null = null
  if (tplWithCur && video.classLabel) {
    for (let i = 0; i < 14; i++) {
      const d = addDays(app.now, -i)
      const s = app.sessionsOn(d).find((x) => x.templateId === tplWithCur.templateId && x.end < app.now)
      if (s) {
        const t = TEMPLATES.find((x) => x.id === s.templateId)!
        givenIn = { label: classTitle(t), date: s.start, attended: isPresent(app.state.attendance, s.id, ME_ID) }
        break
      }
    }
  }

  return (
    <>
      <div className="pt-safe relative flex h-[230px] shrink-0 items-center justify-center bg-[#0A0A0A]">
        <button
          aria-label="Volver a ITACA+"
          onClick={() => nav('/itaca')}
          className="absolute left-4 flex h-11 w-11 items-center justify-center rounded-full border-0 bg-white/15 text-white"
          style={{ top: 'calc(env(safe-area-inset-top) + 16px)' }}
        >
          <IconBack size={22} />
        </button>
        {subscribed ? (
          <button
            aria-label={playing ? 'Pausar' : 'Reproducir'}
            onClick={() => {
              if (pct >= 100) app.setVideoProgress(video.id, 0)
              setPlaying((p) => !p)
            }}
            className="mt-[30px] flex h-16 w-16 items-center justify-center rounded-full border-0 bg-accent text-[#0A0A0A]"
          >
            {playing ? (
              <span className="flex gap-[6px]" aria-hidden="true">
                <span className="h-6 w-[6px] rounded bg-[#0A0A0A]" />
                <span className="h-6 w-[6px] rounded bg-[#0A0A0A]" />
              </span>
            ) : (
              <IconPlayFill size={30} />
            )}
          </button>
        ) : (
          <div className="mt-[30px] flex flex-col items-center gap-3 text-white">
            <IconLock size={32} />
            <span className="text-[14px] font-semibold">Solo para suscriptores de ITACA+</span>
            <Link to="/tarifas" className="rounded-[12px] bg-white px-5 py-3 text-[14px] font-semibold text-[#0A0A0A] no-underline">
              Suscribirme
            </Link>
          </div>
        )}
        {subscribed && (
          <div className="absolute inset-x-4 bottom-3 flex items-center gap-[10px] text-[12px] text-white">
            <span>{mmss((total * pct) / 100)}</span>
            <div aria-hidden="true" className="h-1 flex-1 rounded-full bg-white/30">
              <div className="h-full rounded-full bg-white" style={{ width: `${pct}%` }} />
            </div>
            <span>{mmss(total)}</span>
          </div>
        )}
      </div>

      <div className="flex flex-1 flex-col gap-[10px] px-5 pt-4 pb-6">
        <Eyebrow>{curriculum ? `${curriculum.name} · ${video.order} de ${siblings.length}` : `Clase grabada · ${video.classLabel}`}</Eyebrow>
        <h1 className="m-0 text-[22px] font-bold leading-[1.2]">{video.title}</h1>
        <span className="text-[13px] text-muted">Prof. {coach?.name} · {video.minutes} min</span>
        <div className="flex flex-wrap gap-[6px]">
          {video.tags.map((t) => (
            <span key={t} className="rounded-full bg-surface px-[10px] py-[6px] text-[12px] font-semibold">
              {t}
            </span>
          ))}
        </div>

        {givenIn && (
          <div className="flex items-center justify-between gap-[10px] rounded-2xl border-[1.5px] border-line px-[14px] py-[10px]">
            <div className="flex flex-col gap-[1px]">
              <span className="text-[13px] font-semibold">Dado en clase el {shortDay(givenIn.date)}</span>
              <span className="text-[12px] text-muted">{givenIn.label}</span>
            </div>
            {givenIn.attended ? <Chip tone="ok">Asististe</Chip> : <Chip tone="neutral">Te la perdiste</Chip>}
          </div>
        )}
        {video.kind === 'clase' && video.classDate && (
          <p className="m-0 text-[13px] text-muted">Explicación técnica de la clase del {mediumDay(new Date(video.classDate + 'T12:00:00'))}.</p>
        )}

        {nearby.length > 0 && (
          <>
            <Eyebrow>En este currículo</Eyebrow>
            <div className="flex flex-col gap-[2px]">
              {nearby.map((v) => {
                const seen = (app.state.videoProgress[v.id] ?? 0) >= 100
                return (
                  <Link
                    key={v.id}
                    to={`/itaca/video/${v.id}`}
                    aria-current={v.id === video.id ? 'page' : undefined}
                    className={cx('flex items-center gap-3 rounded-[14px] px-3 py-[10px] text-ink no-underline', v.id === video.id && 'bg-surface')}
                  >
                    <span className="w-[22px] font-display text-[22px] font-extrabold text-muted">{v.order}</span>
                    <span className="flex flex-1 flex-col gap-[1px]">
                      <span className="text-[14px] font-semibold">{v.title}</span>
                      <span className="text-[12px] text-muted">{v.minutes} min</span>
                    </span>
                    {seen ? (
                      <span className="text-ok-fg" aria-label="Visto">
                        <IconCheck size={20} />
                      </span>
                    ) : (
                      <span aria-hidden="true" className="w-5" />
                    )}
                  </Link>
                )
              })}
            </div>
          </>
        )}
      </div>

      {subscribed && (
        <ActionBar row>
          {pct >= 100 ? (
            <Btn
              variant="ink"
              size="lg"
              className="flex-1"
              onClick={() => {
                const next = siblings[idx + 1]
                if (next) nav(`/itaca/video/${next.id}`)
                else nav('/itaca')
              }}
            >
              {siblings[idx + 1] ? 'Siguiente vídeo' : 'Volver a ITACA+'}
            </Btn>
          ) : (
            <Btn
              variant="ink"
              size="lg"
              className="flex-1"
              onClick={() => {
                setPlaying(false)
                app.setVideoProgress(video.id, 100)
                app.toast('Marcado como visto')
              }}
            >
              Marcar como visto
            </Btn>
          )}
        </ActionBar>
      )}
    </>
  )
}
