export default function LoadingSkeleton({ rows = 4 }) {
  return (
    <div className="space-y-3 animate-pulse">
      {[...Array(rows)].map((_, i) => (
        <div key={i} className="flex items-center gap-4 p-4 bg-white rounded-xl shadow-sm">
          <div className="w-10 h-10 rounded-full bg-gray-200" />
          <div className="flex-1 space-y-2">
            <div className="h-4 w-32 bg-gray-200 rounded" />
            <div className="h-3 w-48 bg-gray-100 rounded" />
          </div>
        </div>
      ))}
    </div>
  )
}