import { useState, useEffect, useCallback } from 'react'
import { FaEdit, FaTrash, FaPlus } from 'react-icons/fa'
import apiClient from '../api/axios'
import Modal from '../components/common/modal'
import LoadingSkeleton from '../components/common/loading'

const FaqFormModal = ({ isOpen, onClose, onSave, faq }) => {
  const [question, setQuestion] = useState('')
  const [answer, setAnswer] = useState('')
  const [category, setCategory] = useState('umum')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (isOpen) {
      setQuestion(faq?.question || '')
      setAnswer(faq?.answer || '')
      setCategory(faq?.category || 'umum')
    }
  }, [faq, isOpen])

  if (!isOpen) return null

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!question.trim() || !answer.trim()) return
    setSaving(true)
    await onSave({ ...faq, question: question.trim(), answer: answer.trim(), category })
    setSaving(false)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <form onSubmit={handleSubmit} onClick={e => e.stopPropagation()} className="bg-white rounded-2xl shadow-2xl w-full max-w-lg p-6">
        <h2 className="text-lg font-bold mb-4">{faq ? 'Edit FAQ' : 'Tambah FAQ Baru'}</h2>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Kategori</label>
            <select value={category} onChange={e => setCategory(e.target.value)}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30">
              <option value="umum">Umum</option><option value="aplikasi">Aplikasi</option><option value="kesehatan">Kesehatan</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Pertanyaan</label>
            <input value={question} onChange={e => setQuestion(e.target.value)} required disabled={saving}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none" placeholder="Masukkan pertanyaan" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Jawaban</label>
            <textarea value={answer} onChange={e => setAnswer(e.target.value)} required disabled={saving} rows={4}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg resize-none" placeholder="Masukkan jawaban lengkap" />
          </div>
          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="px-5 py-2 border border-lineGray rounded-lg text-textSecondary">Batal</button>
            <button type="submit" disabled={saving} className="px-5 py-2 bg-primaryBlue text-white rounded-lg hover:bg-blue-600 disabled:opacity-50">
              {saving ? 'Menyimpan...' : 'Simpan'}
            </button>
          </div>
        </div>
      </form>
    </div>
  )
}

export default function FAQManagePage() {
  const [faqs, setFaqs] = useState([])
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [editFaq, setEditFaq] = useState(null)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })
  const [selectedFaq, setSelectedFaq] = useState(null)

  const fetchFaqs = useCallback(async () => {
    setLoading(true)
    try {
      const { data } = await apiClient.get('/faq')
      setFaqs(data)
    } catch { setModal({ isOpen: true, title: 'Error', message: 'Gagal memuat FAQ.', type: 'error' })
    } finally { setLoading(false) }
  }, [])

  useEffect(() => { fetchFaqs() }, [fetchFaqs])

  const handleSave = async (faqData) => {
    try {
      if (faqData.id) { await apiClient.put(`/faq/${faqData.id}`, faqData) }
      else { await apiClient.post('/faq', faqData) }
      setShowForm(false)
      setEditFaq(null)
      fetchFaqs()
    } catch { setModal({ isOpen: true, title: 'Gagal', message: 'Gagal menyimpan FAQ.', type: 'error' }) }
  }

  const handleDelete = async () => {
    if (!selectedFaq) return
    try {
      await apiClient.delete(`/faq/${selectedFaq.id}`)
      setModal({ isOpen: true, title: 'Berhasil', message: 'FAQ berhasil dihapus.', type: 'success' })
      fetchFaqs()
    } catch { setModal({ isOpen: true, title: 'Gagal', message: 'Gagal menghapus FAQ.', type: 'error' })
    } finally { setSelectedFaq(null) }
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-darkNavy">Kelola FAQ</h1>
        <button onClick={() => { setEditFaq(null); setShowForm(true) }}
          className="flex items-center gap-2 px-4 py-2 bg-primaryBlue text-white rounded-lg hover:bg-blue-600 transition">
          <FaPlus /> Tambah FAQ
        </button>
      </div>

      {loading ? <LoadingSkeleton rows={4} /> : (
        <div className="space-y-4">
          {faqs.map(faq => (
            <div key={faq.id} className="bg-white rounded-xl shadow-sm p-5">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <span className="text-xs font-medium px-2 py-0.5 bg-blue-50 text-primaryBlue rounded-full mb-2 inline-block">
                    {faq.category || 'umum'}
                  </span>
                  <h3 className="font-semibold text-lg mb-2">{faq.question}</h3>
                  <p className="text-sm text-textSecondary">{faq.answer}</p>
                </div>
                <div className="flex gap-2 ml-4">
                  <button onClick={() => { setEditFaq(faq); setShowForm(true) }}
                    className="p-2 text-primaryBlue hover:bg-blue-50 rounded-lg"><FaEdit /></button>
                  <button onClick={() => {
                    setSelectedFaq(faq)
                    setModal({ isOpen: true, title: 'Hapus FAQ?', message: `Hapus "${faq.question}"?`, type: 'confirm' })
                  }} className="p-2 text-red-500 hover:bg-red-50 rounded-lg"><FaTrash /></button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <FaqFormModal isOpen={showForm} onClose={() => { setShowForm(false); setEditFaq(null) }} onSave={handleSave} faq={editFaq} />
      <Modal isOpen={modal.isOpen} onClose={() => setModal({ ...modal, isOpen: false })}
        onConfirm={modal.type === 'confirm' ? handleDelete : undefined} title={modal.title} message={modal.message} type={modal.type} />
    </div>
  )
}