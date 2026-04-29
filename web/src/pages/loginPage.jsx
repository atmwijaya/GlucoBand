import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { FiEye, FiEyeOff } from 'react-icons/fi'
import { login } from '../api/authApi'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const response = await login(email, password)
      console.log('Response data:', response.data) 
      const { token, user } = response.data
      if (user.role !== 'tenaga_medis') {
        setError('Hanya tenaga medis yang dapat mengakses dashboard ini.')
        return
      }
      sessionStorage.setItem('token', token)
      sessionStorage.setItem('user', JSON.stringify(user))
      navigate('/admin/dashboard', { replace: true })
    } catch {
      console.error('Login error:', err)
      setError('Email atau password salah.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex">
      <div className="hidden lg:flex w-1/2 bg-gradient-to-br from-darkNavy via-primaryDark to-primaryBlue items-center justify-center relative overflow-hidden">
        <div className="absolute top-20 left-20 w-64 h-64 bg-white/10 rounded-full blur-3xl" />
        <div className="absolute bottom-20 right-20 w-96 h-96 bg-white/5 rounded-full blur-3xl" />
        <div className="relative z-10 text-center px-12">
          <img src="/icons/icon-192x192.png" alt="GlucoBand" className="w-24 h-24 mx-auto mb-6 rounded-2xl shadow-lg" />
          <h1 className="text-5xl font-bold text-white mb-4">Gluco<span className="text-blue-300">Band</span></h1>
          <p className="text-lg text-slate-300 mb-8">Dashboard pemantauan gula darah non‑invasif untuk tenaga medis.</p>
          <div className="w-24 h-0.5 bg-blue-400/50 mx-auto mb-6" />
          <p className="text-sm text-slate-400">Pantau pasien Anda secara real‑time, kapan saja.</p>
        </div>
      </div>

      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-md">
          <div className="lg:hidden text-center mb-8">
            <img src="/icons/icon-192x192.png" alt="GlucoBand" className="w-16 h-16 mx-auto mb-3 rounded-xl" />
            <h1 className="text-2xl font-bold text-darkNavy">GlucoBand Medic</h1>
          </div>
          <h2 className="text-2xl font-bold text-darkNavy mb-2">Selamat Datang</h2>
          <p className="text-sm text-textSecondary mb-8">Silakan login untuk mengakses dashboard tenaga medis.</p>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-textPrimary mb-1.5">Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
                className="w-full px-4 py-3 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue focus:border-transparent transition-all"
                placeholder="medis@glucoband.id" />
            </div>
            <div>
              <label className="block text-sm font-medium text-textPrimary mb-1.5">Password</label>
              <div className="relative">
                <input type={showPassword ? 'text' : 'password'} value={password} onChange={e => setPassword(e.target.value)} required
                  className="w-full px-4 py-3 border border-lineGray rounded-lg pr-12 focus:outline-none focus:ring-2 focus:ring-primaryBlue focus:border-transparent transition-all"
                  placeholder="••••••••" />
                <button type="button" onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 flex items-center pr-4 text-gray-500 hover:text-primaryBlue">
                  {showPassword ? <FiEyeOff /> : <FiEye />}
                </button>
              </div>
            </div>

            {error && (
              <div className="p-3 bg-red-50 border border-red-200 text-red-600 text-sm rounded-lg">{error}</div>
            )}

            <button type="submit" disabled={loading}
              className="w-full py-3 bg-primaryBlue text-white font-medium rounded-lg hover:bg-blue-600 transition disabled:opacity-50">
              {loading ? 'Memproses...' : 'Login'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}