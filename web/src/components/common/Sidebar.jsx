import { useState } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import {
  FaHome, FaHeartbeat, FaUser, FaClipboardList,
  FaQuestionCircle, FaSignOutAlt, FaCog, FaUserMd,
  FaChevronLeft, FaChevronRight, FaTimes
} from 'react-icons/fa'
import ReusableModal from './modal'
import logoImg from '../../assets/android-chrome-192x192.png'

const menuItems = [
  { to: '/admin/dashboard', icon: FaHome, text: 'Dashboard' },
  { to: '/admin/monitoring', icon: FaHeartbeat, text: 'Monitoring' },
  { to: '/admin/data-pasien', icon: FaUser, text: 'Data Pasien' },
  { to: '/admin/tenaga-medis', icon: FaUserMd, text: 'Tenaga Medis' },
  { to: '/admin/notifications', icon: FaClipboardList, text: 'Notifikasi' },
  { to: '/admin/faq', icon: FaQuestionCircle, text: 'FAQ' },
  { to: '/admin/settings', icon: FaCog, text: 'Pengaturan' },
]

export default function Sidebar({
  isCollapsed = false,
  onToggleCollapse,
  isMobileOpen = false,
  onCloseMobile,
}) {
  const navigate = useNavigate()
  const [showLogoutModal, setShowLogoutModal] = useState(false)

  const handleLogout = () => {
    sessionStorage.clear()
    navigate('/login', { replace: true })
  }

  const handleItemClick = () => {
    if (onCloseMobile) {
      onCloseMobile()
    }
  }

  return (
    <>
      {/* Backdrop Gelap untuk Mobile Drawer */}
      {isMobileOpen && (
        <div
          onClick={onCloseMobile}
          className="fixed inset-0 bg-slate-950/60 backdrop-blur-xs z-40 md:hidden transition-opacity duration-300"
          aria-hidden="true"
        />
      )}

      {/* Sidebar Container */}
      <aside
        className={`bg-[#0F172A] text-white flex flex-col flex-shrink-0 z-40 transition-all duration-300 ease-in-out relative
          fixed inset-y-0 left-0 md:static
          ${isMobileOpen ? 'translate-x-0 shadow-2xl' : '-translate-x-full md:translate-x-0'}
          ${isCollapsed ? 'md:w-20 w-64' : 'w-64'}
        `}
      >
        {/* Tombol Floating Expand / Collapse di garis batas kanan (Desktop & Tablet) */}
        {onToggleCollapse && (
          <button
            type="button"
            onClick={onToggleCollapse}
            title={isCollapsed ? 'Buka Sidebar (Lebarkan)' : 'Geser Sidebar ke Kiri (Hemat Tempat)'}
            className="hidden md:flex absolute -right-3.5 top-6 z-50 w-7 h-7 rounded-full bg-[#1E293B] border border-slate-600 text-slate-300 hover:text-white hover:bg-primaryBlue shadow-lg items-center justify-center transition-transform duration-200 hover:scale-110 cursor-pointer focus:outline-none"
          >
            {isCollapsed ? <FaChevronRight size={10} /> : <FaChevronLeft size={10} />}
          </button>
        )}

        {/* Header / Logo */}
        <div className="flex items-center justify-between px-4 py-5 border-b border-[#334155] min-h-[73px]">
          <div
            onClick={() => {
              navigate('/admin/dashboard')
              handleItemClick()
            }}
            className={`flex items-center gap-3 cursor-pointer overflow-hidden transition-all duration-300 ${
              isCollapsed ? 'justify-center w-full' : ''
            }`}
            title="GlucoBand Medic Portal"
          >
            <div className="w-9 h-9 rounded-lg bg-white p-1 flex items-center justify-center shadow-sm flex-shrink-0">
              <img src={logoImg} alt="GlucoBand Logo" className="w-full h-full object-contain" />
            </div>

            {/* Nama Portal (Sembunyi saat Collapsed) */}
            <div
              className={`transition-all duration-300 whitespace-nowrap overflow-hidden ${
                isCollapsed ? 'opacity-0 w-0 pointer-events-none' : 'opacity-100 w-auto'
              }`}
            >
              <h1 className="text-lg font-bold tracking-tight text-white leading-none">GlucoBand</h1>
              <span className="text-[10px] text-slate-400 font-medium tracking-wider uppercase">Medic Portal</span>
            </div>
          </div>

          {/* Tombol Close X khusus Mobile Drawer */}
          <button
            type="button"
            onClick={onCloseMobile}
            className="md:hidden text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-[#1E293B] transition"
            title="Tutup Menu"
          >
            <FaTimes size={16} />
          </button>
        </div>

        {/* Navigation Links */}
        <nav className="flex-1 p-3 space-y-1.5 overflow-y-auto sidebar-scroll">
          {menuItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              onClick={handleItemClick}
              className={({ isActive }) =>
                `group relative rounded-xl font-medium transition-all duration-200 flex items-center ${
                  isCollapsed ? 'justify-center p-3' : 'px-3.5 py-2.5 gap-3.5 text-sm'
                } ${
                  isActive
                    ? 'bg-primaryBlue text-white shadow-md shadow-primaryBlue/30'
                    : 'text-slate-300 hover:bg-[#1E293B] hover:text-white'
                }`
              }
            >
              {({ isActive }) => (
                <>
                  <item.icon className={`flex-shrink-0 ${isCollapsed ? 'text-xl' : 'text-lg'}`} />

                  {/* Teks Menu */}
                  <span
                    className={`transition-all duration-200 whitespace-nowrap overflow-hidden ${
                      isCollapsed ? 'opacity-0 w-0 pointer-events-none hidden' : 'opacity-100'
                    }`}
                  >
                    {item.text}
                  </span>

                  {/* Floating Tooltip saat Collapsed (Hover di iPad/Desktop) */}
                  {isCollapsed && (
                    <div className="absolute left-full ml-3 px-3 py-1.5 bg-[#0F172A] text-white text-xs font-semibold rounded-lg shadow-2xl whitespace-nowrap opacity-0 pointer-events-none group-hover:opacity-100 transition-all duration-200 z-50 border border-slate-700 flex items-center gap-2">
                      <span>{item.text}</span>
                      {isActive && <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />}
                    </div>
                  )}
                </>
              )}
            </NavLink>
          ))}
        </nav>

        {/* Footer dengan Tombol Logout */}
        <div className="p-3 border-t border-[#334155] space-y-2">
          <button
            type="button"
            onClick={() => setShowLogoutModal(true)}
            title={isCollapsed ? 'Keluar' : undefined}
            className={`group relative rounded-xl text-slate-300 hover:text-red-400 hover:bg-[#1E293B] transition-all duration-200 w-full flex items-center cursor-pointer ${
              isCollapsed ? 'justify-center p-3' : 'px-3.5 py-2.5 gap-3 text-sm'
            }`}
          >
            <FaSignOutAlt className={`flex-shrink-0 ${isCollapsed ? 'text-xl' : 'text-base'}`} />

            <span
              className={`transition-all duration-200 whitespace-nowrap overflow-hidden ${
                isCollapsed ? 'opacity-0 w-0 pointer-events-none hidden' : 'opacity-100'
              }`}
            >
              Keluar
            </span>

            {/* Tooltip Logout saat Collapsed */}
            {isCollapsed && (
              <div className="absolute left-full ml-3 px-3 py-1.5 bg-red-950/90 text-red-200 text-xs font-semibold rounded-lg shadow-2xl whitespace-nowrap opacity-0 pointer-events-none group-hover:opacity-100 transition-all duration-200 z-50 border border-red-800">
                Keluar
              </div>
            )}
          </button>

          {/* Copyright Ringkas */}
          <div
            className={`text-center text-slate-500 text-[10px] overflow-hidden transition-all duration-300 ${
              isCollapsed ? 'hidden' : 'block'
            }`}
          >
            © 2026 GlucoBand v1.0
          </div>
        </div>
      </aside>

      {/* Modal Konfirmasi Logout */}
      <ReusableModal
        isOpen={showLogoutModal}
        onClose={() => setShowLogoutModal(false)}
        onConfirm={handleLogout}
        title="Konfirmasi Logout"
        message="Apakah Anda yakin ingin keluar dari dashboard?"
        type="confirm"
      />
    </>
  )
}
