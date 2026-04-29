import apiClient from './axios'

export const login = (email, password) =>
  apiClient.post('/auth/login', { email, password })

export const registerPasien = (data) =>
  apiClient.post('/auth/register/pasien', data)