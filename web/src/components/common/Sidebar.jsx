import { NavLink, useNavigate } from 'react-router-dom'
import {
  FaHome, FaHeartbeat, FaUser, FaClipboardList, FaQuestionCircle, FaCog
} from 'react-icons/fa'

const menuItems = [
  { to: '/admin/dashboard', icon: FaHome, text: 'Dashboard' },
  { to: '/admin/monitoring', icon: FaHeartbeat, text: 'Monitoring' },
  { to: '/admin/data-pasien', icon: FaUser, text: 'Data Pasien' },
  { to: '/admin/notifications', icon: FaClipboardList, text: 'Notifikasi' },
  { to: '/admin/faq', icon: FaQuestionCircle, text: 'FAQ' },
  { to: '/admin/setting', icon: FaCog, text: 'Setting' },
]

export default function Sidebar() {
  const navigate = useNavigate()

  return (
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

      {/* Footer */}
      <div className="px-4 py-3 border-t border-[#334155] text-xs text-slate-400">
        © 2026 GlucoBand v1.0
      </div>
    </aside>
  )
}