import { useState, useEffect } from 'react'
import { useParams, Link } from 'react-router-dom'
import { FaArrowLeft } from 'react-icons/fa'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts'
import apiClient from '../api/axios'
import LoadingSkeleton from '../components/common/loading'
import RecommendationForm from '../components/common/recommendationForm'
import ReusableModal from '../components/common/Modal'

export default function PatientDetailPage() {
  const { id } = useParams()
  const [patient, setPatient] = useState(null)
  const [history, setHistory] = useState([])
  const [loading, setLoading] = useState(true)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })

  useEffect(() => {
    Promise.all([
      apiClient.get(`/patients/${id}`),
      apiClient.get(`/patients/${id}/measurements?limit=30`)
    ]).then(([patientRes, historyRes]) => {
      setPatient(patientRes.data)
      setHistory(historyRes.data.reverse())
    }).catch(() => {
      setModal({ isOpen: true, title: 'Error', message: 'Gagal memuat data pasien.', type: 'error' })
    }).finally(() => setLoading(false))
  }, [id])

  if (loading) return <LoadingSkeleton rows={6} />
  if (!patient) return <p className="text-center py-12">Data tidak ditemukan.</p>

  const chartData = history.map(h => ({
    time: new Date(h.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
    glucose: h.glucose_estimated
  }))

  return (
    <div>
      <Link to="/admin/data-pasien" className="flex items-center gap-2 text-primaryBlue hover:underline mb-4">
        <FaArrowLeft /> Kembali ke daftar pasien
      </Link>
      <div className="bg-white rounded-xl shadow-sm p-6 mb-6">
        <h1 className="text-2xl font-bold text-darkNavy mb-2">{patient.name}</h1>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm mt-4">
          <div><span className="text-textSecondary">Usia:</span> <p className="font-medium">{patient.age} tahun</p></div>
          <div><span className="text-textSecondary">BMI:</span> <p className="font-medium">{patient.bmi}</p></div>
          <div><span className="text-textSecondary">Risiko:</span> <p className={`font-medium ${patient.risk_level === 'high' ? 'text-errorRed' : 'text-successGreen'}`}>
            {patient.risk_level === 'high' ? 'Tinggi' : 'Rendah'}
          </p></div>
          <div><span className="text-textSecondary">Glukosa Terakhir:</span> <p className={`font-bold ${patient.latest_glucose > 200 ? 'text-errorRed' : patient.latest_glucose < 70 ? 'text-warningAmber' : 'text-successGreen'}`}>
            {patient.latest_glucose} mg/dL
          </p></div>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-6 mb-6">
        <h3 className="text-lg font-semibold mb-4">Tren Glukosa</h3>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
            <XAxis dataKey="time" tick={{ fontSize: 11 }} />
            <YAxis domain={[0, 400]} tick={{ fontSize: 12 }} />
            <Tooltip />
            <ReferenceLine y={200} stroke="#EF4444" strokeDasharray="5 5" label="Hiper" />
            <ReferenceLine y={70} stroke="#F59E0B" strokeDasharray="5 5" label="Hipo" />
            <Line type="monotone" dataKey="glucose" stroke="#3B82F6" strokeWidth={2} dot={{ r: 2 }} />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <RecommendationForm
        patientId={patient.id}
        onSuccess={() => setModal({ isOpen: true, title: 'Terkirim', message: 'Rekomendasi telah dikirim ke pasien.', type: 'success' })}
      />

      <ReusableModal isOpen={modal.isOpen} onClose={() => setModal({ ...modal, isOpen: false })}
        title={modal.title} message={modal.message} type={modal.type} />
    </div>
  )
}