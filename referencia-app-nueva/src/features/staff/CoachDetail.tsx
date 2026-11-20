import { useState } from 'react'
import { useParams } from 'react-router'
import { ActionBar, Screen } from '../../components/Layout'
import { BackButton, Btn, EmptyState, Eyebrow, Sheet, cx } from '../../components/ui'
import { coachSubtitle, classTitle } from '../../lib/data'
import { addDays, hhmm, mediumDay, WEEKDAY_LETTER } from '../../lib/dates'
import { useApp } from '../../lib/store'
import type { ClassTemplate, Session } from '../../lib/types'
import { useCoachStats } from './Coaches'

const DAY_SHORT = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']

export function CoachDetail() {
  const { id = '' } = useParams()
  const app = useApp()
  const stats = useCoachStats()
  const [assignFor, setAssignFor] = useState<ClassTemplate | null>(null)
  const [subOpen, setSubOpen] = useState(false)
  const coach = app.coach(id)

  if (!coach) {
    return (
      <Screen>
        <BackButton label="Volver a monitores" to="/staff/monitores" />
        <EmptyState title="Monitor no encontrado" text="Vuelve a la lista de monitores." />
      </Screen>
    )
  }

  const s = stats(coach.id)
  const templates = [...s.templates]

  // Próximas sesiones de sus clases (para "hoy le toca" y sustituciones)
  const upcoming: Session[] = Array.from({ length: 7 }, (_, i) => app.sessionsOn(addDays(app.now, i)))
    .flat()
    .filter((x) => x.coachId === coach.id && x.end > app.now)
  const next = upcoming[0]
  const nextCur = next ? app.curriculumFor(next.templateId) : null
  const isToday = next && next.start.toDateString() === app.now.toDateString()

  const exportHours = () => {
    const rows = [['monitor', 'mes', 'horas', 'clases_por_semana', 'asistencia_media']]
    for (const c of app.coaches) rows.push([c.name, app.now.toISOString().slice(0, 7), String(c.hoursThisMonth), String(stats(c.id).perWeek), String(c.avgAttendance)])
    const csv = rows.map((r) => r.map((v) => `"${v.replace(/"/g, '""')}"`).join(';')).join('\n')
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `horas-monitores-${app.now.toISOString().slice(0, 7)}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <>
      <Screen gap={12}>
        <div className="flex items-center gap-3">
          <BackButton label="Volver a monitores" to="/staff/monitores" />
          <div className="flex flex-col gap-[1px]">
            <h1 className="m-0 text-[26px] font-bold leading-tight tracking-[-0.02em]">{coach.name}</h1>
            <span className="text-[13px] text-muted">
              {coachSubtitle(coach)} · {s.perWeek} {s.perWeek === 1 ? 'clase' : 'clases'} por semana
            </span>
          </div>
        </div>

        {next && (
          <div className="flex flex-col gap-[6px] rounded-[20px] bg-ink px-4 py-[14px] text-on-ink">
            <Eyebrow onInk>
              {isToday ? 'Hoy le toca dar' : `Próxima clase · ${mediumDay(next.start)}`} · {hhmm(next.start)}
            </Eyebrow>
            <span className="text-[16px] font-bold leading-[1.3]">{nextCur?.unit ?? `${app.template(next.templateId).name} · tema libre`}</span>
            <span className="text-[13px] text-muted-on-ink">
              {nextCur?.curriculum ? `${nextCur.curriculum.name} · semana ${nextCur.week} de ${nextCur.curriculum.weeks}` : classTitle(app.template(next.templateId))}
              {app.state.substitutes[next.id] && ` · sustituye ${app.coach(app.state.substitutes[next.id])?.name}`}
            </span>
          </div>
        )}

        <Eyebrow>Clases y currículo asignado</Eyebrow>
        <div className="flex flex-col gap-2">
          {templates.map((t) => {
            const cur = app.curriculumFor(t.id)
            const isOpen = t.discipline === 'openmat'
            const days = t.weekdays.map((d) => DAY_SHORT[d]).join(' · ')
            return (
              <div key={t.id} className="flex items-center gap-[10px] rounded-2xl bg-surface px-[14px] py-[10px]">
                <div className="flex flex-1 flex-col gap-[2px]">
                  <span className="text-[14px] font-semibold">
                    {classTitle(t)}
                  </span>
                  <span className="text-[12px] text-muted">
                    {days} {t.start}
                  </span>
                  <span className={cx('text-[12px]', !cur.curriculum && !isOpen ? 'text-warn-text' : 'text-ink-2')}>
                    {isOpen ? 'No aplica' : cur.curriculum ? `${cur.curriculum.name} · semana ${cur.week} de ${cur.curriculum.weeks}` : 'Sin currículo: tema libre'}
                  </span>
                </div>
                {!isOpen && (
                  <Btn size="sm" variant={cur.curriculum ? 'outline' : 'ink'} className="px-[14px] text-[13px]" onClick={() => setAssignFor(t)}>
                    {cur.curriculum ? 'Cambiar' : 'Asignar'}
                  </Btn>
                )}
              </div>
            )
          })}
        </div>
      </Screen>

      <ActionBar row>
        <Btn variant="outline" className="flex-1 text-[14px]" onClick={() => setSubOpen(true)} disabled={upcoming.length === 0}>
          Poner sustituto
        </Btn>
        <Btn variant="outline" className="flex-1 text-[14px]" onClick={exportHours}>
          Exportar horas
        </Btn>
      </ActionBar>

      <Sheet open={!!assignFor} onClose={() => setAssignFor(null)} title={assignFor ? `Currículo de ${classTitle(assignFor)}` : ''}>
        {assignFor &&
          [...app.curricula.map((c) => ({ id: c.id as string | null, label: c.name, sub: `${c.weeks} semanas` })), { id: null, label: 'Sin currículo', sub: 'Tema libre' }].map((o) => {
            const active = app.curriculumFor(assignFor.id).curriculum?.id === o.id || (o.id === null && !app.curriculumFor(assignFor.id).curriculum)
            return (
              <button
                key={o.label}
                aria-pressed={active}
                onClick={() => {
                  app.assignCurriculum(assignFor.id, o.id)
                  app.toast(o.id ? `${o.label} asignado desde la semana 1` : 'Clase sin currículo')
                  setAssignFor(null)
                }}
                className={cx('flex min-h-[56px] items-center justify-between rounded-2xl border-[1.5px] px-4 text-left', active ? 'border-ink bg-ink text-on-ink' : 'border-border bg-bg text-ink')}
              >
                <span className="text-[15px] font-semibold">{o.label}</span>
                <span className={cx('text-[13px]', active ? 'text-muted-on-ink' : 'text-muted')}>{o.sub}</span>
              </button>
            )
          })}
      </Sheet>

      <SubstituteSheet open={subOpen} onClose={() => setSubOpen(false)} sessions={upcoming.slice(0, 6)} coachId={coach.id} />
    </>
  )
}

function SubstituteSheet({ open, onClose, sessions, coachId }: { open: boolean; onClose: () => void; sessions: Session[]; coachId: string }) {
  const app = useApp()
  const [session, setSession] = useState<Session | null>(null)
  const others = app.coaches.filter((c) => c.id !== coachId)
  const close = () => {
    setSession(null)
    onClose()
  }
  return (
    <Sheet open={open} onClose={close} title={session ? 'Elige sustituto' : 'Elige la sesión'}>
      {!session &&
        sessions.map((s) => {
          const t = app.template(s.templateId)
          const sub = app.state.substitutes[s.id]
          return (
            <button key={s.id} onClick={() => setSession(s)} className="flex min-h-[56px] items-center justify-between rounded-2xl border-[1.5px] border-border bg-bg px-4 text-left text-ink">
              <span className="flex flex-col">
                <span className="text-[15px] font-semibold">
                  {classTitle(t)}
                </span>
                <span className="text-[12px] text-muted">
                  {WEEKDAY_LETTER[s.start.getDay()]} {mediumDay(s.start)} · {hhmm(s.start)}
                </span>
              </span>
              {sub && <span className="text-[12px] text-muted">Sustituye {app.coach(sub)?.name}</span>}
            </button>
          )
        })}
      {session &&
        others.map((c) => (
          <button
            key={c.id}
            onClick={() => {
              app.setSubstitute(session.id, c.id)
              app.toast(`${c.name} sustituye el ${mediumDay(session.start)} a las ${hhmm(session.start)}`)
              close()
            }}
            className="flex min-h-[56px] items-center justify-between rounded-2xl border-[1.5px] border-border bg-bg px-4 text-left text-ink"
          >
            <span className="text-[15px] font-semibold">{c.name}</span>
            <span className="text-[13px] text-muted">{coachSubtitle(c)}</span>
          </button>
        ))}
    </Sheet>
  )
}
