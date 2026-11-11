import apiClient from './axios'

export const getTenagaMedis = () =>
  apiClient.get('/tenaga-medis')

export const createTenagaMedis = (data) =>
  apiClient.post('/tenaga-medis', data)

export const updateTenagaMedis = (id, data) =>
  apiClient.put(`/tenaga-medis/${id}`, data)

export const deleteTenagaMedis = (id) =>
  apiClient.delete(`/tenaga-medis/${id}`)

export const assignPasienToTenagaMedis = (data) =>
  apiClient.post('/tenaga-medis/assign', data)

export const getMedicalStaff = getTenagaMedis
export const createMedicalStaff = createTenagaMedis
export const updateMedicalStaff = updateTenagaMedis
export const deleteMedicalStaff = deleteTenagaMedis
export const assignPatientToStaff = assignPasienToTenagaMedis

export default {
  getTenagaMedis,
  createTenagaMedis,
  updateTenagaMedis,
  deleteTenagaMedis,
  assignPasienToTenagaMedis
}
