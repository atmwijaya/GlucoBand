import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import LoginPage from './pages/loginPage'
import ProtectedRoute from './components/protectedRoute'
import AdminLayout from './components/common/AdminLayout'
import DashboardPage from './pages/Dashboard'
import RealtimeMonitorPage from './pages/monitoring/RealtimeMonitoring'
import PatientListPage from './pages/PatientListPage'
import TambahPasien from './pages/tambahPasien'
import EditPasien from './pages/EditPasien'
import PatientDetailPage from './pages/PatientDetail'
import NotificationPage from './pages/NotificationPage'
import FAQManagePage from './pages/FAQManagement'
import NotFound from './pages/NotFound'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<ProtectedRoute allowedRoles={['tenaga_medis']} />}>
          <Route element={<AdminLayout />}>
            <Route path="/admin/dashboard" element={<DashboardPage />} />
            <Route path="/admin/monitoring" element={<RealtimeMonitorPage />} />
            <Route path="/admin/data-pasien" element={<PatientListPage />} />
            <Route path="/admin/tambah-pasien" element={<TambahPasien />} />
            <Route path="/admin/edit-pasien/:id" element={<EditPasien />} />
            <Route path="/admin/detail-pasien/:id" element={<PatientDetailPage />} />
            <Route path="/admin/notifications" element={<NotificationPage />} />
            <Route path="/admin/faq" element={<FAQManagePage />} />
          </Route>
        </Route>
        <Route path="/" element={<Navigate to="/admin/dashboard" replace />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  )
}