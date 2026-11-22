import { useState, useEffect } from 'react'
import { Outlet } from 'react-router-dom'
import { FaBars } from 'react-icons/fa'
import Sidebar from './Sidebar'

export default function AdminLayout() {
  const [isCollapsed, setIsCollapsed] = useState(() => {
    const saved = localStorage.getItem('glucoband_sidebar_collapsed')
    if (saved !== null) {
      return saved === 'true'
    }
    return typeof window !== 'undefined' ? window.innerWidth < 1024 : false
  })

  const [isMobileOpen, setIsMobileOpen] = useState(false)

  const handleToggleCollapse = () => {
    setIsCollapsed((prev) => {
      const next = !prev
      localStorage.setItem('glucoband_sidebar_collapsed', String(next))
      return next
    })
  }

  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth < 768) {
        setIsMobileOpen(false)
      }
    }
    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  return (
    <div className="flex h-screen overflow-hidden bg-slate-50 relative">
      {/* Tombol Hamburger Khusus Mobile (Hanya tampil di layar HP < 768px) */}
      <button
        type="button"
        onClick={() => setIsMobileOpen(true)}
        className="md:hidden fixed top-3 left-3 z-30 p-2.5 bg-white/90 backdrop-blur-xs text-slate-700 hover:text-slate-900 hover:bg-white rounded-xl shadow-md border border-slate-200 transition"
        title="Buka Menu Navigasi"
      >
        <FaBars size={16} />
      </button>

      {/* Komponen Sidebar Retractable / Collapsible */}
      <Sidebar
        isCollapsed={isCollapsed}
        onToggleCollapse={handleToggleCollapse}
        isMobileOpen={isMobileOpen}
        onCloseMobile={() => setIsMobileOpen(false)}
      />

      {/* Konten Utama Halaman (Langsung penuh dari atas tanpa header bar) */}
      <main className="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8 bg-slate-50 min-w-0">
        <Outlet />
      </main>
    </div>
  )
}
