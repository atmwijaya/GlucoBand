import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { FiEye, FiEyeOff } from "react-icons/fi";
import { login } from "../api/authApi";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const response = await login(email, password);
      const { token, user } = response.data;

      if (user.role !== "tenaga_medis") {
        setError("Hanya tenaga medis yang dapat mengakses dashboard ini.");
        return;
      }

      sessionStorage.setItem("token", token);
      sessionStorage.setItem("user", JSON.stringify(user));
      navigate("/admin/dashboard", { replace: true });
    } catch (err) {
      console.error("Login error:", err);
      setError("Email atau password salah.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center p-6">
      <div className="w-full max-w-md">
        {/* Logo & Brand */}
        <div className="flex flex-col items-center mb-10">
          <img
            src="/icons/icon-192x192.png"
            alt="GlucoBand"
            className="w-20 h-20 mb-4 rounded-2xl shadow-md"
          />
          <h1 className="text-3xl font-bold text-darkNavy">
            Gluco<span className="text-primaryBlue">Band</span>
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

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Email */}
            <div>
              <label className="block text-sm font-medium text-textPrimary mb-1.5">
                Email
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="w-full px-4 py-3 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue focus:border-transparent transition-all"
                placeholder="email@home.id"
              />
            </div>

            {/* Password */}
            <div>
              <label className="block text-sm font-medium text-textPrimary mb-1.5">
                Password
              </label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="w-full px-4 py-3 border border-lineGray rounded-lg pr-12 focus:outline-none focus:ring-2 focus:ring-primaryBlue focus:border-transparent transition-all"
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