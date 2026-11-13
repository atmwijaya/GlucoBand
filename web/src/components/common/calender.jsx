import { useState, useEffect } from 'react'
import { FaChevronLeft, FaChevronRight } from 'react-icons/fa'

export default function Calendar({ selectedDate = new Date(), onSelectDate, markedDates = [] }) {
  const [currentMonth, setCurrentMonth] = useState(() => (selectedDate ? selectedDate.getMonth() : new Date().getMonth()))
  const [currentYear, setCurrentYear] = useState(() => (selectedDate ? selectedDate.getFullYear() : new Date().getFullYear()))

  useEffect(() => {
    if (selectedDate) {
      setCurrentMonth(selectedDate.getMonth())
      setCurrentYear(selectedDate.getFullYear())
    }
  }, [selectedDate])

  const monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ]

  const today = new Date()
  const todayYear = today.getFullYear()
  const todayMonth = today.getMonth()
  const todayDate = today.getDate()
  const todayStart = new Date(todayYear, todayMonth, todayDate).getTime()

  const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate()
  const firstDay = new Date(currentYear, currentMonth, 1).getDay()
  const startOffset = firstDay === 0 ? 6 : firstDay - 1

  const isToday = (day) =>
    day === todayDate && currentMonth === todayMonth && currentYear === todayYear

  const isSelected = (day) => {
    if (!selectedDate) return false
    return (
      day === selectedDate.getDate() &&
      currentMonth === selectedDate.getMonth() &&
      currentYear === selectedDate.getFullYear()
    )
  }

  // Cek apakah tanggal berada di masa depan (besok dan seterusnya)
  const isFuture = (day) => {
    const dayTime = new Date(currentYear, currentMonth, day).getTime()
    return dayTime > todayStart
  }

  // Cek apakah bulan saat ini adalah bulan sekarang atau lebih baru (untuk menonaktifkan navigasi ke bulan masa depan)
  const isCurrentOrFutureMonth =
    currentYear > todayYear || (currentYear === todayYear && currentMonth >= todayMonth)

  const prevMonth = () => {
    if (currentMonth === 0) {
      setCurrentMonth(11)
      setCurrentYear((y) => y - 1)
    } else {
      setCurrentMonth((m) => m - 1)
    }
  }

  const nextMonth = () => {
    if (isCurrentOrFutureMonth) return
    if (currentMonth === 11) {
      setCurrentMonth(0)
      setCurrentYear((y) => y + 1)
    } else {
      setCurrentMonth((m) => m + 1)
    }
  }

  const goToToday = () => {
    const now = new Date()
    setCurrentMonth(now.getMonth())
    setCurrentYear(now.getFullYear())
    onSelectDate?.(now)
  }

  const markedSet = new Set(
    markedDates.map((d) => (typeof d === 'string' ? d : d.toISOString().split('T')[0]))
  )

  const dayHeaders = ['S', 'S', 'R', 'K', 'J', 'S', 'M']

  return (
    <div className="bg-white rounded-xl shadow-sm p-5 border border-slate-100 flex flex-col justify-between">
      <div>
        <div className="flex justify-between items-center mb-3">
          <button
            type="button"
            onClick={prevMonth}
            className="p-1.5 rounded-lg text-gray-400 hover:text-primaryBlue hover:bg-blue-50 transition cursor-pointer"
            title="Bulan Sebelumnya"
          >
            <FaChevronLeft size={12} />
          </button>
          <div className="text-center">
            <h3 className="font-bold text-slate-800 text-sm">
              {monthNames[currentMonth]} {currentYear}
            </h3>
          </div>
          <button
            type="button"
            onClick={nextMonth}
            disabled={isCurrentOrFutureMonth}
            className={`p-1.5 rounded-lg transition ${
              isCurrentOrFutureMonth
                ? 'text-gray-200 cursor-not-allowed'
                : 'text-gray-400 hover:text-primaryBlue hover:bg-blue-50 cursor-pointer'
            }`}
            title={isCurrentOrFutureMonth ? 'Bulan masa depan tidak dapat dipilih' : 'Bulan Berikutnya'}
          >
            <FaChevronRight size={12} />
          </button>
        </div>

        <div className="grid grid-cols-7 gap-1 mb-1">
          {dayHeaders.map((d, i) => (
            <div key={i} className="text-center text-xs font-semibold text-gray-400 py-1">
              {d}
            </div>
          ))}
          {Array.from({ length: startOffset }).map((_, i) => (
            <div key={`empty-${i}`} className="py-1" />
          ))}
          {Array.from({ length: daysInMonth }, (_, i) => {
            const day = i + 1
            const sel = isSelected(day)
            const tod = isToday(day)
            const fut = isFuture(day)
            const dateStr = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
            const hasData = markedSet.has(dateStr)

            if (fut) {
              return (
                <button
                  key={day}
                  type="button"
                  disabled
                  className="relative flex flex-col items-center justify-center h-8 rounded-lg text-xs text-slate-300 bg-transparent cursor-not-allowed select-none"
                  title="Tanggal masa depan tidak dapat dipilih"
                >
                  <span>{day}</span>
                </button>
              )
            }

            return (
              <button
                key={day}
                type="button"
                onClick={() => onSelectDate?.(new Date(currentYear, currentMonth, day))}
                className={`relative flex flex-col items-center justify-center h-8 rounded-lg text-xs transition cursor-pointer ${
                  sel
                    ? 'bg-primaryBlue text-white font-bold shadow-sm'
                    : tod
                    ? 'border-2 border-primaryBlue text-primaryBlue font-bold hover:bg-blue-50'
                    : 'text-slate-700 hover:bg-slate-100'
                }`}
              >
                <span>{day}</span>
                {hasData && (
                  <span
                    className={`absolute bottom-0.5 w-1.5 h-1.5 rounded-full ${
                      sel ? 'bg-white' : 'bg-emerald-500'
                    }`}
                  />
                )}
              </button>
            )
          })}
        </div>
      </div>

      <div className="mt-3 pt-3 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
        <div className="flex items-center gap-1.5">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
          <span>Ada aktivitas</span>
        </div>
        <button
          type="button"
          onClick={goToToday}
          className="text-primaryBlue font-semibold hover:underline cursor-pointer"
        >
          Hari Ini
        </button>
      </div>
    </div>
  )
}
