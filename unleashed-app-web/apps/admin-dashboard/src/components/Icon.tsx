import type { SVGProps } from 'react'

export type IconName =
  | 'dashboard'
  | 'products'
  | 'inventory'
  | 'orders'
  | 'customers'
  | 'reports'
  | 'settings'
  | 'plus'
  | 'search'
  | 'edit'
  | 'trash'
  | 'eye'
  | 'menu'
  | 'x'
  | 'logout'
  | 'upload'
  | 'image'
  | 'arrowLeft'
  | 'check'
  | 'alert'
  | 'refresh'
  | 'chevronRight'
  | 'shirt'
  | 'download'
  | 'filter'
  | 'lock'
  | 'user'
  | 'messages'
  | 'star'
  | 'bell'

interface IconProps extends SVGProps<SVGSVGElement> {
  name: IconName
  size?: number
}

export function Icon({ name, size = 20, ...props }: IconProps) {
  const common = {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.7,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    'aria-hidden': true,
    ...props,
  }

  switch (name) {
    case 'dashboard':
      return (
        <svg {...common}>
          <rect x="3" y="3" width="7" height="7" rx="1.5" />
          <rect x="14" y="3" width="7" height="7" rx="1.5" />
          <rect x="3" y="14" width="7" height="7" rx="1.5" />
          <rect x="14" y="14" width="7" height="7" rx="1.5" />
        </svg>
      )
    case 'products':
      return (
        <svg {...common}>
          <path d="m12 3 8 4.5v9L12 21l-8-4.5v-9L12 3Z" />
          <path d="m4.2 7.6 7.8 4.3 7.8-4.3M12 12v9" />
        </svg>
      )
    case 'inventory':
      return (
        <svg {...common}>
          <path d="m12 2 9 4.5-9 4.5-9-4.5L12 2Z" />
          <path d="m3 12 9 4.5 9-4.5M3 17l9 4.5 9-4.5" />
        </svg>
      )
    case 'orders':
      return (
        <svg {...common}>
          <path d="M6 2h12v20l-3-2-3 2-3-2-3 2V2Z" />
          <path d="M9 7h6M9 11h6M9 15h3" />
        </svg>
      )
    case 'customers':
      return (
        <svg {...common}>
          <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
          <circle cx="9" cy="7" r="4" />
          <path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
      )
    case 'reports':
      return (
        <svg {...common}>
          <path d="M3 3v18h18" />
          <path d="M7 15v3M12 10v8M17 6v12" />
        </svg>
      )
    case 'settings':
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="3" />
          <path d="M19.4 15a1.7 1.7 0 0 0 .34 1.87l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06A1.7 1.7 0 0 0 15 19.36a1.7 1.7 0 0 0-1 .64 1.7 1.7 0 0 0-.36 1.05V21a2 2 0 1 1-4 0v-.09A1.7 1.7 0 0 0 8.6 19.4a1.7 1.7 0 0 0-1.87.34l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.7 1.7 0 0 0 4.24 15a1.7 1.7 0 0 0-.64-1 1.7 1.7 0 0 0-1.05-.36H3a2 2 0 1 1 0-4h.09A1.7 1.7 0 0 0 4.6 8.6a1.7 1.7 0 0 0-.34-1.87l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.7 1.7 0 0 0 9 4.24a1.7 1.7 0 0 0 1-.64 1.7 1.7 0 0 0 .36-1.05V3a2 2 0 1 1 4 0v.09A1.7 1.7 0 0 0 15.4 4.6a1.7 1.7 0 0 0 1.87-.34l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.7 1.7 0 0 0 19.76 9c.12.37.35.7.64 1 .28.27.64.42 1.05.42H21a2 2 0 1 1 0 4h-.09a1.7 1.7 0 0 0-1.51.58Z" />
        </svg>
      )
    case 'plus':
      return (
        <svg {...common}>
          <path d="M12 5v14M5 12h14" />
        </svg>
      )
    case 'search':
      return (
        <svg {...common}>
          <circle cx="11" cy="11" r="7" />
          <path d="m20 20-3.5-3.5" />
        </svg>
      )
    case 'edit':
      return (
        <svg {...common}>
          <path d="M12 20h9" />
          <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5Z" />
        </svg>
      )
    case 'trash':
      return (
        <svg {...common}>
          <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v5M14 11v5" />
        </svg>
      )
    case 'eye':
      return (
        <svg {...common}>
          <path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z" />
          <circle cx="12" cy="12" r="2.5" />
        </svg>
      )
    case 'menu':
      return (
        <svg {...common}>
          <path d="M4 6h16M4 12h16M4 18h16" />
        </svg>
      )
    case 'x':
      return (
        <svg {...common}>
          <path d="m6 6 12 12M18 6 6 18" />
        </svg>
      )
    case 'logout':
      return (
        <svg {...common}>
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
        </svg>
      )
    case 'upload':
      return (
        <svg {...common}>
          <path d="M12 16V4M7 9l5-5 5 5" />
          <path d="M4 16v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3" />
        </svg>
      )
    case 'image':
      return (
        <svg {...common}>
          <rect x="3" y="3" width="18" height="18" rx="2" />
          <circle cx="8.5" cy="8.5" r="1.5" />
          <path d="m21 15-5-5L5 21" />
        </svg>
      )
    case 'arrowLeft':
      return (
        <svg {...common}>
          <path d="m15 18-6-6 6-6M9 12h12" />
        </svg>
      )
    case 'check':
      return (
        <svg {...common}>
          <path d="m5 12 4.5 4.5L19 7" />
        </svg>
      )
    case 'alert':
      return (
        <svg {...common}>
          <path d="M12 9v4M12 17h.01" />
          <path d="M10.3 3.9 2.8 17a2 2 0 0 0 1.7 3h15a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z" />
        </svg>
      )
    case 'refresh':
      return (
        <svg {...common}>
          <path d="M21 12a9 9 0 0 1-15.5 6.2L3 16M3 12a9 9 0 0 1 15.5-6.2L21 8" />
          <path d="M3 21v-5h5M21 3v5h-5" />
        </svg>
      )
    case 'chevronRight':
      return (
        <svg {...common}>
          <path d="m9 6 6 6-6 6" />
        </svg>
      )
    case 'shirt':
      return (
        <svg {...common}>
          <path d="M8 3 3 6l2 4 3-1v12h8V9l3 1 2-4-5-3a5 5 0 0 1-8 0Z" />
        </svg>
      )
    case 'download':
      return (
        <svg {...common}>
          <path d="M12 3v12M7 10l5 5 5-5" />
          <path d="M4 21h16" />
        </svg>
      )
    case 'filter':
      return (
        <svg {...common}>
          <path d="M3 5h18l-7 8v6l-4 2v-8L3 5Z" />
        </svg>
      )
    case 'lock':
      return (
        <svg {...common}>
          <rect x="4" y="10" width="16" height="11" rx="2" />
          <path d="M8 10V7a4 4 0 0 1 8 0v3" />
        </svg>
      )
    case 'user':
      return (
        <svg {...common}>
          <circle cx="12" cy="8" r="4" />
          <path d="M4 21v-2a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v2" />
        </svg>
      )
    case 'messages':
      return (
        <svg {...common}>
          <path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 9.3 9.3 0 0 1-3.8-.9L3 21l1.9-5a8.4 8.4 0 0 1-.9-3.8 8.4 8.4 0 0 1 8.4-8.4h.6a8.4 8.4 0 0 1 8 8v.7Z" />
          <path d="M8 11h8M8 15h5" />
        </svg>
      )
    case 'star':
      return (
        <svg {...common}>
          <path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3l-5.6 2.9 1.1-6.2L3 9.6l6.2-.9L12 3Z" />
        </svg>
      )
    case 'bell':
      return (
        <svg {...common}>
          <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9" />
          <path d="M13.7 21a2 2 0 0 1-3.4 0" />
        </svg>
      )
    default:
      return null
  }
}
