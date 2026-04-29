import apiClient from './axios'

export const addRecommendation = (patientId, content) =>
  apiClient.post(`/patients/${patientId}/recommendations`, { content })