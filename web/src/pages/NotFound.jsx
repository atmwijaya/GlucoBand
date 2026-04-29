import { Link } from 'react-router-dom'
import { FaHome } from 'react-icons/fa'

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-slate-50 text-center p-8">
      <h1 className="text-8xl font-bold text-primaryBlue/20 mb-4">404</h1>
      <h2 className="text-2xl font-bold text-darkNavy mb-2">Halaman Tidak Ditemukan</h2>
      <p className="text-textSecondary mb-6">Halaman yang Anda cari tidak tersedia.</p>
      <Link to="/admin/dashboard" className="flex items-center gap-2 px-6 py-3 bg-primaryBlue text-white rounded-lg hover:bg-blue-600 transition">
        <FaHome /> Kembali ke Dashboard
      </Link>
    </div>
  )
}