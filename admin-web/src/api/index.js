import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3000';

const api = axios.create({
  baseURL: API_BASE,
  timeout: 10000,
});

// SOS Cases
export const getCaseClusters = () => api.get('/api/admin/case-clusters');
export const getAllCases = (status) => api.get('/api/admin/cases', { params: { status } });
export const getDashboardStats = () => api.get('/api/admin/stats');
export const resolveCase = (id, resolvedBy = 'admin') => api.post(`/api/case/${id}/resolve`, { resolvedBy });

// Volunteers
export const getVolunteerLocations = () => api.get('/api/volunteers/locations');
export const getVolunteers = () => api.get('/api/volunteers');
export const approveVolunteer = (id, approved) => api.put(`/api/volunteers/${id}/approve`, { approved });

export default api;
