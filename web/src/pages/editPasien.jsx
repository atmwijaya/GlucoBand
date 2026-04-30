import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import apiClient from '../api/axios'
import ReusableModal from '../components/common/Modal'

export default function EditPasien() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [form, setForm] = useState({
    name: '', email: '', age: '', gender: 'L', weight_kg: '', height_cm: '',
    blood_pressure_sys: '', blood_pressure_dia: '', diabetes_history: 0, smoking_history: 0
  })
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [fetchLoading, setFetchLoading] = useState(true)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })

  useEffect(() => {
    apiClient.get(`/patients/${id}`)
      .then(({ data }) => setForm({
        name: data.name, email: data.email, age: data.age, gender: data.gender || 'L',
        weight_kg: data.weight_kg, height_cm: data.height_cm,
        blood_pressure_sys: data.blood_pressure_sys, blood_pressure_dia: data.blood_pressure_dia,
        diabetes_history: data.diabetes_history, smoking_history: data.smoking_history
      }))
      .catch(() => setModal({ isOpen: true, title: 'Error', message: 'Gagal memuat data pasien.', type: 'error' }))
      .finally(() => setFetchLoading(false))
  }, [id])

  const handleChange = (e) => {
    const { name, value, type: inputType, checked } = e.target
    setForm(prev => ({ ...prev, [name]: inputType === 'checkbox' ? (checked ? 1 : 0) : value }))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (password && password !== confirmPassword) {
      setModal({ isOpen: true, title: 'Error', message: 'Password dan konfirmasi tidak cocok.', type: 'error' })
      return
    }

    setLoading(true)
    try {
      // Kirim password hanya jika diisi
      const payload = { ...form }
      if (password) {
        payload.password = password
      }
      await apiClient.put(`/patients/${id}`, payload)
      setModal({ isOpen: true, title: 'Berhasil', message: 'Data pasien berhasil diperbarui.', type: 'success' })
    } catch {
      setModal({ isOpen: true, title: 'Gagal', message: 'Terjadi kesalahan saat memperbarui data.', type: 'error' })
    } finally { setLoading(false) }
  }

  if (fetchLoading) return <div className="text-center py-12 text-gray-400">Memuat data...</div>

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-darkNavy mb-6">Edit Data Pasien</h1>
      <form onSubmit={handleSubmit} className="bg-white rounded-xl shadow-sm p-6 space-y-5">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {/* Nama */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Nama Lengkap</label>
            <input name="name" value={form.name} onChange={handleChange} required
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          {/* Email */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Email</label>
            <input type="email" name="email" value={form.email} onChange={handleChange} required
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          {/* Password Baru */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Password Baru (kosongkan jika tidak diubah)</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          {/* Konfirmasi Password */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Konfirmasi Password</label>
            <input type="password" value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          {/* Usia */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Usia</label>
            <input type="number" name="age" value={form.age} onChange={handleChange} required
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          {/* Jenis Kelamin */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Jenis Kelamin</label>
            <select name="gender" value={form.gender} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30">
              <option value="L">Laki-laki</option><option value="P">Perempuan</option>
            </select>
          </div>
          {/* Berat */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Berat Badan (kg)</label>
            <input type="number" step="0.1" name="weight_kg" value={form.weight_kg} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          {/* Tinggi */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Tinggi Badan (cm)</label>
            <input type="number" step="0.1" name="height_cm" value={form.height_cm} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          {/* Sistolik */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Tekanan Darah Sistolik</label>
            <input type="number" name="blood_pressure_sys" value={form.blood_pressure_sys} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          {/* Diastolik */}
          <div>
            <label className="block text-sm font-medium mb-1.5">Tekanan Darah Diastolik</label>
            <input type="number" name="blood_pressure_dia" value={form.blood_pressure_dia} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
        </div>

        {/* Checkbox */}
        <div className="flex gap-6">
          <label className="flex items-center gap-2">
            <input type="checkbox" name="diabetes_history" checked={form.diabetes_history === 1} onChange={handleChange}
              className="w-4 h-4 text-primaryBlue" />
            <span className="text-sm">Riwayat Diabetes</span>
          </label>
          <label className="flex items-center gap-2">
            <input type="checkbox" name="smoking_history" checked={form.smoking_history === 1} onChange={handleChange}
              className="w-4 h-4 text-primaryBlue" />
            <span className="text-sm">Riwayat Merokok</span>
          </label>
        </div>

        {/* Tombol */}
        <div className="flex gap-3 pt-4">
          <button type="button" onClick={() => navigate(-1)}
            className="px-6 py-2.5 border border-lineGray rounded-lg text-textSecondary hover:bg-gray-50 transition">Batal</button>
          <button type="submit" disabled={loading}
            className="px-6 py-2.5 bg-primaryBlue text-white rounded-lg hover:bg-blue-600 transition disabled:opacity-50">
            {loading ? 'Menyimpan...' : 'Simpan Perubahan'}
          </button>
        </div>
      </form>
      <ReusableModal isOpen={modal.isOpen}
        onClose={() => {
          setModal({ ...modal, isOpen: false })
          if (modal.type === 'success') navigate('/admin/data-pasien')
        }}
        title={modal.title} message={modal.message} type={modal.type} />
    </div>
  )
}