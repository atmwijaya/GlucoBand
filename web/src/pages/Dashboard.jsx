import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  FaUsers,
  FaBell,
  FaChartBar,
  FaChartLine,
  FaCalendarAlt,
  FaChevronLeft,
  FaChevronRight,
  FaHeartbeat,
  FaSortAmountDown,
  FaSortAmountUp
} from 'react-icons/fa'
import {
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine
} from 'recharts'
import { format, subDays, addDays, isSameDay } from 'date-fns'
import { id } from 'date-fns/locale'
import apiClient from '../api/axios'
import { getPatientMeasurements, getPatientMeasurementDates } from '../api/measurementApi'
import StatCard from '../components/common/statCard'
import Calendar from '../components/common/calender'

function getGreeting() {
  const hour = new Date().getHours()
  if (hour < 11) return 'Selamat Pagi'
  if (hour < 15) return 'Selamat Siang'
  if (hour < 18) return 'Selamat Sore'
  return 'Selamat Malam'
}

function getDiabetesRisk(patient) {
  const r = (patient.risk_level || '').toLowerCase()
  if (r === 'tinggi' || r === 'high') {
    return { level: 'Tinggi', badgeClass: 'bg-red-50 text-red-700 border border-red-200' }
  }
  if (r === 'sedang' || r === 'moderate' || r === 'medium') {
    return { level: 'Sedang', badgeClass: 'bg-amber-50 text-amber-700 border border-amber-200' }
  }
  if (r === 'rendah' || r === 'low') {
    return { level: 'Rendah', badgeClass: 'bg-emerald-50 text-emerald-700 border border-emerald-200' }
  }

  const glucose = patient.latest_glucose !== null && patient.latest_glucose !== undefined ? Number(patient.latest_glucose) : null
  const bmi = patient.bmi ? Number(patient.bmi) : null
  const hasDiabetesHistory = patient.diabetes_history === 1 || patient.diabetes_history === '1'

  if (hasDiabetesHistory || (glucose !== null && glucose >= 200)) {
    return { level: 'Tinggi', badgeClass: 'bg-red-50 text-red-700 border border-red-200' }
  }
  if ((glucose !== null && glucose >= 140) || (bmi !== null && bmi >= 25.0)) {
    return { level: 'Sedang', badgeClass: 'bg-amber-50 text-amber-700 border border-amber-200' }
  }
  return { level: 'Rendah', badgeClass: 'bg-emerald-50 text-emerald-700 border border-emerald-200' }
}

