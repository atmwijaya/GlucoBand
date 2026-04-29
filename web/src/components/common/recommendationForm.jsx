import { useState } from 'react'
import apiClient from '../../api/axios'
import ReusableModal from './modal'

export default function RecommendationForm({ patientId, onSuccess }) {
  const [content, setContent] = useState('')
  const [saving, setSaving] = useState(false)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!content.trim()) return
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
      <form onSubmit={handleSubmit} className="bg-white rounded-xl shadow-sm p-6">
        <h3 className="text-lg font-semibold mb-4">Berikan Rekomendasi Medis</h3>
        <textarea
          value={content} onChange={e => setContent(e.target.value)}
          placeholder="Tulis saran atau rekomendasi untuk pasien..." rows={4}
          className="w-full px-4 py-3 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30 resize-none mb-4"
          required disabled={saving}
        />
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