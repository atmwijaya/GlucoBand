import apiClient from './axios'

export const getTrendPrediction = (patientId) =>
  apiClient.get(`/predictions/trend/${patientId}`)

export const getRiskPrediction = (patientId) =>
  apiClient.get(`/predictions/risk/${patientId}`)