import { useState, useEffect } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import { FaBars, FaChevronLeft, FaChevronRight, FaUserMd } from 'react-icons/fa'
import Sidebar from './Sidebar'

const pageTitles = {
  '/admin/dashboard': 'Dashboard Utama',
  '/admin/monitoring': 'Monitoring Glukosa Realtime',
  '/admin/data-pasien': 'Daftar Data Pasien',
  '/admin/tenaga-medis': 'Daftar Tenaga Medis',
  '/admin/tambah-pasien': 'Registrasi Pasien Baru',
  '/admin/notifications': 'Pusat Notifikasi & Alert Medis',
  '/admin/faq': 'Manajemen FAQ Medis',
  '/admin/settings': 'Pengaturan Sistem & APK',
}

export default function AdminLayout() {
  const location = useLocation()
  const user = JSON.parse(sessionStorage.getItem('user')) || { name: 'Tenaga Medis' }

  // Deteksi awal: Jika layar < 1024px (iPad / Tablet), default langsung Collapsed agar hemat tempat
  const [isCollapsed, setIsCollapsed] = useState(() => {
    const saved = localStorage.getItem('glucoband_sidebar_collapsed')
    if (saved !== null) {
      return saved === 'true'
    }
    return typeof window !== 'undefined' ? window.innerWidth < 1024 : false
  })

  const [isMobileOpen, setIsMobileOpen] = useState(false)

  // Simpan preferensi collapse ke localStorage saat diubah pengguna
  const handleToggleCollapse = () => {
    setIsCollapsed((prev) => {
      const next = !prev
      localStorage.setItem('glucoband_sidebar_collapsed', String(next))
      return next
    })
  }

  // Auto-adaptasi breakpoint saat resize orientasi layar (misal iPad rotasi portrait/landscape)
  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth < 768) {
        setIsMobileOpen(false)
      }
    }
    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  // Cari judul halaman aktif
  let currentTitle = pageTitles[location.pathname] || 'Portal Medis'
  if (location.pathname.startsWith('/admin/edit-pasien')) {
    currentTitle = 'Edit Data Pasien'
  } else if (location.pathname.startsWith('/admin/detail-pasien')) {
    currentTitle = 'Detail Riwayat Pasien'
  }

  return (
    <div className="flex h-screen overflow-hidden bg-slate-50 relative">
      {/* Komponen Sidebar Retractable / Collapsible */}
      <Sidebar
        isCollapsed={isCollapsed}
        onToggleCollapse={handleToggleCollapse}
        isMobileOpen={isMobileOpen}
        onCloseMobile={() => setIsMobileOpen(false)}
      />

      {/* Konten Utama */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Top Header Bar Responsif (Memudahkan Kontrol Sidebar di iPad, Tablet & Mobile) */}
        <header className="h-16 bg-white border-b border-slate-200/90 px-4 sm:px-6 flex items-center justify-between flex-shrink-0 z-10 shadow-xs">
          {/* Sisi Kiri: Tombol Toggle Sidebar & Judul Halaman */}
          <div className="flex items-center gap-3">
            {/* Tombol Toggle Khusus Mobile (< 768px) */}
            <button
              type="button"
              onClick={() => setIsMobileOpen(true)}
              className="md:hidden p-2 text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition"
              title="Buka Menu Navigasi"
            >
              <FaBars size={18} />
            </button>

            {/* Tombol Toggle Expand / Geser ke Kiri untuk Tablet & Desktop */}
            <button
              type="button"
              onClick={handleToggleCollapse}
              className="hidden md:flex items-center gap-1.5 p-2 text-slate-600 hover:text-primaryBlue hover:bg-slate-100 rounded-lg transition text-xs font-semibold"
              title={isCollapsed ? 'Perluas Sidebar' : 'Geser Sidebar ke Kiri (Hemat Tempat)'}
            >
              {isCollapsed ? (
                <>
                  <FaChevronRight size={13} className="text-primaryBlue" />
                  <span className="hidden lg:inline text-slate-500">Buka Menu</span>
                </>
              ) : (
                <>
                  <FaChevronLeft size={13} className="text-slate-500" />
                  <span className="hidden lg:inline text-slate-500">Ciutkan</span>
                </>
              )}
            </button>

            {/* Divider vertikal halus */}
            <div className="hidden md:block h-5 w-[1px] bg-slate-200" />

            {/* Judul Halaman Aktif */}
            <div className="flex items-center gap-2">
              <h2 className="text-base sm:text-lg font-bold text-slate-800 tracking-tight truncate">
                {currentTitle}
              </h2>
            </div>
          </div>

          {/* Sisi Kanan: Status Monitoring & Profil Tenaga Medis */}
          <div className="flex items-center gap-3 sm:gap-4">
            {/* Indikator Status Server */}
            <div className="hidden sm:flex items-center gap-2 px-2.5 py-1 bg-emerald-50 border border-emerald-200 rounded-full">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              <span className="text-[11px] font-bold text-emerald-700 uppercase tracking-wide">Live Medic</span>
            </div>

            {/* Profil Singkat Nakes */}
            <div className="flex items-center gap-2.5 pl-2 sm:border-l sm:border-slate-200">
              <div className="w-8 h-8 rounded-full bg-primaryBlue/10 border border-primaryBlue/20 text-primaryBlue flex items-center justify-center font-bold text-sm">
                <FaUserMd size={15} />
              </div>
              <div className="hidden sm:block text-left">
                <p className="text-xs font-bold text-slate-800 leading-tight truncate max-w-[140px]">
                  {user.name || 'Tenaga Medis'}
                </p>
                <p className="text-[10px] text-slate-500 font-medium">Petugas Medis</p>
              </div>
            </div>
          </div>
        </header>

        {/* Konten Utama Halaman (Otomatis Melebar Penuh saat Sidebar Collapsed) */}
        <main className="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8 bg-slate-50">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
