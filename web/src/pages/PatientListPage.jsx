import { useState, useEffect } from 'react'
import { FaTrash, FaEdit, FaSearch, FaChevronLeft, FaChevronRight } from 'react-icons/fa'
import { useNavigate } from 'react-router-dom'
import apiClient from '../api/axios'
import ReusableModal from '../components/common/Modal'
import LoadingSkeleton from '../components/common/loading'

export default function PatientListPage() {
  const [search, setSearch] = useState('')
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [currentPage, setCurrentPage] = useState(1)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })
  const [selectedUser, setSelectedUser] = useState(null)
  const navigate = useNavigate()
  const itemsPerPage = 8

  useEffect(() => { fetchUsers() }, [])

  const fetchUsers = async () => {
    setLoading(true)
    try {
      const { data } = await apiClient.get('/patients')
      setUsers(data)
    } catch {
      setModal({ isOpen: true, title: 'Error', message: 'Gagal memuat data pasien.', type: 'error' })
      setUsers([])
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async () => {
    if (!selectedUser) return
    try {
      await apiClient.delete(`/patients/${selectedUser.id}`)
      setModal({ isOpen: true, title: 'Berhasil', message: `Pasien "${selectedUser.name}" telah dihapus.`, type: 'success' })
      fetchUsers()
    } catch (err) {
      const msg = err.response?.status === 409
        ? 'Pasien masih memiliki data terkait. Hapus data pemeriksaan terlebih dahulu.'
        : 'Terjadi kesalahan saat menghapus pasien.'
      setModal({ isOpen: true, title: 'Gagal', message: msg, type: 'error' })
    } finally {
      setSelectedUser(null)
    }
  }

  const filtered = users.filter(u => u.name?.toLowerCase().includes(search.toLowerCase()))
  const totalPages = Math.ceil(filtered.length / itemsPerPage)
  const paginated = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage)

  return (
    <div>
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-6">
        <h1 className="text-2xl font-bold text-darkNavy">Data Pasien</h1>
        <button onClick={() => navigate('/admin/tambah-pasien')}
          className="px-4 py-2 bg-primaryBlue text-white rounded-lg hover:bg-blue-600 transition">
          + Tambah Pasien
        </button>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-6">
        <div className="relative mb-6">
          <FaSearch className="absolute left-3 top-3.5 text-gray-400" />
          <input type="text" placeholder="Cari berdasarkan nama..." value={search}
            onChange={e => { setSearch(e.target.value); setCurrentPage(1) }}
            className="w-full pl-10 pr-4 py-3 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
        </div>

        {loading ? <LoadingSkeleton rows={5} /> : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead>
                  <tr className="border-b border-lineGray text-sm text-textSecondary">
                    <th className="py-3 font-medium">Nama</th><th className="py-3 font-medium">Usia</th><th className="py-3 font-medium">BMI</th>
                    <th className="py-3 font-medium">Risiko Diabetes</th><th className="py-3 font-medium">Aksi</th>
                  </tr>
                </thead>
                <tbody>
                  {paginated.map(user => (
                    <tr key={user.id} className="border-b border-lineGray hover:bg-blue-50/30 transition">
                      <td className="py-3 font-medium">{user.name}</td>
                      <td className="py-3 text-sm">{user.age} th</td>
                      <td className="py-3 text-sm">{user.bmi}</td>
                      <td className="py-3">
                        <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${
                          user.risk_level === 'high' ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'
                        }`}>
                          {user.risk_level === 'high' ? 'Tinggi' : 'Rendah'}
                        </span>
                      </td>
                      <td className="py-3">
                        <div className="flex gap-2">
                          <button onClick={() => navigate(`/admin/edit-pasien/${user.id}`)}
                            className="p-2 text-primaryBlue hover:bg-blue-50 rounded-lg transition"><FaEdit /></button>
                          <button onClick={() => {
                            setSelectedUser(user)
                            setModal({
                              isOpen: true, title: 'Konfirmasi Hapus',
                              message: `Apakah Anda yakin ingin menghapus pasien "${user.name}"?`,
                              type: 'confirm'
                            })
                          }} className="p-2 text-red-500 hover:bg-red-50 rounded-lg transition"><FaTrash /></button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {paginated.length === 0 && (
                    <tr><td colSpan={5} className="py-12 text-center text-gray-400">Tidak ada data pasien.</td></tr>
                  )}
                </tbody>
              </table>
            </div>

            {totalPages > 1 && (
              <div className="flex justify-between items-center mt-6">
                <p className="text-sm text-textSecondary">Halaman {currentPage} dari {totalPages} ({filtered.length} pasien)</p>
                <div className="flex gap-2">
                  <button onClick={() => setCurrentPage(p => Math.max(1, p - 1))} disabled={currentPage === 1}
                    className="p-2 rounded-lg border border-lineGray disabled:opacity-30 hover:bg-gray-50"><FaChevronLeft /></button>
                  {Array.from({ length: totalPages }, (_, i) => (
                    <button key={i} onClick={() => setCurrentPage(i + 1)}
                      className={`w-10 h-10 rounded-lg text-sm font-medium ${
                        currentPage === i + 1 ? 'bg-primaryBlue text-white' : 'border border-lineGray hover:bg-gray-50'
                      }`}>{i + 1}</button>
                  ))}
                  <button onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))} disabled={currentPage === totalPages}
                    className="p-2 rounded-lg border border-lineGray disabled:opacity-30 hover:bg-gray-50"><FaChevronRight /></button>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      <ReusableModal isOpen={modal.isOpen} onClose={() => setModal({ ...modal, isOpen: false })}
        onConfirm={modal.type === 'confirm' ? handleDelete : undefined}
        title={modal.title} message={modal.message} type={modal.type} />
    </div>
  )
}