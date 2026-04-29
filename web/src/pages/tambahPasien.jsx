import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import apiClient from '../api/axios'
import ReusableModal from '../components/common/Modal'

export default function TambahPasien() {
  const navigate = useNavigate()
  const [form, setForm] = useState({
    name: '', email: '', password: '', age: '', gender: 'L',
    weight_kg: '', height_cm: '', blood_pressure_sys: '', blood_pressure_dia: '',
    diabetes_history: 0, smoking_history: 0
  })
  const [loading, setLoading] = useState(false)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })

  const handleChange = (e) => {
    const { name, value, type: inputType, checked } = e.target
    setForm(prev => ({ ...prev, [name]: inputType === 'checkbox' ? (checked ? 1 : 0) : value }))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      await apiClient.post('/patients', form)
      setModal({ isOpen: true, title: 'Berhasil', message: 'Pasien baru berhasil ditambahkan.', type: 'success' })
    } catch {
      setModal({ isOpen: true, title: 'Gagal', message: 'Terjadi kesalahan. Periksa kembali data.', type: 'error' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-darkNavy mb-6">Tambah Pasien Baru</h1>
      <form onSubmit={handleSubmit} className="bg-white rounded-xl shadow-sm p-6 space-y-5">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div>
            <label className="block text-sm font-medium mb-1.5">Nama Lengkap</label>
            <input name="name" value={form.name} onChange={handleChange} required
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1.5">Email</label>
            <input type="email" name="email" value={form.email} onChange={handleChange} required
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1.5">Password</label>
            <input type="password" name="password" value={form.password} onChange={handleChange} required
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1.5">Usia</label>
            <input type="number" name="age" value={form.age} onChange={handleChange} required
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1.5">Jenis Kelamin</label>
            <select name="gender" value={form.gender} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30">
              <option value="L">Laki-laki</option><option value="P">Perempuan</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium mb-1.5">Berat Badan (kg)</label>
            <input type="number" step="0.1" name="weight_kg" value={form.weight_kg} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1.5">Tinggi Badan (cm)</label>
            <input type="number" step="0.1" name="height_cm" value={form.height_cm} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1.5">Tekanan Darah Sistolik</label>
            <input type="number" name="blood_pressure_sys" value={form.blood_pressure_sys} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1.5">Tekanan Darah Diastolik</label>
            <input type="number" name="blood_pressure_dia" value={form.blood_pressure_dia} onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30" />
          </div>
        </div>

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

        <div className="flex gap-3 pt-4">
          <button type="button" onClick={() => navigate(-1)}
            className="px-6 py-2.5 border border-lineGray rounded-lg text-textSecondary hover:bg-gray-50 transition">Batal</button>
          <button type="submit" disabled={loading}
            className="px-6 py-2.5 bg-primaryBlue text-white rounded-lg hover:bg-blue-600 transition disabled:opacity-50">
            {loading ? 'Menyimpan...' : 'Simpan Pasien'}
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