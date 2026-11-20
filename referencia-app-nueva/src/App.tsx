import { Navigate, Route, Routes } from 'react-router'
import { BareLayout, StaffLayout, StudentLayout } from './components/Layout'
import { ForgotPassword, Login, RequireAuth, ResetPassword, Signup } from './features/auth/Login'
import { AccountSettings } from './features/student/AccountSettings'
import { ItacaHome } from './features/itaca/ItacaHome'
import { ItacaVideo } from './features/itaca/ItacaVideo'
import { CoachDetail } from './features/staff/CoachDetail'
import { Coaches } from './features/staff/Coaches'
import { ScheduleEditor } from './features/staff/ScheduleEditor'
import { Kiosk } from './features/staff/Kiosk'
import { Members } from './features/staff/Members'
import { More } from './features/staff/More'
import { Tariffs } from './features/staff/Tariffs'
import { RollCall } from './features/staff/RollCall'
import { ClassDetail } from './features/student/ClassDetail'
import { Install } from './features/student/Install'
import { Plans } from './features/student/Plans'
import { MyBookings } from './features/student/MyBookings'
import { EditProfile } from './features/student/EditProfile'
import { Profile } from './features/student/Profile'
import { Progress } from './features/student/Progress'
import { Schedule } from './features/student/Schedule'
import { Home } from './features/student/Home'
import { News } from './features/student/News'
import { AppSettings } from './features/student/AppSettings'
import { BillingSettings, Documents, EmergencyContact, FamilyProfiles, MinorProfile, Promotions, Support } from './features/student/ProfileMenu'

export function App() {
  return (
    <Routes>
      <Route path="entrar" element={<Login />} />
      <Route path="registro" element={<Signup />} />
      <Route path="recuperar" element={<ForgotPassword />} />
      <Route path="restablecer" element={<ResetPassword />} />
      <Route element={<RequireAuth><StudentLayout /></RequireAuth>}>
        <Route index element={<Home />} />
        <Route path="horario" element={<Navigate to="/" replace />} />
        <Route path="itaca" element={<ItacaHome />} />
        <Route path="estadisticas" element={<Progress />} />
        <Route path="progreso" element={<Navigate to="/estadisticas" replace />} />
        <Route path="novedades" element={<News />} />
        <Route path="ajustes" element={<AppSettings />} />
        <Route path="cuenta" element={<AccountSettings />} />
        <Route path="perfil" element={<Profile />} />
        <Route path="perfil/editar" element={<EditProfile />} />
        <Route path="perfil/perfiles" element={<FamilyProfiles />} />
        <Route path="perfil/perfiles/:id" element={<MinorProfile />} />
        <Route path="perfil/promociones" element={<Promotions />} />
        <Route path="perfil/emergencia" element={<EmergencyContact />} />
        <Route path="perfil/facturacion" element={<BillingSettings />} />
        <Route path="perfil/soporte" element={<Support />} />
        <Route path="documentos" element={<Documents />} />
        <Route path="tarifas" element={<Plans />} />
        <Route path="reservas" element={<MyBookings />} />
        <Route path="instalar" element={<Install />} />
      </Route>
      <Route element={<RequireAuth><BareLayout /></RequireAuth>}>
        <Route path="clase/:id" element={<ClassDetail />} />
        <Route path="itaca/video/:id" element={<ItacaVideo />} />
      </Route>
      <Route element={<RequireAuth staff><BareLayout /></RequireAuth>}>
        <Route path="staff/monitores/:id" element={<CoachDetail />} />
        <Route path="staff/horario/editor" element={<ScheduleEditor />} />
        <Route path="staff/kiosco" element={<Kiosk />} />
      </Route>
      <Route path="staff" element={<RequireAuth staff><StaffLayout /></RequireAuth>}>
        <Route index element={<RollCall />} />
        <Route path="alumnos" element={<Members />} />
        <Route path="horario" element={<Schedule staff />} />
        <Route path="tarifas" element={<Tariffs />} />
        <Route path="cobros" element={<Navigate to="/staff/tarifas?vista=ingresos" replace />} />
        <Route path="mas" element={<More />} />
        <Route path="monitores" element={<Coaches />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
