import { useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom'
import LoginPage from './pages/loginPage'
import ProtectedRoute from './components/protectedRoute'
import AdminLayout from './components/common/AdminLayout'
import DashboardPage from './pages/Dashboard'
import RealtimeMonitorPage from './pages/monitoring/RealtimeMonitoring'
import PatientListPage from './pages/PatientListPage'
import TambahPasien from './pages/tambahPasien'
import EditPasien from './pages/EditPasien'
import PatientDetailPage from './pages/patientDetail'
import NotificationPage from './pages/NotificationPage'
import FAQManagePage from './pages/FAQManagement'
import SettingsPage from './pages/Settings'
import NotFound from './pages/NotFound'

function TitleUpdater() {
  const location = useLocation()

  useEffect(() => {
    const titles = {
      '/admin/dashboard': 'Dashboard - GlucoBand',
      '/admin/monitoring': 'Monitoring - GlucoBand',
      '/admin/data-pasien': 'Data Pasien - GlucoBand',
      '/admin/notifications': 'Notifikasi - GlucoBand',
      '/admin/faq': 'FAQ - GlucoBand',
      '/admin/settings': 'Pengaturan - GlucoBand',
      '/admin/tambah-pasien': 'Tambah Pasien - GlucoBand',
      '/login': 'Login - GlucoBand',
    }

    if (location.pathname.startsWith('/admin/edit-pasien')) {
      document.title = 'Edit Pasien - GlucoBand'
    } else if (location.pathname.startsWith('/admin/detail-pasien')) {
      document.title = 'Detail Pasien - GlucoBand'
    } else {
      document.title = titles[location.pathname] || 'GlucoBand'
    }
  }, [location])

  return null
}

export default function App() {
  return (
    <BrowserRouter>
      <TitleUpdater />
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
            <Route path="/admin/settings" element={<SettingsPage />} />
          </Route>
        </Route>
        <Route path="/" element={<Navigate to="/admin/dashboard" replace />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  )
}