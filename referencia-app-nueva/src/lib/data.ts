/**
 * Datos de ejemplo. Nombres, clases, importes y cifras son ficticios.
 * [NOMBRE] y [PRECIO] marcan lo que falta por decidir.
 * Se sustituirán por consultas a Supabase en los pasos 1–6 del plan.
 */
import type { Belt, ClassTemplate, Coach, Curriculum, CurriculumAssignment, Member, Plan, Video } from './types'

export const GYM = {
  name: 'ITACA Jiu Jitsu',
  timeZone: 'Europe/Madrid',
  /** Horas antes del inicio hasta las que se cancela sin penalización */
  cancelWindowHours: 2,
  /** Ventana de check-in: minutos antes y después del inicio */
  checkInBeforeMin: 30,
  checkInAfterMin: 15,
}

export const ME_ID = 'me'

/** Orden: infantiles y después adultos */
export const BELTS: Belt[] = ['blanco', 'gris', 'amarillo', 'naranja', 'verde', 'azul', 'morado', 'marron', 'negro']

export const BELT_LABEL: Record<Belt, string> = {
  blanco: 'Blanco',
  gris: 'Gris',
  amarillo: 'Amarillo',
  naranja: 'Naranja',
  verde: 'Verde',
  azul: 'Azul',
  morado: 'Morado',
  marron: 'Marrón',
  negro: 'Negro',
}

export const BELT_COLOR: Record<Belt, string> = {
  blanco: 'var(--color-belt-white)',
  gris: '#8A8A86',
  amarillo: '#E9C21C',
  naranja: '#E07A1F',
  verde: '#2E8B57',
  azul: 'var(--color-belt-blue)',
  morado: 'var(--color-belt-purple)',
  marron: 'var(--color-belt-brown)',
  negro: 'var(--color-belt-black)',
}

export const ME: Member = { id: ME_ID, name: 'Elena Díaz', belt: 'azul', stripes: 2, plan: 'blue' }

export const MEMBERS: Member[] = [
  ME,
  { id: 'm01', name: 'Ana Ruiz', belt: 'blanco', stripes: 3, plan: 'black' },
  { id: 'm02', name: 'Carlos Vega', belt: 'azul', stripes: 1, plan: 'bjj-white', debt: true },
  { id: 'm03', name: 'Javier Soto', belt: 'morado', stripes: 0, plan: 'black' },
  { id: 'm04', name: 'Lucía Marín', belt: 'blanco', stripes: 0, plan: 'bono-10', trial: true },
  { id: 'm05', name: 'Marcos Gil', belt: 'blanco', stripes: 1, plan: 'bjj-white' },
  { id: 'm06', name: 'Paula Navarro', belt: 'azul', stripes: 4, plan: 'black', readyToPromote: true },
  { id: 'm07', name: 'Luis Moreno', belt: 'blanco', stripes: 2, plan: 'black' },
  { id: 'm08', name: 'Andrea Ramos', belt: 'morado', stripes: 1, plan: 'corral' },
  { id: 'm09', name: 'Jorge Serrano', belt: 'azul', stripes: 3, plan: 'black' },
  { id: 'm10', name: 'Sara Ortega', belt: 'blanco', stripes: 1, plan: 'bjj-white' },
  { id: 'm11', name: 'Diego Castro', belt: 'marron', stripes: 2, plan: 'black' },
  { id: 'm12', name: 'Nuria Prieto', belt: 'blanco', stripes: 0, plan: 'bono-10' },
  { id: 'm13', name: 'Raúl Herrero', belt: 'azul', stripes: 0, plan: 'black', debt: true },
  { id: 'm14', name: 'Clara Molina', belt: 'blanco', stripes: 4, plan: 'black', readyToPromote: true },
  { id: 'm15', name: 'Pablo Iglesias', belt: 'morado', stripes: 3, plan: 'corral' },
  { id: 'm16', name: 'Irene Santos', belt: 'blanco', stripes: 2, plan: 'bjj-white' },
  { id: 'm17', name: 'Hugo Medina', belt: 'azul', stripes: 2, plan: 'black' },
  { id: 'm18', name: 'Marta León', belt: 'blanco', stripes: 1, plan: 'black' },
  { id: 'm19', name: 'Álvaro Cano', belt: 'azul', stripes: 1, plan: 'bjj-white' },
  { id: 'm20', name: 'Eva Rubio', belt: 'blanco', stripes: 0, plan: 'black' },
  { id: 'm21', name: 'Adrián Vidal', belt: 'morado', stripes: 2, plan: 'black' },
  { id: 'm22', name: 'Laura Pascual', belt: 'blanco', stripes: 3, plan: 'black' },
  { id: 'm23', name: 'Sergio Lozano', belt: 'azul', stripes: 4, plan: 'black' },
  { id: 'm24', name: 'Alba Gallego', belt: 'blanco', stripes: 1, plan: 'bjj-white' },
  { id: 'm25', name: 'Iker Domínguez', belt: 'marron', stripes: 0, plan: 'corral' },
  { id: 'm26', name: 'Noa Calvo', belt: 'blanco', stripes: 2, plan: 'bjj-kids' },
  { id: 'm27', name: 'Leo Peña', belt: 'blanco', stripes: 1, plan: 'bjj-kids' },
  { id: 'm28', name: 'Vera Campos', belt: 'blanco', stripes: 3, plan: 'bjj-kids' },
  { id: 'm29', name: 'Mateo Fuentes', belt: 'blanco', stripes: 0, plan: 'bjj-kids' },
  { id: 'm30', name: 'Daniel Ibáñez', belt: 'azul', stripes: 1, plan: 'black' },
  { id: 'm31', name: 'Lola Vargas', belt: 'blanco', stripes: 2, plan: 'black' },
  { id: 'm32', name: 'Bruno Sanz', belt: 'blanco', stripes: 0, plan: 'bjj-white' },
]

