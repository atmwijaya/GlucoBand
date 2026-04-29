import { useState } from 'react'
import { FaChevronLeft, FaChevronRight } from 'react-icons/fa'

export default function Calendar() {
  const [currentMonth, setCurrentMonth] = useState(new Date().getMonth())
  const [currentYear, setCurrentYear] = useState(new Date().getFullYear())

  const monthNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

  const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate()
  const firstDay = new Date(currentYear, currentMonth, 1).getDay()
  const startOffset = firstDay === 0 ? 6 : firstDay - 1
  const today = new Date()

  const isToday = (day) =>
    day === today.getDate() && currentMonth === today.getMonth() && currentYear === today.getFullYear()

  const prevMonth = () => {
    if (currentMonth === 0) { setCurrentMonth(11); setCurrentYear(y => y - 1) }
    else setCurrentMonth(m => m - 1)
  }

  const nextMonth = () => {
    if (currentMonth === 11) { setCurrentMonth(0); setCurrentYear(y => y + 1) }
    else setCurrentMonth(m => m + 1)
  }

  const dayHeaders = ['S', 'S', 'R', 'K', 'J', 'S', 'M']

  return (
    <div className="bg-white rounded-xl shadow-sm p-5">
      <div className="flex justify-between items-center mb-4">
        <button onClick={prevMonth} className="text-gray-400 hover:text-primaryBlue"><FaChevronLeft /></button>
        <h3 className="font-semibold">{monthNames[currentMonth]} {currentYear}</h3>
        <button onClick={nextMonth} className="text-gray-400 hover:text-primaryBlue"><FaChevronRight /></button>
      </div>
      <div className="grid grid-cols-7 gap-1">
        {dayHeaders.map((d, i) => (
          <div key={i} className="text-center text-xs font-medium text-gray-400 py-1">{d}</div>
        ))}
        {Array.from({ length: startOffset }).map((_, i) => <div key={`empty-${i}`} className="py-1" />)}
        {Array.from({ length: daysInMonth }, (_, i) => {
          const day = i + 1
          return (
            <div
              key={day}
              className={`text-center text-sm py-1 rounded-full ${
                isToday(day) ? 'bg-primaryBlue text-white font-bold' : 'hover:bg-blue-50'
              }`}
            >
              {day}
            </div>
          )
        })}
      </div>
    </div>
  )
}