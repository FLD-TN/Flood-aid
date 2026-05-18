import { useState, useEffect, useRef, useCallback } from 'react';
import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3000';

/**
 * Universal polling hook
 * @param {string} path - API endpoint path
 * @param {number} intervalMs - polling interval (mặc định 15s)
 */
export function usePolling(path, intervalMs = 15000) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);
  const timerRef = useRef(null);

  const fetchData = useCallback(async () => {
    try {
      const res = await axios.get(`${API_BASE}${path}`);
      setData(res.data);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [path]);

  useEffect(() => {
    fetchData();
    timerRef.current = setInterval(fetchData, intervalMs);
    return () => clearInterval(timerRef.current);
  }, [fetchData, intervalMs]);

  return { data, error, loading, refresh: fetchData };
}
