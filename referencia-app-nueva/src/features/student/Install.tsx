import { useEffect, useState } from 'react'
import { Screen } from '../../components/Layout'
import { BackButton, Btn, Card, Eyebrow, Title } from '../../components/ui'
import { IconPlusSquare, IconShare } from '../../components/icons'

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
}

function platform(): 'ios' | 'android' | 'other' {
  const ua = navigator.userAgent
  if (/iPhone|iPad|iPod/.test(ua) || (ua.includes('Mac') && 'ontouchend' in document)) return 'ios'
  if (/Android/.test(ua)) return 'android'
  return 'other'
}

/** Guía de instalación de la PWA según la plataforma */
export function Install() {
  const [deferred, setDeferred] = useState<BeforeInstallPromptEvent | null>(null)
  const p = platform()
  const installed = window.matchMedia?.('(display-mode: standalone)').matches

  useEffect(() => {
    const h = (e: Event) => {
      e.preventDefault()
      setDeferred(e as BeforeInstallPromptEvent)
    }
    window.addEventListener('beforeinstallprompt', h)
    return () => window.removeEventListener('beforeinstallprompt', h)
  }, [])

  return (
    <Screen gap={16}>
      <div className="flex items-center gap-3">
        <BackButton label="Volver al perfil" to="/perfil" />
        <Title size={40}>Instalar</Title>
      </div>
      {installed ? (
        <Card radius={24} className="gap-2 p-5">
          <span className="text-[17px] font-bold">La app ya está instalada</span>
          <p className="m-0 text-[14px] text-muted">La estás usando desde la pantalla de inicio.</p>
        </Card>
      ) : (
        <>
          <p className="m-0 text-[15px] text-ink-2">
            ITACA funciona como una app: se añade a la pantalla de inicio, se abre a pantalla completa y no necesita tienda.
          </p>
          {(p === 'ios' || p === 'other') && (
            <Card radius={24} className="gap-4 p-5">
              <Eyebrow>iPhone y iPad (Safari)</Eyebrow>
              <Step n={1}>
                Abre esta página en <b>Safari</b>.
              </Step>
              <Step n={2}>
                Toca <IconShare size={18} className="inline align-[-3px]" /> <b>Compartir</b>.
              </Step>
              <Step n={3}>
                Elige <IconPlusSquare size={18} className="inline align-[-3px]" /> <b>Añadir a pantalla de inicio</b>.
              </Step>
              <p className="m-0 text-[13px] text-muted">Los avisos en iPhone solo llegan con la app ya instalada.</p>
            </Card>
          )}
          {(p === 'android' || p === 'other') && (
            <Card radius={24} className="gap-4 p-5">
              <Eyebrow>Android (Chrome)</Eyebrow>
              {deferred ? (
                <Btn variant="accent" size="lg" block onClick={() => deferred.prompt()}>
                  Instalar app
                </Btn>
              ) : (
                <>
                  <Step n={1}>Abre el menú ⋮ de Chrome.</Step>
                  <Step n={2}>
                    Toca <b>Instalar app</b> o <b>Añadir a pantalla de inicio</b>.
                  </Step>
                </>
              )}
            </Card>
          )}
        </>
      )}
    </Screen>
  )
}

function Step({ n, children }: { n: number; children: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3">
      <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-ink font-display text-[18px] font-extrabold text-on-ink">{n}</span>
      <span className="pt-1 text-[15px]">{children}</span>
    </div>
  )
}