/**
 * Instructores reales (itacajiujitsu.com, 15/11/2026).
 * Horas y asistencia media se calcularán con datos reales (pasos 4 y 8).
 */
export const COACHES: Coach[] = [
  { id: 'c1', name: 'Cipri', belt: 'negro', title: 'Head coach', hoursThisMonth: 0, avgAttendance: 0, unregisteredSessions: 0 },
  { id: 'c2', name: 'Boris', belt: 'morado', title: 'Instructor', hoursThisMonth: 0, avgAttendance: 0, unregisteredSessions: 0 },
  { id: 'c3', name: 'Marta', belt: 'morado', title: 'Instructora', hoursThisMonth: 0, avgAttendance: 0, unregisteredSessions: 0 },
]

export const CURRICULA: Curriculum[] = [
  {
    id: 'cur-guardia',
    name: 'Guardia cerrada',
    weeks: 4,
    units: [
      'Control de postura y agarres básicos',
      'Guardia cerrada: romper la postura y armbar',
      'Triángulo desde guardia cerrada',
      'Raspado de tijera y de cadera',
    ],
  },
  {
    id: 'cur-media',
    name: 'Pasajes de media guardia',
    weeks: 6,
    units: [
      'Aplastar la media guardia',
      'Pasaje de rodilla cruzada',
      'Underhook y crossface',
      'Pasaje de cadera',
      'Contraataques a la media guardia profunda',
      'Rondas específicas',
    ],
  },
  {
    id: 'cur-juegos',
    name: 'Juegos de base',
    weeks: 8,
    units: [
      'Caídas y desplazamientos',
      'Equilibrio y base',
      'Juego del cocodrilo',
      'Montada y escapes jugando',
      'Guardia y puente',
      'Agarres sin tirones',
      'Rey de la pista',
      'Repaso con juegos',
    ],
  },
  {
    id: 'cur-montada',
    name: 'Escapes de montada',
    weeks: 4,
    units: ['Puente y rueda (upa)', 'Escape de codo-rodilla', 'Escape a media guardia', 'Rondas desde montada'],
  },
]

