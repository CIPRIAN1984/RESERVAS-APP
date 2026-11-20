export type Discipline = 'gi' | 'nogi' | 'infantil' | 'mma' | 'openmat'
export type Belt = 'blanco' | 'gris' | 'amarillo' | 'naranja' | 'verde' | 'azul' | 'morado' | 'marron' | 'negro'
/** Identificador (slug) de la tarifa, p. ej. 'blue' o 'bjj-kids' */
export type PlanId = string

export interface Member {
  id: string
  name: string
  belt: Belt
  stripes: number
  plan: PlanId
  /** Cuota vencida */
  debt?: boolean
  /** Viene a clase de prueba */
  trial?: boolean
  /** Cumple las reglas de su siguiente grado */
  readyToPromote?: boolean
  /** Alumno real sin cinturón registrado todavía (paso 5) */
  rankUnknown?: boolean
  /** Ruta de la foto de perfil en el almacenamiento */
  avatarPath?: string | null
}

export interface Coach {
  id: string
  name: string
  belt?: Belt
  title?: string
  hoursThisMonth: number
  avgAttendance: number
  unregisteredSessions: number
}

export interface Curriculum {
  id: string
  name: string
  weeks: number
  /** Unidad por semana: técnica principal que se da */
  units: string[]
}

export interface ClassTemplate {
  id: string
  name: string
  level: string
  discipline: Discipline
  /** 1 = lunes … 7 = domingo */
  weekdays: number[]
  /** Hora local "HH:MM" (Europe/Madrid) */
  start: string
  durationMin: number
  capacity: number
  coachId: string | null
  place: string
  /** Solo para alumnos con plan infantil */
  kidsOnly?: boolean
  active?: boolean
}

export interface CurriculumAssignment {
  templateId: string
  curriculumId: string | null
  /** Semana actual del bloque (1-based) */
  week: number
}

/** Clase concreta generada a partir de una plantilla */
export interface Session {
  id: string
  templateId: string
  date: string // YYYY-MM-DD
  start: Date
  end: Date
  capacity: number
  coachId: string | null
  status?: 'scheduled' | 'cancelled' | 'done'
  cancelReason?: string
  /** Ocupación según el servidor (modo real) */
  bookedCount?: number
  waitlistCount?: number
}

export type BookingStatus = 'booked' | 'waitlist' | 'cancelled'

export interface Booking {
  id: string
  sessionId: string
  profileId: string
  status: BookingStatus
  createdAt: number
  late?: boolean
  /** Puesto en la lista de espera, si lo da el servidor */
  position?: number
}

export interface Attendance {
  sessionId: string
  profileId: string
  method: 'coach' | 'qr'
  /** Identificador generado en el móvil para que reenviar no duplique */
  clientId: string
  at: number
}

export interface Video {
  id: string
  title: string
  kind: 'clase' | 'tecnica'
  curriculumId?: string
  order?: number
  minutes: number
  tags: string[]
  /** Para clases grabadas: fecha y nombre de la clase */
  classLabel?: string
  classDate?: string
}

/** Mi tarifa vigente y lo que llevo gastado en el periodo actual */
export interface PlanStatus {
  memberPlanId: string
  planId: string
  planName: string
  startsOn: string
  endsOn: string | null
  period: 'week' | 'month' | 'total' | 'none'
  limit: number | null
  used: number | null
}

export interface Plan {
  id: PlanId
  name: string
  description: string
  kind: 'membership' | 'pack' | 'drop_in'
  priceCents: number
  period: 'month' | 'quarter' | 'year' | 'once'
  /** Identificador en la base (uuid); solo con servidor */
  dbId?: string
  /** null = sesiones ilimitadas */
  sessions: number | null
  /** Clases por semana (lunes a domingo); si tiene valor, manda sobre sessions */
  weeklySessions?: number | null
  /** Complemento (ITACA+): se suma a la tarifa principal, no la sustituye */
  isAddon?: boolean
  /** true: sesiones por mes; false: en total (bonos y pases) */
  sessionsPerMonth: boolean
  /** Validez de un bono o pase en meses; null = sin caducidad */
  validityMonths: number | null
  autoRenew: boolean
  audience: 'adults' | 'kids' | 'all'
}
