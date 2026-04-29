export default function StatCard({ title, value, icon: Icon, color = 'text-primaryBlue', loading = false }) {
  if (loading) {
    return (
      <div className="bg-white rounded-xl shadow-sm p-6 animate-pulse">
        <div className="h-4 w-24 bg-gray-200 rounded mb-3" />
        <div className="h-8 w-16 bg-gray-200 rounded" />
      </div>
    )
  }

  return (
    <div className="bg-white rounded-xl shadow-sm p-6 hover:shadow-md transition-shadow duration-300">
      <div className="flex items-center justify-between mb-3">
        <p className="text-sm text-textSecondary">{title}</p>
        {Icon && <Icon className={`text-xl ${color}`} />}
      </div>
      <p className={`text-3xl font-bold ${color}`}>
        {typeof value === 'number' ? value.toLocaleString() : value}
      </p>
    </div>
  )
}