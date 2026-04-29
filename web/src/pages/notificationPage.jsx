import { useState, useEffect } from 'react'
import apiClient from '../api/axios'
import LoadingSkeleton from '../components/common/loading'

export default function NotificationPage() {
  const [notifs, setNotifs] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    apiClient.get('/notifications?limit=50')
      .then(({ data }) => setNotifs(data))
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <LoadingSkeleton rows={5} />

  return (
    <div>
      <h1 className="text-2xl font-bold text-darkNavy mb-6">Notifikasi Peringatan</h1>
      <div className="bg-white rounded-xl shadow-sm p-6">
        {notifs.length === 0 ? (
          <p className="text-center text-gray-400 py-8">Tidak ada notifikasi.</p>
        ) : (
          <ul className="space-y-3">
            {notifs.map(notif => (
              <li key={notif.id} className={`p-4 rounded-lg ${notif.type === 'hiperglikemia' ? 'bg-red-50 text-red-800' : 'bg-amber-50 text-amber-800'}`}>
                <div className="flex justify-between items-start">
                  <div>
                    <span className="font-medium">{notif.patient_name || 'Pasien'}</span>
                    <p className="text-sm mt-1">Glukosa: <strong>{notif.glucose_value} mg/dL</strong> ({notif.type === 'hiperglikemia' ? 'Hiperglikemia' : 'Hipoglikemia'})</p>
                    {notif.message && <p className="text-sm mt-1 opacity-80">{notif.message}</p>}
                  </div>
                  <span className="text-xs">{new Date(notif.created_at).toLocaleString('id-ID')}</span>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}