import apiClient from './axios'

export const getNotifications = () => apiClient.get('/notifications')