/**
 * Horario real de ITACA (itacajiujitsu.com, 15/11/2026).
 * La web no dice qué instructor da cada clase ni el aforo: profesor por asignar
 * y aforo provisional; se completan desde el editor de horario.
 */
const T = (id: string, name: string, discipline: ClassTemplate['discipline'], weekdays: number[], start: string, durationMin: number, capacity: number, level = '', kidsOnly = false): ClassTemplate => ({
  id, name, level, discipline, weekdays, start, durationMin, capacity, coachId: null, place: 'Tatami', kidsOnly,
})

export const TEMPLATES: ClassTemplate[] = [
  T('t-fund-l', 'Fundamentos', 'gi', [1], '07:00', 60, 50),
  T('t-fundgi-l', 'Fundamentos (Gi)', 'gi', [1], '17:00', 60, 50),
  T('t-grap-m', 'Grappling No Gi', 'nogi', [2], '10:00', 90, 50),
  T('t-kids710-m', 'Kids', 'infantil', [2], '16:45', 60, 50, '7 a 10 años', true),
  T('t-adv-nogi', 'Avanzados No Gi', 'nogi', [2], '18:00', 120, 50),
  T('t-ini-nogi', 'Iniciación No Gi', 'nogi', [2], '20:00', 60, 50),
  T('t-fund-nogi', 'Fundamentos No Gi', 'nogi', [3], '07:00', 60, 50),
  T('t-grap-x', 'No Gi Grappling', 'nogi', [3], '17:00', 60, 50),
  T('t-gi-j', 'BJJ Gi', 'gi', [4], '10:00', 90, 50),
  T('t-kids46', 'Kids', 'infantil', [4], '16:45', 60, 50, '4 a 6 años', true),
  T('t-adv-gi-j', 'Avanzados Gi', 'gi', [4], '18:00', 120, 50),
  T('t-ini-gi', 'Iniciación Gi', 'gi', [4], '20:00', 60, 50),
  T('t-sparring', 'Específico Sparring', 'gi', [5], '07:00', 60, 50),
  T('t-kids710-v', 'BJJ Kids Gi', 'infantil', [5], '16:45', 60, 50, '7 a 10 años', true),
  T('t-adv-gi-v', 'Avanzado Gi', 'gi', [5], '18:30', 90, 50),
  T('t-gi-libre', 'BJJ Gi Libre', 'gi', [6], '10:00', 60, 50),
  T('t-openmat', 'Open Mat', 'openmat', [6], '11:00', 90, 50),
]

/** Currículos de ejemplo asignados a algunas clases */
export const ASSIGNMENTS: CurriculumAssignment[] = [
  { templateId: 't-fundgi-l', curriculumId: 'cur-guardia', week: 2 },
  { templateId: 't-adv-nogi', curriculumId: 'cur-media', week: 1 },
  { templateId: 't-kids710-m', curriculumId: 'cur-juegos', week: 3 },
  { templateId: 't-kids710-v', curriculumId: 'cur-juegos', week: 3 },
  { templateId: 't-ini-gi', curriculumId: 'cur-montada', week: 2 },
]

/** Tarifas vigentes de ITACA (capturas de la app actual, 15/11/2026) */
const P = (id: string, name: string, kind: Plan['kind'], euros: number, period: Plan['period'], sessions: number | null, extra: Partial<Plan> = {}): Plan => ({
  id, name, kind, priceCents: euros * 100, period, sessions,
  description: '', sessionsPerMonth: true, validityMonths: null, autoRenew: true, audience: 'adults', ...extra,
})

