import { createContext, useContext } from 'react';

export const STORAGE_KEY = 'adminTheme';

export const ThemeContext = createContext(null);

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme phải nằm trong <ThemeProvider>');
  return ctx;
}
