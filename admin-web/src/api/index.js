import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3000';

const api = axios.create({
  baseURL: API_BASE,
  timeout: 10000,
});

// Tự động đính JWT admin token vào mọi request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('adminToken');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// 401 → xóa token, reload về trang login
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('adminToken');
      localStorage.removeItem('adminInfo');
      window.location.reload();
    }
    return Promise.reject(err);
  }
);

// SOS Cases
export const getCaseClusters = () => api.get('/api/admin/case-clusters');
export const getAllCases = (status) => api.get('/api/admin/cases', { params: { status } });
export const getDashboardStats = () => api.get('/api/admin/stats');
export const resolveCase = (id, resolvedBy = 'admin') => api.post(`/api/case/${id}/resolve`, { resolvedBy });

// Volunteers
export const getVolunteerLocations = () => api.get('/api/volunteers/locations');
export const getVolunteers = () => api.get('/api/volunteers');
export const approveVolunteer = (id, approved) => api.put(`/api/volunteers/${id}/approve`, { approved });

// Từ điển phương ngữ (override)
export const getDialectDict = () => api.get('/api/dialect-dict');
export const addDialectTerm = (dialect, standard) => api.post('/api/dialect-dict', { dialect, standard });
export const removeDialectTerm = (dialect) => api.delete('/api/dialect-dict', { data: { dialect } });

export default api;
