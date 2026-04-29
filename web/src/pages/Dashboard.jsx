import { useState, useEffect } from 'react'
import { FaUsers, FaBell, FaChartBar } from 'react-icons/fa'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { format } from 'date-fns'
import { id } from 'date-fns/locale'
import apiClient from '../api/axios'
import StatCard from '../components/common/statCard'
import Calendar from '../components/common/calender'

function getGreeting() {
  const hour = new Date().getHours()
  if (hour < 11) return 'Selamat Pagi'
  if (hour < 15) return 'Selamat Siang'
  if (hour < 18) return 'Selamat Sore'
  return 'Selamat Malam'
}

export default function DashboardPage() {
  const greeting = getGreeting()
  const user = JSON.parse(sessionStorage.getItem('user')) || { name: 'Dok!' }
  const [stats, setStats] = useState({ total_patients: 0, alerts_today: 0, total_measurements: 0 })
  const [monthlyData, setMonthlyData] = useState([])
  const [recentPatients, setRecentPatients] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [statsRes, patientsRes] = await Promise.all([
          apiClient.get('/dashboard/stats'),
          apiClient.get('/patients')
        ])
        setStats(statsRes.data)

        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des']
        const monthly = {}
        patientsRes.data.forEach(p => {
          if (p.created_at) {
            const m = monthNames[new Date(p.created_at).getMonth()]
            monthly[m] = (monthly[m] || 0) + 1
          }
        })
        setMonthlyData(monthNames.map(m => ({ month: m, count: monthly[m] || 0 })))
        setRecentPatients(patientsRes.data.slice(0, 5))
      } catch (err) {
        console.error('Gagal memuat dashboard:', err)
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [])

  return (
    <div>
      <h1 className="text-2xl font-bold text-darkNavy mb-6">
        {greeting} | {format(new Date(), 'EEEE, dd MMMM yyyy', { locale: id })}
      </h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <StatCard title="Total Pasien" value={stats.total_patients} icon={FaUsers} color="text-primaryBlue" loading={loading} />
        <StatCard title="Notifikasi Hari Ini" value={stats.alerts_today} icon={FaBell} color="text-red-500" loading={loading} />
        <StatCard title="Total Pengukuran" value={stats.total_measurements} icon={FaChartBar} color="text-successGreen" loading={loading} />
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        <div className="lg:col-span-2 bg-white rounded-xl shadow-sm p-6">
          <h3 className="text-lg font-semibold mb-4">Registrasi Pasien per Bulan</h3>
          {loading ? (
            <div className="h-64 animate-pulse bg-gray-100 rounded" />
          ) : (
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={monthlyData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                <XAxis dataKey="month" tick={{ fontSize: 12 }} />
                <YAxis allowDecimals={false} tick={{ fontSize: 12 }} />
                <Tooltip />
                <Bar dataKey="count" fill="#3B82F6" radius={[4, 4, 0, 0]} name="Pasien" />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
        <Calendar />
      </div>
      <div className="bg-white rounded-xl shadow-sm p-6">
        <h3 className="text-lg font-semibold mb-4">Pasien Terbaru</h3>
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-lineGray text-sm text-textSecondary">
              <th className="py-3 font-medium">Nama</th><th className="py-3 font-medium">Usia</th><th className="py-3 font-medium">BMI</th>
              <th className="py-3 font-medium">Glukosa</th><th className="py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {recentPatients.map(patient => {
              const glucose = patient.latest_glucose
              const status = glucose ? (glucose > 200 ? 'Hiper' : glucose < 70 ? 'Hipo' : 'Normal') : '—'
              const statusColor = glucose
                ? (glucose > 200 ? 'text-red-600 bg-red-50' : glucose < 70 ? 'text-amber-600 bg-amber-50' : 'text-green-600 bg-green-50')
                : 'text-gray-400 bg-gray-50'

              return (
                <tr key={patient.id} className="border-b border-lineGray hover:bg-blue-50/30 transition">
                  <td className="py-3 font-medium">{patient.name}</td>
                  <td className="py-3 text-sm">{patient.age} th</td>
                  <td className="py-3 text-sm">{patient.bmi}</td>
                  <td className={`py-3 text-sm font-bold ${glucose > 200 ? 'text-errorRed' : glucose < 70 ? 'text-warningAmber' : 'text-successGreen'}`}>
                    {glucose ?? '—'} mg/dL
                  </td>
                  <td className="py-3">
                    <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${statusColor}`}>{status}</span>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}