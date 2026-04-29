import { Navigate, Outlet } from 'react-router-dom'

export default function ProtectedRoute({ allowedRoles }) {
  const token = sessionStorage.getItem('token')
  const user = JSON.parse(sessionStorage.getItem('user'))

  if (!token || !user) {
    return <Navigate to="/login" replace />
  }

  if (!allowedRoles.includes(user.role)) {
    sessionStorage.clear()
    return <Navigate to="/login" replace />
  }

  return <Outlet />
}