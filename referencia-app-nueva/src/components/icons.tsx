import type { SVGProps } from 'react'

type P = SVGProps<SVGSVGElement> & { size?: number; strokeWidth?: number }

function Svg({ size = 24, strokeWidth = 2, children, ...rest }: P) {
  return (
    <svg
      aria-hidden="true"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      {...rest}
    >
      {children}
    </svg>
  )
}

export const IconHome = (p: P) => (
  <Svg {...p}>
    <path d="M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z" />
  </Svg>
)
export const IconCalendar = (p: P) => (
  <Svg {...p}>
    <rect x="3" y="5" width="18" height="16" rx="3" />
    <path d="M3 10h18M8 3v4M16 3v4" />
  </Svg>
)
export const IconPlay = (p: P) => (
  <Svg {...p}>
    <rect x="3" y="5" width="18" height="14" rx="3" />
    <path d="M10 9.5v5l4.5-2.5z" />
  </Svg>
)
export const IconChart = (p: P) => (
  <Svg {...p}>
    <path d="M4 20V10M10 20V4M16 20v-7M22 20H2" />
  </Svg>
)
export const IconUser = (p: P) => (
  <Svg {...p}>
    <circle cx="12" cy="8" r="4" />
    <path d="M4 21c0-4 4-6 8-6s8 2 8 6" />
  </Svg>
)
export const IconUsers = (p: P) => (
  <Svg {...p}>
    <circle cx="9" cy="8" r="3.5" />
    <path d="M2 20c0-3.5 3-5.5 7-5.5s7 2 7 5.5M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.8c2.5.6 4 2.3 4 5.2" />
  </Svg>
)
export const IconCard = (p: P) => (
  <Svg {...p}>
    <rect x="3" y="6" width="18" height="13" rx="3" />
    <path d="M3 10h18M7 15h4" />
  </Svg>
)
export const IconMore = ({ size = 24, ...p }: P) => (
  <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="currentColor" {...p}>
    <circle cx="5" cy="12" r="1.8" />
    <circle cx="12" cy="12" r="1.8" />
    <circle cx="19" cy="12" r="1.8" />
  </svg>
)
export const IconQr = (p: P) => (
  <Svg {...p}>
    <rect x="3" y="3" width="7" height="7" rx="1" />
    <rect x="14" y="3" width="7" height="7" rx="1" />
    <rect x="3" y="14" width="7" height="7" rx="1" />
    <path d="M14 14h3v3h-3zM20 14v7M14 20h3" />
  </Svg>
)
export const IconBack = (p: P) => (
  <Svg strokeWidth={2.4} {...p}>
    <path d="M15 5l-7 7 7 7" />
  </Svg>
)
export const IconChevron = (p: P) => (
  <Svg strokeWidth={2.4} {...p}>
    <path d="M9 5l7 7-7 7" />
  </Svg>
)
export const IconCheck = (p: P) => (
  <Svg strokeWidth={3} {...p}>
    <path d="M5 12l5 5 9-10" />
  </Svg>
)
export const IconCircle = (p: P) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="8" />
  </Svg>
)
export const IconWifiOff = (p: P) => (
  <Svg {...p}>
    <path d="M2 8.5a15 15 0 0 1 20 0M5.5 12a10 10 0 0 1 13 0M9 15.5a5 5 0 0 1 6 0M3 3l18 18" />
  </Svg>
)
export const IconPlayFill = ({ size = 24, ...p }: P) => (
  <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="currentColor" {...p}>
    <path d="M8 5.5v13l11-6.5z" />
  </svg>
)
export const IconLock = (p: P) => (
  <Svg {...p}>
    <rect x="5" y="11" width="14" height="10" rx="2" />
    <path d="M8 11V8a4 4 0 0 1 8 0v3" />
  </Svg>
)
export const IconShare = (p: P) => (
  <Svg {...p}>
    <path d="M12 3v12M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6" />
  </Svg>
)
export const IconPlusSquare = (p: P) => (
  <Svg {...p}>
    <rect x="3" y="3" width="18" height="18" rx="4" />
    <path d="M12 8v8M8 12h8" />
  </Svg>
)
export const IconClose = (p: P) => (
  <Svg strokeWidth={2.4} {...p}>
    <path d="M6 6l12 12M18 6L6 18" />
  </Svg>
)
export const IconNews = (p: P) => (
  <Svg {...p}>
    <rect x="3" y="4" width="18" height="16" rx="3" />
    <path d="M7 15l3-3 2.5 2.5L15 12l2 2M15.5 8.5h.01" />
  </Svg>
)
export const IconProfile = (p: P) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="9" />
    <circle cx="12" cy="10" r="3" />
    <path d="M6.5 18.5c1.2-2 3.2-3 5.5-3s4.3 1 5.5 3" />
  </Svg>
)
export const IconStats = (p: P) => (
  <Svg {...p}>
    <path d="M5 20v-6M12 20V5M19 20v-9" />
  </Svg>
)
export const IconShareNodes = (p: P) => (
  <Svg {...p}>
    <circle cx="18" cy="5" r="2.5" />
    <circle cx="6" cy="12" r="2.5" />
    <circle cx="18" cy="19" r="2.5" />
    <path d="M8.2 10.8l7.6-4.4M8.2 13.2l7.6 4.4" />
  </Svg>
)
export const IconPeople = (p: P) => (
  <Svg {...p}>
    <circle cx="9" cy="9" r="3" />
    <path d="M3.5 19c.6-3 2.8-4.5 5.5-4.5s4.9 1.5 5.5 4.5M16 6.5a2.5 2.5 0 0 1 0 5M17.5 14.5c1.7.5 2.8 2 3 4.5" />
  </Svg>
)
export const IconPerson = (p: P) => (
  <Svg {...p}>
    <circle cx="12" cy="8" r="3.5" />
    <path d="M5 20c.8-3.5 3.6-5.5 7-5.5s6.2 2 7 5.5" />
  </Svg>
)
export const IconStar = ({ size = 24, ...p }: P) => (
  <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="currentColor" {...p}>
    <path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z" />
  </svg>
)
export const IconSettings = (p: P) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" />
  </Svg>
)
export const IconAward = (p: P) => (
  <Svg {...p}>
    <circle cx="12" cy="9" r="5.5" />
    <path d="M8.5 13.5 7 21l5-2.5 5 2.5-1.5-7.5" />
  </Svg>
)
export const IconHeart = (p: P) => (
  <Svg {...p}>
    <path d="M12 20s-7.5-4.6-7.5-10.2A4.3 4.3 0 0 1 12 7.2a4.3 4.3 0 0 1 7.5 2.6C19.5 15.4 12 20 12 20z" />
  </Svg>
)
export const IconHelp = (p: P) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="9" />
    <path d="M9.6 9.3a2.5 2.5 0 0 1 4.8.9c0 1.7-2.4 2.2-2.4 3.6M12 17.2h.01" />
  </Svg>
)
export const IconReceipt = (p: P) => (
  <Svg {...p}>
    <path d="M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6M9 16h3" />
  </Svg>
)
export const IconDoc = (p: P) => (
  <Svg {...p}>
    <path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8zM14 3v5h5M9 13h6M9 17h6" />
  </Svg>
)
export const IconLogout = (p: P) => (
  <Svg {...p}>
    <path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 8l-4 4 4 4M6 12h10" />
  </Svg>
)
export const IconMail = (p: P) => (
  <Svg {...p}>
    <rect x="3" y="5" width="18" height="14" rx="2" />
    <path d="m4 7 8 6 8-6" />
  </Svg>
)
export const IconPhone = (p: P) => (
  <Svg {...p}>
    <path d="M5 4h3.5l1.5 4-2 1.5a11 11 0 0 0 6.5 6.5l1.5-2 4 1.5V19a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z" />
  </Svg>
)
export const IconChat = (p: P) => (
  <Svg {...p}>
    <path d="M4 20l1.3-3.9A8 8 0 1 1 8 19z" />
  </Svg>
)
export const IconPin = (p: P) => (
  <Svg {...p}>
    <path d="M12 21s-6.5-6-6.5-11a6.5 6.5 0 0 1 13 0c0 5-6.5 11-6.5 11z" />
    <circle cx="12" cy="10" r="2.3" />
  </Svg>
)
export const IconGlobe = (p: P) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="9" />
    <path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" />
  </Svg>
)
export const IconAt = (p: P) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="3.5" />
    <path d="M15.5 12v1.5a2.5 2.5 0 0 0 5 0V12a8.5 8.5 0 1 0-3.3 6.7" />
  </Svg>
)
export const IconPhoneLink = (p: P) => (
  <Svg {...p}>
    <rect x="6" y="2.5" width="12" height="19" rx="2.5" />
    <path d="M11 18.5h2" />
  </Svg>
)
export const IconCrown = ({ size = 24, ...p }: P) => (
  <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="currentColor" {...p}>
    <path d="M3 8l4.5 3.5L12 5l4.5 6.5L21 8l-2 10H5z" />
  </svg>
)
export const IconTrendUp = (p: P) => (
  <Svg {...p}>
    <path d="M3 17l6-6 4 4 8-8M15 7h6v6" />
  </Svg>
)
export const IconTrash = (p: P) => (
  <Svg {...p}>
    <path d="M4 7h16M9 7V4.5h6V7M6.5 7l1 12.5h9l1-12.5M10 11v5.5M14 11v5.5" />
  </Svg>
)
export const IconThumbtack = (p: P) => (
  <Svg {...p}>
    <path d="M9 3h6l-1 6 3 3v2H7v-2l3-3zM12 14v7" />
  </Svg>
)
export const IconEdit = (p: P) => (
  <Svg {...p}>
    <path d="M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4" />
  </Svg>
)
