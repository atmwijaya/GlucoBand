import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { FaSignOutAlt } from 'react-icons/fa'
import ReusableModal from './Modal'

export default function Navbar() {
  const user = JSON.parse(sessionStorage.getItem('user')) || { name: 'Tenaga Medis' }
  const navigate = useNavigate()
  const [showLogoutModal, setShowLogoutModal] = useState(false)

  const handleLogout = () => {
    sessionStorage.clear()
    navigate('/login', { replace: true })
  }

  return (
    <>
      <header className="bg-white shadow-sm px-6 py-3 flex justify-between items-center">
        <h1 className="text-xl font-bold text-primaryDark">GlucoBand Medic</h1>
        <div className="flex items-center gap-4">
          <span className="text-sm text-textSecondary">{user.name || user.email}</span>
          <button
            onClick={() => setShowLogoutModal(true)}
            className="flex items-center gap-1 text-sm text-red-500 hover:text-red-700 transition"
          >
            <FaSignOutAlt /> Keluar
          </button>
        </div>
      </header>

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