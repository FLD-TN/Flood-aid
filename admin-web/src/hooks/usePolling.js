import { useState, useEffect, useRef, useCallback } from 'react';
import api from '../api';

/**
 * Polling dùng chung.
 *
 * Dùng axios instance ở ../api để mọi request tự đính JWT admin — các endpoint
 * /api/admin/* có adminAuthMiddleware, gọi bằng axios thô sẽ luôn nhận 401.
 *
 * @param {string} path        đường dẫn API
 * @param {number} intervalMs  chu kỳ poll (mặc định 15s)
 */
export function usePolling(path, intervalMs = 15000) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);
  const timerRef = useRef(null);

  const fetchData = useCallback(async () => {
    try {
      const res = await api.get(path);
      setData(res.data);
      setError(null);
    } catch (err) {
      setError(err.response?.data?.error || err.message);
    } finally {
      setLoading(false);
    }
  }, [path]);

  useEffect(() => {
    fetchData();

    const start = () => {
      clearInterval(timerRef.current);
      timerRef.current = setInterval(fetchData, intervalMs);
    };
    const stop = () => clearInterval(timerRef.current);

    // Tab ẩn thì ngừng poll, hiện lại thì fetch ngay rồi poll tiếp
    const onVisibility = () => {
      if (document.hidden) {
        stop();
      } else {
        fetchData();
        start();
      }
    };

    if (!document.hidden) start();
    document.addEventListener('visibilitychange', onVisibility);

    return () => {
      stop();
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [fetchData, intervalMs]);

  return { data, error, loading, refresh: fetchData };
}
