import apiClient from './axios'

export const getFaqs = () => apiClient.get('/faq')

export const createFaq = (data) => apiClient.post('/faq', data)

export const updateFaq = (id, data) => apiClient.put(`/faq/${id}`, data)

export const deleteFaq = (id) => apiClient.delete(`/faq/${id}`)