export default function DashboardPage() {
  const navigate = useNavigate()
  const greeting = getGreeting()
  const user = JSON.parse(sessionStorage.getItem('user')) || { name: 'Dok!' }
  const [stats, setStats] = useState({ total_patients: 0, alerts_today: 0, total_measurements: 0 })
  const [allPatients, setAllPatients] = useState([])
  const [monthlyData, setMonthlyData] = useState([])
  const [loading, setLoading] = useState(true)
  const [filterType, setFilterType] = useState('pengukuran_tertinggi')
  const [currentPage, setCurrentPage] = useState(1)
  const itemsPerPage = 10
  const [chartView, setChartView] = useState('patient_daily')
  const [selectedDate, setSelectedDate] = useState(new Date())
  const [selectedPatientId, setSelectedPatientId] = useState(null)
  const [dailyMeasurements, setDailyMeasurements] = useState([])
  const [markedDates, setMarkedDates] = useState([])
  const [loadingDaily, setLoadingDaily] = useState(false)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [statsRes, patientsRes] = await Promise.all([
          apiClient.get('/dashboard/stats'),
          apiClient.get('/patients')
        ])
        setStats(statsRes.data)
        const patients = patientsRes.data || []
        setAllPatients(patients)

        if (patients.length > 0) {
          const withMeasurements = patients.filter((p) => p.latest_glucose !== null && p.latest_glucose !== undefined)
          const sorted = withMeasurements.length > 0
            ? [...withMeasurements].sort((a, b) => Number(b.latest_glucose) - Number(a.latest_glucose))
            : patients
          const topPatient = sorted[0]
          setSelectedPatientId((prev) => prev || (topPatient ? topPatient.id : patients[0].id))
        }

        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des']
        const monthly = {}
        patients.forEach((p) => {
          if (p.created_at) {
            const m = monthNames[new Date(p.created_at).getMonth()]
            monthly[m] = (monthly[m] || 0) + 1
          }
        })
        setMonthlyData(monthNames.map((m) => ({ month: m, count: monthly[m] || 0 })))
      } catch (err) {
        console.error('Gagal memuat dashboard:', err)
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [])

  const filteredPatients = useMemo(() => {
    const list = [...allPatients]
    if (filterType === 'pengukuran_tertinggi') {
      return list.sort((a, b) => {
        const hasA = a.latest_glucose !== null && a.latest_glucose !== undefined
        const hasB = b.latest_glucose !== null && b.latest_glucose !== undefined
        if (hasA && !hasB) return -1
        if (!hasA && hasB) return 1
        if (hasA && hasB) {
          const diff = Number(b.latest_glucose) - Number(a.latest_glucose)
          if (diff !== 0) return diff
        }
        return new Date(b.latest_measurement_at || b.created_at || 0).getTime() -
               new Date(a.latest_measurement_at || a.created_at || 0).getTime()
      })
    }
    if (filterType === 'pengukuran_terendah') {
      return list.sort((a, b) => {
        const hasA = a.latest_glucose !== null && a.latest_glucose !== undefined
        const hasB = b.latest_glucose !== null && b.latest_glucose !== undefined
        if (hasA && !hasB) return -1
        if (!hasA && hasB) return 1
        if (hasA && hasB) {
          const diff = Number(a.latest_glucose) - Number(b.latest_glucose)
          if (diff !== 0) return diff
        }
        return new Date(b.latest_measurement_at || b.created_at || 0).getTime() -
               new Date(a.latest_measurement_at || a.created_at || 0).getTime()
      })
    }
    return list.sort((a, b) => new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime())
  }, [allPatients, filterType])

  const totalPages = Math.ceil(filteredPatients.length / itemsPerPage) || 1
  const paginatedPatients = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage
    return filteredPatients.slice(start, start + itemsPerPage)
  }, [filteredPatients, currentPage, itemsPerPage])

  const handleFilterChange = (type) => {
    setFilterType(type)
    setCurrentPage(1)
  }

  useEffect(() => {
    if (!selectedPatientId) return
    getPatientMeasurementDates(selectedPatientId)
      .then((res) => {
        if (Array.isArray(res.data)) {
          setMarkedDates(res.data)
        }
      })
      .catch(() => setMarkedDates([]))
  }, [selectedPatientId])

  useEffect(() => {
    if (!selectedPatientId || !selectedDate) return
    setLoadingDaily(true)
    const dateStr = format(selectedDate, 'yyyy-MM-dd')

    getPatientMeasurements(selectedPatientId, 100, dateStr)
      .then((res) => {
        const raw = res.data || []
        // Pastikan terfilter sesuai tanggal terpilih
        const filtered = raw.filter((m) => {
          if (!m.created_at) return false
          return m.created_at.startsWith(dateStr)
        })
        // Urutkan berdasarkan waktu secara kronologis menaik
        filtered.sort((a, b) => new Date(a.created_at) - new Date(b.created_at))
        setDailyMeasurements(filtered)
      })
      .catch((err) => {
        console.error('Gagal memuat pengukuran harian:', err)
        setDailyMeasurements([])
      })
      .finally(() => setLoadingDaily(false))
  }, [selectedPatientId, selectedDate])

  const selectedPatient = allPatients.find((p) => p.id === Number(selectedPatientId))

  // Format data harian untuk Recharts
  const chartDailyData = dailyMeasurements.map((m) => {
    const timeStr = m.created_at ? format(new Date(m.created_at), 'HH:mm') : '--:--'
    const glucoseVal = parseFloat(m.glucose_estimated) || 0
    return {
      time: timeStr,
      glucose: glucoseVal,
      heartRate: m.ppg_heart_rate,
      spo2: m.ppg_spo2,
      temp: m.skin_temp_celsius,
      status: m.status || (glucoseVal > 200 ? 'Hiperglikemia' : glucoseVal < 70 ? 'Hipoglikemia' : 'Normal')
    }
  })

  // Ringkasan Glukosa Harian
  const validGlucose = dailyMeasurements
    .map((m) => parseFloat(m.glucose_estimated))
    .filter((v) => !isNaN(v) && v > 0)

  const avgGlucose = validGlucose.length > 0
    ? Math.round(validGlucose.reduce((a, b) => a + b, 0) / validGlucose.length)
    : 0
  const maxGlucose = validGlucose.length > 0 ? Math.max(...validGlucose) : 0
  const minGlucose = validGlucose.length > 0 ? Math.min(...validGlucose) : 0

  // Custom Tooltip Grafik Harian
  const CustomDailyTooltip = ({ active, payload, label }) => {
    if (active && payload && payload.length) {
      const data = payload[0].payload
      return (
        <div className="bg-white p-3 rounded-xl shadow-xl border border-slate-200 text-xs min-w-[170px]">
          <p className="font-bold text-slate-800 mb-1 border-b pb-1">Pukul {label} WIB</p>
          <div className="flex items-center justify-between gap-2 mb-1.5">
            <span className="text-slate-500 font-medium">Glukosa:</span>
            <div className="flex items-center gap-1.5">
              <span className="font-bold text-sm text-primaryBlue">{data.glucose} mg/dL</span>
              <span
                className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${
                  data.glucose > 200
                    ? 'bg-red-100 text-red-700'
                    : data.glucose < 70
                    ? 'bg-amber-100 text-amber-700'
                    : 'bg-emerald-100 text-emerald-700'
                }`}
              >
                {data.status}
              </span>
            </div>
          </div>
          {data.heartRate ? (
            <div className="flex items-center justify-between text-slate-600 mb-0.5">
              <span>Detak Jantung:</span>
              <span className="font-semibold text-slate-800">{data.heartRate} bpm</span>
            </div>
          ) : null}
          {data.spo2 ? (
            <div className="flex items-center justify-between text-slate-600 mb-0.5">
              <span>SpO2:</span>
              <span className="font-semibold text-slate-800">{data.spo2}%</span>
            </div>
          ) : null}
          {data.temp ? (
            <div className="flex items-center justify-between text-slate-600">
              <span>Suhu Kulit:</span>
              <span className="font-semibold text-slate-800">{data.temp}°C</span>
            </div>
          ) : null}
        </div>
      )
    }
    return null
  }

  return (
    <div>
      {/* Header Salam */}
      <h1 className="text-2xl font-bold text-darkNavy mb-6">
        {greeting} | {format(new Date(), 'EEEE, dd MMMM yyyy', { locale: id })}
      </h1>

      {/* Kartu Statistik */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <StatCard title="Total Pasien" value={stats.total_patients} icon={FaUsers} color="text-primaryBlue" loading={loading} />
        <StatCard title="Notifikasi Hari Ini" value={stats.alerts_today} icon={FaBell} color="text-red-500" loading={loading} />
        <StatCard title="Total Pengukuran" value={stats.total_measurements} icon={FaChartBar} color="text-successGreen" loading={loading} />
      </div>

      {/* Grid Grafik & Kalender */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8 items-start">
        {/* Kolom Grafik Utama (2 Kolom) */}
        <div className="lg:col-span-2 bg-white rounded-xl shadow-sm p-6 border border-slate-100">
          {/* Header Opsi Tab Grafik */}
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-5 border-b pb-4">
            {/* Tab Switcher */}
            <div className="flex items-center bg-slate-100 p-1 rounded-xl">
              <button
                type="button"
                onClick={() => setChartView('patient_daily')}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                  chartView === 'patient_daily'
                    ? 'bg-white text-primaryBlue shadow-sm'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <FaHeartbeat />
                <span>Grafik Glukosa Pasien (Harian)</span>
              </button>
              <button
                type="button"
                onClick={() => setChartView('monthly')}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                  chartView === 'monthly'
                    ? 'bg-white text-primaryBlue shadow-sm'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <FaChartBar />
                <span>Registrasi Pasien (Bulanan)</span>
              </button>
            </div>

            {/* Kontrol Pasien & Tanggal jika mode Grafik Harian */}
            {chartView === 'patient_daily' && (
              <div className="flex items-center gap-2 w-full sm:w-auto">
                <select
                  value={selectedPatientId || ''}
                  onChange={(e) => setSelectedPatientId(Number(e.target.value))}
                  className="w-full sm:w-auto text-xs font-semibold bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-slate-800 focus:outline-none focus:ring-2 focus:ring-primaryBlue/30 cursor-pointer"
                >
                  {allPatients.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name} ({p.age} th)
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>

          {/* Konten Grafik Sesuai Mode */}
          {chartView === 'monthly' ? (
            // ==========================================
            // GRAFIK 1: REGISTRASI PASIEN PER BULAN
            // ==========================================
            <div>
              <div className="mb-4">
                <h3 className="text-base font-bold text-slate-800">Registrasi Pasien per Bulan</h3>
                <p className="text-xs text-slate-500">Jumlah pasien baru yang terdaftar di GlucoBand sepanjang tahun</p>
              </div>
              {loading ? (
                <div className="h-64 animate-pulse bg-gray-100 rounded-xl" />
              ) : (
                <ResponsiveContainer width="100%" height={290}>
                  <BarChart data={monthlyData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                    <XAxis dataKey="month" tick={{ fontSize: 12, fill: '#64748B' }} />
                    <YAxis allowDecimals={false} tick={{ fontSize: 12, fill: '#64748B' }} />
                    <Tooltip />
                    <Bar dataKey="count" fill="#3B82F6" radius={[6, 6, 0, 0]} name="Pasien" />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>
          ) : (
            // ==========================================
            // GRAFIK 2: GRAFIK HARIAN PER PASIEN
            // ==========================================
            <div>
              {/* Info Pasien & Navigasi Tanggal */}
              <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
                <div>
                  <h3 className="text-base font-bold text-slate-800">
                    Tren Glukosa: {selectedPatient?.name || 'Pilih Pasien'}
                  </h3>
                  <p className="text-xs text-slate-500 flex items-center gap-1.5 mt-0.5">
                    <FaCalendarAlt className="text-primaryBlue" />
                    <span>{format(selectedDate, 'EEEE, dd MMMM yyyy', { locale: id })}</span>
                  </p>
                </div>

                {/* Navigasi Cepat Tanggal (Hari Sebelumnya / Hari Berikutnya) */}
                <div className="flex items-center gap-1.5">
                  {!isSameDay(selectedDate, new Date()) && (
                    <button
                      type="button"
                      onClick={() => setSelectedDate(new Date())}
                      className="px-2.5 py-1 text-xs font-bold text-primaryBlue bg-blue-50 hover:bg-blue-100 rounded-lg transition"
                      title="Kembali ke Hari Ini"
                    >
                      Hari Ini
                    </button>
                  )}

                  <div className="flex items-center gap-1 bg-slate-50 border border-slate-200 rounded-lg p-0.5">
                    <button
                      type="button"
                      onClick={() => setSelectedDate((d) => subDays(d, 1))}
                      className="p-1.5 text-slate-500 hover:text-primaryBlue hover:bg-white rounded transition"
                      title="Hari Sebelumnya"
                    >
                      <FaChevronLeft size={11} />
                    </button>
                    <span
                      className={`px-2.5 py-1 text-xs font-bold transition text-center min-w-[80px] ${
                        isSameDay(selectedDate, new Date()) ? 'text-primaryBlue' : 'text-slate-800'
                      }`}
                    >
                      {isSameDay(selectedDate, new Date())
                        ? 'Hari Ini'
                        : format(selectedDate, 'dd MMM yyyy', { locale: id })}
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        if (!isSameDay(selectedDate, new Date())) {
                          setSelectedDate((d) => addDays(d, 1))
                        }
                      }}
                      disabled={isSameDay(selectedDate, new Date())}
                      className={`p-1.5 rounded transition ${
                        isSameDay(selectedDate, new Date())
                          ? 'text-slate-300 cursor-not-allowed'
                          : 'text-slate-500 hover:text-primaryBlue hover:bg-white cursor-pointer'
                      }`}
                      title={isSameDay(selectedDate, new Date()) ? 'Tanggal masa depan tidak dapat dipilih' : 'Hari Berikutnya'}
                    >
                      <FaChevronRight size={11} />
                    </button>
                  </div>
                </div>
              </div>

              {/* Ringkasan Angka Pengukuran Hari Ini (jika ada data) */}
              {dailyMeasurements.length > 0 && (
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-4">
                  <div className="bg-blue-50/60 border border-blue-100 rounded-lg p-2.5">
                    <span className="text-[11px] text-slate-500">Rata-rata</span>
                    <p className="text-sm font-bold text-primaryBlue">{avgGlucose} mg/dL</p>
                  </div>
                  <div className="bg-red-50/60 border border-red-100 rounded-lg p-2.5">
                    <span className="text-[11px] text-slate-500">Tertinggi</span>
                    <p className="text-sm font-bold text-red-600">{maxGlucose} mg/dL</p>
                  </div>
                  <div className="bg-emerald-50/60 border border-emerald-100 rounded-lg p-2.5">
                    <span className="text-[11px] text-slate-500">Terendah</span>
                    <p className="text-sm font-bold text-emerald-600">{minGlucose} mg/dL</p>
                  </div>
                  <div className="bg-slate-50 border border-slate-200 rounded-lg p-2.5">
                    <span className="text-[11px] text-slate-500">Pengukuran</span>
                    <p className="text-sm font-bold text-slate-700">{dailyMeasurements.length} kali</p>
                  </div>
                </div>
              )}

              {/* Tampilan Visual Grafik Harian */}
              {loadingDaily ? (
                <div className="h-64 animate-pulse bg-gray-100 rounded-xl" />
              ) : chartDailyData.length === 0 ? (
                // State Kosong Ramah
                <div className="h-[270px] flex flex-col items-center justify-center text-center p-6 bg-slate-50/60 rounded-xl border border-dashed border-slate-200">
                  <div className="w-12 h-12 rounded-full bg-blue-50 text-primaryBlue flex items-center justify-center mb-3">
                    <FaCalendarAlt size={20} />
                  </div>
                  <p className="font-semibold text-slate-700 text-sm">
                    Tidak ada data pengukuran pada {format(selectedDate, 'dd MMMM yyyy', { locale: id })}
                  </p>
                  <p className="text-xs text-slate-500 mt-1 max-w-sm">
                    Pasien <span className="font-semibold text-slate-700">{selectedPatient?.name}</span> belum melakukan pengukuran pada tanggal ini. Klik tanggal bertitik hijau di kalender untuk melihat riwayat.
                  </p>
                  {markedDates.length > 0 && (
                    <button
                      type="button"
                      onClick={() => setSelectedDate(new Date(markedDates[0]))}
                      className="mt-3 text-xs bg-primaryBlue text-white px-3.5 py-1.5 rounded-lg font-bold hover:bg-blue-600 transition shadow-sm"
                    >
                      Lihat Pengukuran Terakhir ({format(new Date(markedDates[0]), 'dd MMM yyyy', { locale: id })})
                    </button>
                  )}
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={270}>
                  <LineChart data={chartDailyData} margin={{ top: 10, right: 10, left: -10, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                    <XAxis dataKey="time" tick={{ fontSize: 11, fill: '#64748B' }} />
                    <YAxis domain={[40, 'auto']} tick={{ fontSize: 11, fill: '#64748B' }} unit=" mg" />
                    <Tooltip content={<CustomDailyTooltip />} />
                    <ReferenceLine
                      y={200}
                      stroke="#EF4444"
                      strokeDasharray="4 4"
                      label={{ value: 'Hiper (200)', fill: '#EF4444', fontSize: 10, position: 'insideTopRight' }}
                    />
                    <ReferenceLine
                      y={70}
                      stroke="#F59E0B"
                      strokeDasharray="4 4"
                      label={{ value: 'Hipo (70)', fill: '#F59E0B', fontSize: 10, position: 'insideBottomRight' }}
                    />
                    <Line
                      type="monotone"
                      dataKey="glucose"
                      stroke="#3B82F6"
                      strokeWidth={2.5}
                      dot={{ r: 4, fill: '#3B82F6', strokeWidth: 2, stroke: '#FFFFFF' }}
                      activeDot={{ r: 6, fill: '#2563EB' }}
                      name="Glukosa"
                    />
                  </LineChart>
                </ResponsiveContainer>
              )}
            </div>
          )}
        </div>

        {/* Kolom Kalender Interaktif (1 Kolom) */}
        <div className="lg:col-span-1">
          <Calendar
            selectedDate={selectedDate}
            onSelectDate={(date) => {
              setSelectedDate(date)
              // Otomatis beralih ke mode grafik harian agar pengguna langsung melihat grafiknya
              setChartView('patient_daily')
            }}
            markedDates={markedDates}
          />
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-6 border border-slate-100">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-5 border-b pb-4">
          <div className="flex flex-wrap items-center gap-3">
            <h3 className="text-lg font-bold text-darkNavy">
              {filterType === 'pengukuran_tertinggi'
                ? 'Pengukuran Tertinggi Pasien'
                : filterType === 'pengukuran_terendah'
                ? 'Pengukuran Terendah Pasien'
                : 'Pasien Baru Terdaftar'}
            </h3>

            <div className="flex flex-wrap items-center bg-slate-100 p-1 rounded-xl gap-1">
              <button
                type="button"
                onClick={() => handleFilterChange('pengukuran_tertinggi')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                  filterType === 'pengukuran_tertinggi'
                    ? 'bg-white text-primaryBlue shadow-sm'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <FaSortAmountDown size={12} className={filterType === 'pengukuran_tertinggi' ? 'text-primaryBlue' : 'text-slate-500'} />
                <span>Pengukuran Tertinggi</span>
              </button>

              <button
                type="button"
                onClick={() => handleFilterChange('pengukuran_terendah')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                  filterType === 'pengukuran_terendah'
                    ? 'bg-white text-primaryBlue shadow-sm'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <FaSortAmountUp size={12} className={filterType === 'pengukuran_terendah' ? 'text-primaryBlue' : 'text-slate-500'} />
                <span>Pengukuran Terendah</span>
              </button>

              <button
                type="button"
                onClick={() => handleFilterChange('pasien_terbaru')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                  filterType === 'pasien_terbaru'
                    ? 'bg-white text-primaryBlue shadow-sm'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <FaUsers size={12} className={filterType === 'pasien_terbaru' ? 'text-primaryBlue' : 'text-slate-500'} />
                <span>Pasien Terbaru</span>
              </button>
            </div>
          </div>

          <span className="text-xs text-slate-500">
            {filterType === 'pengukuran_tertinggi'
              ? 'Diurutkan dari kadar glukosa tertinggi ke terendah'
              : filterType === 'pengukuran_terendah'
              ? 'Diurutkan dari kadar glukosa terendah ke tertinggi'
              : 'Diurutkan dari tanggal registrasi terbaru'}
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-lineGray text-sm text-textSecondary">
                <th className="py-3 font-medium">Nama Pasien</th>
                <th className="py-3 font-medium">Usia</th>
                <th className="py-3 font-medium">BMI</th>
                <th className="py-3 font-medium">Kadar Glukosa</th>
                <th className="py-3 font-medium">Risiko Diabetes</th>
                <th className="py-3 font-medium text-right">Aksi</th>
              </tr>
            </thead>
            <tbody>
              {paginatedPatients.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-10 text-center text-slate-400 text-sm">
                    Tidak ada data pasien yang ditemukan.
                  </td>
                </tr>
              ) : (
                paginatedPatients.map((patient) => {
                  const glucose = patient.latest_glucose !== null && patient.latest_glucose !== undefined
                    ? Number(patient.latest_glucose)
                    : null

                  const risk = getDiabetesRisk(patient)
                  const isCurrentlySelected = selectedPatientId === patient.id

                  return (
                    <tr
                      key={patient.id}
                      className={`border-b border-lineGray transition ${
                        isCurrentlySelected ? 'bg-blue-50/50' : 'hover:bg-slate-50/80'
                      }`}
                    >
                      <td className="py-3.5 font-bold text-slate-900">
                        <div className="flex items-center gap-2">
                          <span>{patient.name}</span>
                          {glucose && glucose > 200 && (
                            <span className="w-2 h-2 rounded-full bg-red-500 flex-shrink-0" title="Kadar Gula Kritis (Tinggi)" />
                          )}
                        </div>
                        {patient.latest_measurement_at && (
                          <span className="text-[11px] text-slate-400 font-normal block mt-0.5">
                            Ukur: {format(new Date(patient.latest_measurement_at), 'dd MMM yyyy, HH:mm', { locale: id })} WIB
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 text-sm text-slate-600">{patient.age ? `${patient.age} th` : '—'}</td>
                      <td className="py-3.5 text-sm text-slate-600">{patient.bmi || '—'}</td>
                      <td className="py-3.5 text-sm font-extrabold">
                        {glucose !== null ? (
                          <span className={glucose > 200 ? 'text-red-600 text-base' : glucose < 70 ? 'text-amber-600 text-base' : 'text-emerald-600 text-base'}>
                            {glucose.toFixed(1)} <span className="text-xs font-semibold text-slate-500">mg/dL</span>
                          </span>
                        ) : (
                          <span className="text-slate-400 font-normal">—</span>
                        )}
                      </td>
                      <td className="py-3.5">
                        <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${risk.badgeClass}`}>
                          {risk.level}
                        </span>
                      </td>
                      <td className="py-3.5 text-right space-x-2">
                        <button
                          type="button"
                          onClick={() => {
                            setSelectedPatientId(patient.id)
                            setChartView('patient_daily')
                            window.scrollTo({ top: 180, behavior: 'smooth' })
                          }}
                          className={`text-xs px-2.5 py-1.5 rounded-lg font-bold transition inline-flex items-center gap-1.5 ${
                            isCurrentlySelected
                              ? 'bg-primaryBlue text-white shadow-sm'
                              : 'bg-slate-100 text-primaryBlue hover:bg-blue-100'
                          }`}
                          title="Tampilkan grafik harian pasien di panel atas"
                        >
                          <FaChartLine size={12} />
                          <span>{isCurrentlySelected ? 'Dipilih' : 'Grafik'}</span>
                        </button>

                        <button
                          type="button"
                          onClick={() => {
                            navigate('/admin/monitoring', {
                              state: {
                                patientId: patient.id,
                                patient
                              }
                            })
                          }}
                          className="text-xs px-2.5 py-1.5 rounded-lg font-semibold bg-white border border-slate-200 text-slate-700 hover:bg-slate-50 transition shadow-xs inline-flex items-center gap-1"
                          title="Inspect monitoring real-time pasien ini"
                        >
                          <span>Monitoring</span>
                        </button>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="flex flex-col sm:flex-row justify-between items-center gap-3 mt-5 pt-4 border-t border-slate-100 text-sm">
            <p className="text-xs sm:text-sm text-textSecondary">
              Menampilkan <span className="font-semibold text-slate-800">{filteredPatients.length === 0 ? 0 : (currentPage - 1) * itemsPerPage + 1}</span> - <span className="font-semibold text-slate-800">{Math.min(currentPage * itemsPerPage, filteredPatients.length)}</span> dari <span className="font-semibold text-slate-800">{filteredPatients.length}</span> pasien
            </p>
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="p-2 rounded-lg border border-lineGray disabled:opacity-30 hover:bg-gray-50 transition text-slate-600"
                title="Halaman Sebelumnya"
              >
                <FaChevronLeft size={12} />
              </button>
              {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => (
                <button
                  key={page}
                  type="button"
                  onClick={() => setCurrentPage(page)}
                  className={`w-8 h-8 rounded-lg text-xs font-bold transition ${
                    currentPage === page
                      ? 'bg-primaryBlue text-white shadow-sm'
                      : 'border border-lineGray hover:bg-gray-50 text-slate-700'
                  }`}
                >
                  {page}
                </button>
              ))}
              <button
                type="button"
                onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                className="p-2 rounded-lg border border-lineGray disabled:opacity-30 hover:bg-gray-50 transition text-slate-600"
                title="Halaman Selanjutnya"
              >
                <FaChevronRight size={12} />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
