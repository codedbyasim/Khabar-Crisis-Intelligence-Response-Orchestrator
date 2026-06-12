import { useEffect, useRef, useCallback } from 'react';

/**
 * Custom hook for polling API endpoints
 * Automatically refetches data at specified intervals
 */
export const usePolling = (fetchFn, interval = 3000) => {
  const intervalIdRef = useRef(null);

  const startPolling = useCallback(() => {
    if (intervalIdRef.current) return; // Already polling

    // Fetch immediately
    fetchFn();

    // Then set up interval
    intervalIdRef.current = setInterval(() => {
      fetchFn();
    }, interval);
  }, [fetchFn, interval]);

  const stopPolling = useCallback(() => {
    if (intervalIdRef.current) {
      clearInterval(intervalIdRef.current);
      intervalIdRef.current = null;
    }
  }, []);

  useEffect(() => {
    startPolling();

    return () => {
      stopPolling();
    };
  }, [startPolling, stopPolling]);

  return { startPolling, stopPolling };
};

export default usePolling;
