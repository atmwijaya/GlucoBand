import { useState, useEffect, useRef } from 'react'

export default function CircularGauge({ value, maxValue, label, unit }) {
  const [animatedValue, setAnimatedValue] = useState(0)
  const frameRef = useRef()

  useEffect(() => {
    let startTime = null
    const startValue = animatedValue
    const diff = value - startValue
    const duration = 600

    const animate = (timestamp) => {
      if (!startTime) startTime = timestamp
      const progress = Math.min((timestamp - startTime) / duration, 1)
      const eased = 1 - Math.pow(1 - progress, 3)
      setAnimatedValue(startValue + diff * eased)
      if (progress < 1) frameRef.current = requestAnimationFrame(animate)
    }
    frameRef.current = requestAnimationFrame(animate)
    return () => cancelAnimationFrame(frameRef.current)
  }, [value])

  const percentage = (Math.min(animatedValue, maxValue) / maxValue) * 100
  const radius = 42
  const circumference = 2 * Math.PI * radius
  const offset = circumference - (percentage / 100) * circumference

  const getColor = () => {
    if (value > 200) return '#EF4444'
    if (value < 70) return '#F59E0B'
    return '#10B981'
  }

  return (
    <div className="flex flex-col items-center">
      <svg width="120" height="120" className="transform -rotate-90">
        <circle cx="60" cy="60" r={radius} fill="none" stroke="#E2E8F0" strokeWidth="8" />
        <circle
          cx="60" cy="60" r={radius} fill="none" stroke={getColor()} strokeWidth="8"
          strokeLinecap="round" strokeDasharray={circumference} strokeDashoffset={offset}
          className="transition-all duration-300"
        />
      </svg>
      <div className="text-center -mt-20 mb-4">
        <p className="text-2xl font-bold" style={{ color: getColor() }}>{Math.round(animatedValue)}</p>
        <p className="text-xs text-textSecondary">{unit}</p>
      </div>
      <p className="text-sm font-medium text-textSecondary">{label}</p>
    </div>
  )
}