export const PLANS: Plan[] = [
  P('1-dia-semana', '1 Día por Semana', 'membership', 30, 'month', null, { weeklySessions: 1 }),
  P('bjj-white', 'Bjj White', 'membership', 50, 'month', 8),
  P('blue', 'Blue', 'membership', 60, 'month', 12),
  P('black', 'Black', 'membership', 70, 'month', 16),
  P('corral', 'Corral', 'membership', 80, 'month', 32),
  P('fundador', 'Fundador', 'membership', 50, 'month', null),
  P('bono-10', 'Bono 10 Clases', 'pack', 70, 'quarter', 10, { description: '10 clases durante máximo 3 meses', sessionsPerMonth: false, validityMonths: 3, autoRenew: false }),
  P('bjj-kids', 'Bjj Kids', 'membership', 40, 'month', 8, { description: 'Bjj Kids martes y viernes', audience: 'kids' }),
  P('anual-kids', 'Anual BJJ Kids', 'membership', 300, 'year', 8, { description: 'Curso completo Bjj Kids', validityMonths: 12, autoRenew: false, audience: 'kids' }),
  P('pase-dia', 'Pase por un Día', 'drop_in', 10, 'once', 1, { description: 'Válido 1 día de entreno', sessionsPerMonth: false, autoRenew: false, audience: 'all' }),
]

export const isKidsPlan = (id: string) => PLANS.find((p) => p.id === id)?.audience === 'kids'

const euroStr = (cents: number) => `${(cents / 100).toLocaleString('es-ES', { maximumFractionDigits: 2 })} €`

/** "30 €/mes", "70 € / 3 meses", "300 € / año", "10 €" */
export function planPrice(p: Pick<Plan, 'priceCents' | 'period'>): string {
  const e = euroStr(p.priceCents)
  return { month: `${e}/mes`, quarter: `${e} / 3 meses`, year: `${e} / año`, once: e }[p.period]
}

/** "1 sesión/semana", "4 sesiones/mes", "Sesiones ilimitadas", "10 sesiones", "1 sesión" */
export function planSessions(p: Pick<Plan, 'sessions' | 'sessionsPerMonth' | 'weeklySessions'>): string {
  if (p.weeklySessions) return `${p.weeklySessions} ${p.weeklySessions === 1 ? 'sesión' : 'sesiones'}/semana`
  if (p.sessions == null) return 'Sesiones ilimitadas'
  const n = `${p.sessions} ${p.sessions === 1 ? 'sesión' : 'sesiones'}`
  return p.sessionsPerMonth ? `${n}/mes` : n
}

/** "Se renueva cada mes", "Válido 3 meses", "Dura 1 año", "Sin caducidad" */
export function planRenewal(p: Pick<Plan, 'autoRenew' | 'period' | 'validityMonths'>): string {
  if (p.autoRenew) return p.period === 'year' ? 'Se renueva cada año' : 'Se renueva cada mes'
  if (p.validityMonths === 12) return 'Dura 1 año'
  if (p.validityMonths) return `Válido ${p.validityMonths} meses`
  return 'Sin caducidad'
}


/** Historial de asistencia del alumno de ejemplo en 2026 (enero–noviembre) */
export const MY_MONTHLY_2026 = [8, 10, 12, 9, 11, 10, 6, 4, 12, 13, 9]
export const MY_PROGRESS = {
  classesTowardNext: 42,
  classesRequired: 60,
  monthsInRank: 8,
  monthsRequired: 6,
  coachApproval: false,
  weekStreak: 6,
  thisWeek: 3,
  rankSince: 'marzo de 2025',
  history: [
    { label: 'Segundo grado de azul', date: 'Mar 2026' },
    { label: 'Primer grado de azul', date: 'Sep 2025' },
    { label: 'Cinturón azul', date: 'Mar 2025' },
  ],
}

