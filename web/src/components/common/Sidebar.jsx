import { useState } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import {
  FaHome, FaHeartbeat, FaUser, FaClipboardList,
  FaQuestionCircle, FaSignOutAlt
} from 'react-icons/fa'
import ReusableModal from './Modal'

const menuItems = [
  { to: '/admin/dashboard', icon: FaHome, text: 'Dashboard' },
  { to: '/admin/monitoring', icon: FaHeartbeat, text: 'Monitoring' },
  { to: '/admin/data-pasien', icon: FaUser, text: 'Data Pasien' },
  { to: '/admin/notifications', icon: FaClipboardList, text: 'Notifikasi' },
  { to: '/admin/faq', icon: FaQuestionCircle, text: 'FAQ' },
]

export default function Sidebar() {
  const navigate = useNavigate()
  const [showLogoutModal, setShowLogoutModal] = useState(false)

  const handleLogout = () => {
    sessionStorage.clear()
    navigate('/login', { replace: true })
  }

  return (
    <>
      <aside className="w-64 bg-[#0F172A] text-white flex flex-col flex-shrink-0">
        {/* Logo */}
        <div
          onClick={() => navigate('/admin/dashboard')}
          className="flex items-center gap-3 px-6 py-5 border-b border-[#334155] cursor-pointer hover:bg-[#1E293B] transition"
        >
          <img src="/icons/icon-192x192.png" alt="Logo" className="w-8 h-8 rounded" />
          <h1 className="text-lg font-bold tracking-tight text-white">GlucoBand</h1>
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-4 space-y-1 overflow-y-auto sidebar-scroll">
          {menuItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition ${
                  isActive
                    ? 'bg-primaryBlue text-white shadow-md shadow-primaryBlue/30'
                    : 'text-white hover:bg-[#1E293B] hover:text-white'
                }`
              }
            >
              <item.icon className="text-lg" />
              {item.text}
            </NavLink>
          ))}
        </nav>

        {/* Footer dengan tombol Logout */}
        <div className="px-4 py-3 border-t border-[#334155] space-y-3">
          <button
            onClick={() => setShowLogoutModal(true)}
            className="flex items-center gap-2 w-full text-sm text-slate-300 hover:text-red-400 transition"
          >
            <FaSignOutAlt className="text-base" />
            Keluar
          </button>
          <p className="text-xs text-slate-500">© 2026 GlucoBand v1.0</p>
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