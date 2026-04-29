import apiClient from './axios'

export const getAllMeasurements = () => apiClient.get('/measurements')

export const getPatientMeasurements = (patientId, limit = 20) =>
  apiClient.get(`/patients/${patientId}/measurements?limit=${limit}`)

export const getLatestMeasurement = (patientId) =>
  apiClient.get(`/patients/${patientId}/latest`)

export const addMeasurement = (data) => apiClient.post('/measurements', data)