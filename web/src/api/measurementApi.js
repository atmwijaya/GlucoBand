import apiClient from './axios'

export const getAllMeasurements = () => apiClient.get('/measurements')

export const getPatientMeasurements = (patientId, limit = 20, date = null) => {
  const url = date
    ? `/patients/${patientId}/measurements?date=${date}`
    : `/patients/${patientId}/measurements?limit=${limit}`
  return apiClient.get(url)
}

export const getPatientMeasurementDates = (patientId) =>
  apiClient.get(`/patients/${patientId}/measurement-dates`)

export const getLatestMeasurement = (patientId) =>
  apiClient.get(`/patients/${patientId}/latest`)

export const addMeasurement = (data) => apiClient.post('/measurements', data)