/** Métricas de cobros de noviembre de 2026 (paso 6: vistas SQL) */
export const BILLING = {
  month: 'Nov 2026',
  // Alumnos por tarifa: cifras de ejemplo. Previsto mensual = alumnos × precio al mes
  // (el bono se reparte en 3 meses y el anual infantil en 12).
  byPlan: [
    { name: 'Bjj White', count: 30, unit: 'alumnos', expected: 1500 },
    { name: 'Blue', count: 22, unit: 'alumnos', expected: 1320 },
    { name: 'Black', count: 18, unit: 'alumnos', expected: 1260 },
    { name: 'Fundador', count: 12, unit: 'alumnos', expected: 600 },
    { name: 'Bjj Kids', count: 15, unit: 'alumnos', expected: 600 },
    { name: '1 Día por Semana', count: 14, unit: 'alumnos', expected: 420 },
    { name: 'Corral', count: 4, unit: 'alumnos', expected: 320 },
    { name: 'Bono 10 Clases', count: 7, unit: 'alumnos', expected: 163 },
    { name: 'Anual BJJ Kids', count: 4, unit: 'alumnos', expected: 100 },
    { name: 'ITACA+', count: 35, unit: 'suscriptores', expected: 350, accent: true },
  ],

  byMethod: [
    { name: 'Bizum', amount: 2380 },
    { name: 'Transfer.', amount: 1810 },
    { name: 'Efectivo', amount: 1240 },
    { name: 'Stripe', amount: 1050 },
  ],
  pendingStudents: 9,
  payingStudents: 126,
  newSubs: 6,
  cancelledSubs: 2,
  overdue: [
    { memberId: 'm02', amount: 50, days: 12 },
    { memberId: 'm13', amount: 70, days: 34 },
  ],
}

export const VIDEOS: Video[] = [
  { id: 'v-g1', title: 'Control de postura en guardia cerrada', kind: 'tecnica', curriculumId: 'cur-guardia', order: 1, minutes: 5, tags: ['Guardia cerrada', 'Control', 'Cinturón blanco'] },
  { id: 'v-g2', title: 'Agarres de manga y cuello', kind: 'tecnica', curriculumId: 'cur-guardia', order: 2, minutes: 7, tags: ['Guardia cerrada', 'Agarres', 'Cinturón blanco'] },
  { id: 'v-g3', title: 'Romper la postura', kind: 'tecnica', curriculumId: 'cur-guardia', order: 3, minutes: 6, tags: ['Guardia cerrada', 'Control', 'Cinturón blanco'] },
  { id: 'v-g4', title: 'Armbar desde guardia cerrada', kind: 'tecnica', curriculumId: 'cur-guardia', order: 4, minutes: 8, tags: ['Guardia cerrada', 'Sumisión', 'Cinturón blanco'], classLabel: 'BJJ Gi · Fundamentos' },
  { id: 'v-g5', title: 'Triángulo desde guardia cerrada', kind: 'tecnica', curriculumId: 'cur-guardia', order: 5, minutes: 9, tags: ['Guardia cerrada', 'Sumisión'] },
  { id: 'v-g6', title: 'Raspado de tijera', kind: 'tecnica', curriculumId: 'cur-guardia', order: 6, minutes: 7, tags: ['Guardia cerrada', 'Raspado'] },
  { id: 'v-g7', title: 'Raspado de cadera', kind: 'tecnica', curriculumId: 'cur-guardia', order: 7, minutes: 6, tags: ['Guardia cerrada', 'Raspado'] },
  { id: 'v-g8', title: 'Kimura desde guardia cerrada', kind: 'tecnica', curriculumId: 'cur-guardia', order: 8, minutes: 8, tags: ['Guardia cerrada', 'Sumisión'] },
  { id: 'v-g9', title: 'Guillotina desde guardia cerrada', kind: 'tecnica', curriculumId: 'cur-guardia', order: 9, minutes: 6, tags: ['Guardia cerrada', 'Sumisión'] },
  { id: 'v-g10', title: 'Encadenar armbar y triángulo', kind: 'tecnica', curriculumId: 'cur-guardia', order: 10, minutes: 10, tags: ['Guardia cerrada', 'Sumisión'] },
  { id: 'v-g11', title: 'Defensa del pasaje de rodillas', kind: 'tecnica', curriculumId: 'cur-guardia', order: 11, minutes: 7, tags: ['Guardia cerrada', 'Defensa'] },
  { id: 'v-g12', title: 'Rondas específicas de guardia cerrada', kind: 'tecnica', curriculumId: 'cur-guardia', order: 12, minutes: 12, tags: ['Guardia cerrada', 'Rondas'] },
  { id: 'v-m1', title: 'Puente y rueda (upa)', kind: 'tecnica', curriculumId: 'cur-montada', order: 1, minutes: 6, tags: ['Montada', 'Escape', 'Cinturón blanco'] },
  { id: 'v-m2', title: 'Escape de codo-rodilla', kind: 'tecnica', curriculumId: 'cur-montada', order: 2, minutes: 8, tags: ['Montada', 'Escape'] },
  { id: 'v-m3', title: 'Escape a media guardia', kind: 'tecnica', curriculumId: 'cur-montada', order: 3, minutes: 7, tags: ['Montada', 'Escape'] },
  { id: 'v-m4', title: 'Escape con gancho de pie', kind: 'tecnica', curriculumId: 'cur-montada', order: 4, minutes: 6, tags: ['Montada', 'Escape'] },
  { id: 'v-m5', title: 'Montada alta: cómo no perderla', kind: 'tecnica', curriculumId: 'cur-montada', order: 5, minutes: 7, tags: ['Montada', 'Control'] },
  { id: 'v-m6', title: 'Escape de montada técnica', kind: 'tecnica', curriculumId: 'cur-montada', order: 6, minutes: 6, tags: ['Montada', 'Escape'] },
  { id: 'v-m7', title: 'Escape cuando cruza la mano', kind: 'tecnica', curriculumId: 'cur-montada', order: 7, minutes: 5, tags: ['Montada', 'Escape'] },
  { id: 'v-m8', title: 'Rondas desde montada', kind: 'tecnica', curriculumId: 'cur-montada', order: 8, minutes: 10, tags: ['Montada', 'Rondas'] },
  { id: 'v-c1', title: 'BJJ Gi · Fundamentos', kind: 'clase', minutes: 8, tags: ['Clase', 'Gi'], classLabel: 'Mié 11 nov', classDate: '2026-11-11' },
  { id: 'v-c2', title: 'No-Gi · Avanzado', kind: 'clase', minutes: 11, tags: ['Clase', 'No-Gi'], classLabel: 'Mar 10 nov', classDate: '2026-11-10' },
]

