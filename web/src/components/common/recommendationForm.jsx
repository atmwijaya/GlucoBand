import { useState } from 'react'
import apiClient from '../../api/axios'
import ReusableModal from './modal'

export default function RecommendationForm({ patientId, onSuccess }) {
  const [content, setContent] = useState('')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!content.trim()) {
      setError('Rekomendasi medis tidak boleh kosong.')
      return
    }
    setError('')
    setSaving(true)
    try {
      await apiClient.post(`/patients/${patientId}/recommendations`, { content: content.trim() })
      setContent('')
      onSuccess?.()
      setModal({ isOpen: true, title: 'Berhasil', message: 'Rekomendasi medis telah terkirim ke pasien.', type: 'success' })
    } catch {
      setModal({ isOpen: true, title: 'Gagal', message: 'Terjadi kesalahan. Silakan coba lagi.', type: 'error' })
    } finally {
      setSaving(false)
    }
  }

  return (
    <>
      <form onSubmit={handleSubmit} noValidate className="bg-white rounded-xl shadow-sm p-6">
        <h3 className="text-lg font-semibold mb-4">Berikan Rekomendasi Medis</h3>
        <textarea
          value={content}
          onChange={e => {
            setContent(e.target.value)
            if (e.target.value.trim()) setError('')
          }}
          placeholder="Tulis saran atau rekomendasi untuk pasien..."
          rows={4}
          className={`w-full px-4 py-3 border rounded-lg focus:outline-none transition resize-none mb-2 ${
            error
              ? 'border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200'
              : 'border-lineGray focus:ring-2 focus:ring-primaryBlue/30'
          }`}
          disabled={saving}
        />
        {error && (
          <p className="text-xs text-red-500 mb-3 font-medium">{error}</p>
        )}
        <button type="submit" disabled={saving}
          className="px-6 py-2.5 bg-primaryBlue text-white rounded-lg hover:bg-blue-600 transition disabled:opacity-50">
          {saving ? 'Mengirim...' : 'Kirim Rekomendasi'}
        </button>
      </form>
      <ReusableModal isOpen={modal.isOpen} onClose={() => setModal({ ...modal, isOpen: false })}
        title={modal.title} message={modal.message} type={modal.type} />
    </>
  )
}