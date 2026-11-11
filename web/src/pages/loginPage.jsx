import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { FiEye, FiEyeOff } from "react-icons/fi";
import { login } from "../api/authApi";
import logoImg from "../assets/android-chrome-512x512.png";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [fieldErrors, setFieldErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    const newErrors = {};
    if (!email.trim()) {
      newErrors.email = "Email wajib diisi.";
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      newErrors.email = "Format email tidak valid.";
    }
    if (!password) {
      newErrors.password = "Password wajib diisi.";
    }

    if (Object.keys(newErrors).length > 0) {
      setFieldErrors(newErrors);
      return;
    }

    setFieldErrors({});
    setError("");
    setLoading(true);

    try {
      const response = await login(email, password);
      const { token, access_token, refresh_token, user } = response.data;

      if (user.role !== "tenaga_medis") {
        setError("Hanya tenaga medis yang dapat mengakses dashboard ini.");
        return;
      }

      const activeToken = access_token || token;
      sessionStorage.setItem("token", activeToken);
      if (refresh_token) {
        sessionStorage.setItem("refresh_token", refresh_token);
      }
      sessionStorage.setItem("user", JSON.stringify(user));
      navigate("/admin/dashboard", { replace: true });
    } catch (err) {
      console.error("Login error:", err);
      const serverMsg = err.response?.data?.msg || err.response?.data?.message;
      setError(serverMsg || "Email atau password salah.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center p-6">
      <div className="w-full max-w-md">
        {/* Logo & Brand */}
        <div className="flex flex-col items-center mb-8">
          <div className="w-24 h-24 mb-3 rounded-2xl bg-white shadow-md p-3 flex items-center justify-center border border-slate-100">
            <img
              src={logoImg}
              alt="GlucoBand Logo"
              className="w-full h-full object-contain"
            />
          </div>
          <h1 className="text-3xl font-bold text-darkNavy tracking-tight">
            Gluco<span className="text-[#613EEA]">Band</span>
          </h1>
        </div>

        {/* Login Card */}
        <div className="bg-white rounded-2xl shadow-xl border border-lineGray p-8 md:p-10">
          <div className="mb-8">
            <h2 className="text-2xl font-semibold text-darkNavy text-center">
              Selamat Datang
            </h2>
            <p className="text-textSecondary text-center mt-2 text-sm">
              Masuk ke akun tenaga medis Anda
            </p>
          </div>

          <form onSubmit={handleSubmit} noValidate className="space-y-6">
            {/* Email */}
            <div>
              <label className="block text-sm font-medium text-textPrimary mb-1.5">
                Email <span className="text-red-500">*</span>
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value)
                  if (fieldErrors.email) setFieldErrors(prev => ({ ...prev, email: "" }))
                }}
                className={`w-full px-4 py-3 border rounded-lg focus:outline-none transition-all ${
                  fieldErrors.email
                    ? "border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200"
                    : "border-lineGray focus:ring-2 focus:ring-primaryBlue focus:border-transparent"
                }`}
                placeholder="email@home.id"
              />
              {fieldErrors.email && (
                <p className="text-xs text-red-500 mt-1 font-medium">{fieldErrors.email}</p>
              )}
            </div>

            {/* Password */}
            <div>
              <label className="block text-sm font-medium text-textPrimary mb-1.5">
                Password <span className="text-red-500">*</span>
              </label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value)
                    if (fieldErrors.password) setFieldErrors(prev => ({ ...prev, password: "" }))
                  }}
                  className={`w-full px-4 py-3 border rounded-lg pr-12 focus:outline-none transition-all ${
                    fieldErrors.password
                      ? "border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200"
                      : "border-lineGray focus:ring-2 focus:ring-primaryBlue focus:border-transparent"
                  }`}
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 flex items-center pr-4 text-gray-500 hover:text-primaryBlue"
                >
                  {showPassword ? <FiEyeOff size={20} /> : <FiEye size={20} />}
                </button>
              </div>
              {fieldErrors.password && (
                <p className="text-xs text-red-500 mt-1 font-medium">{fieldErrors.password}</p>
              )}
            </div>

            {/* Error Message */}
            {error && (
              <div className="p-3 bg-red-50 border border-red-200 text-red-600 text-sm rounded-lg">
                {error}
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full py-3.5 bg-primaryBlue text-white font-medium rounded-lg hover:bg-blue-600 transition-all disabled:opacity-50 text-base"
            >
              {loading ? "Memproses..." : "Login"}
            </button>
          </form>
        </div>

        {/* Footer */}
        <p className="text-center text-textSecondary text-xs mt-8">
          © 2026 GlucoBand
        </p>
      </div>
    </div>
  );
}