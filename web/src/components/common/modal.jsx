import { FaCheck, FaTimes, FaExclamationTriangle } from 'react-icons/fa'

export default function ReusableModal({ isOpen, onClose, title, message, type = 'info', onConfirm }) {
  if (!isOpen) return null

  const icons = {
    confirm: { icon: FaExclamationTriangle, color: 'text-warningAmber', bg: 'bg-amber-50', border: 'border-amber-200' },
    success: { icon: FaCheck, color: 'text-successGreen', bg: 'bg-green-50', border: 'border-green-200' },
    error: { icon: FaTimes, color: 'text-errorRed', bg: 'bg-red-50', border: 'border-red-200' }
  }

  const { icon: Icon, color, bg, border } = icons[type] || icons.info

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div onClick={(e) => e.stopPropagation()} className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
        <div className="flex flex-col items-center text-center">
          <div className={`mb-4 p-4 rounded-full ${bg} ${border} border`}>
            <Icon className={`text-3xl ${color}`} />
          </div>
          <h2 className="text-xl font-bold mb-2">{title}</h2>
          <p className="text-sm text-textSecondary mb-6 whitespace-pre-line">{message}</p>
          {type === 'confirm' && (
            <div className="flex gap-3">
              <button onClick={onClose} className="px-5 py-2 rounded-lg border border-lineGray text-textSecondary hover:bg-gray-50 transition">
                Batal
              </button>
              <button onClick={onConfirm} className="px-5 py-2 rounded-lg bg-primaryBlue text-white hover:bg-blue-600 transition">
                Ya, Lanjutkan
              </button>
            </div>
          )}
          {(type === 'success' || type === 'error') && (
            <button onClick={onClose} className="px-5 py-2 rounded-lg bg-primaryBlue text-white hover:bg-blue-600 transition">
              OK
            </button>
          )}
        </div>
      </div>
    </div>
  )
}