/** Progreso inicial de vídeo (porcentaje visto) del alumno de ejemplo */
export const INITIAL_VIDEO_PROGRESS: Record<string, number> = {
  'v-g1': 100,
  'v-g2': 100,
  'v-g3': 100,
  'v-g4': 40,
}

/** "Head coach · cinturón negro" (o lo que se sepa del instructor) */
export function coachSubtitle(c: { title?: string; belt?: Belt }): string {
  const belt = c.belt ? `cinturón ${BELT_LABEL[c.belt].toLowerCase()}` : ''
  return [c.title, belt].filter(Boolean).join(' · ') || 'Instructor'
}

/** "Kids · 7 a 10 años" o solo "Avanzados Gi" si la clase no tiene nivel */
export function classTitle(t: { name: string; level: string }): string {
  return t.level ? `${t.name} · ${t.level}` : t.name
}

/** "Te quedan 3 de 4 clases este mes" a partir de la tarifa; null si no hay límite. `other`: hablando de otra persona ("Le quedan…") */
export function planUsageText(s: { period: 'week' | 'month' | 'total' | 'none'; limit: number | null; used: number | null } | null, other = false): string | null {
  if (!s || s.limit == null || s.used == null || s.period === 'none') return null
  const left = Math.max(0, s.limit - s.used)
  const when = s.period === 'week' ? 'esta semana' : s.period === 'month' ? 'este mes' : other ? 'en su bono' : 'en tu bono'
  if (left === 0) {
    const of = s.period === 'week' ? 'de esta semana' : s.period === 'month' ? 'de este mes' : 'del bono'
    if (other) return s.limit === 1 ? `Ha usado su clase ${of}` : `Ha usado sus ${s.limit} clases ${of}`
    return s.limit === 1 ? `Ya has usado tu clase ${of}` : `Ya has usado tus ${s.limit} clases ${of}`
  }
  return `${other ? 'Le' : 'Te'} ${left === 1 ? 'queda' : 'quedan'} ${left} de ${s.limit} ${s.limit === 1 ? 'clase' : 'clases'} ${when}`
}
