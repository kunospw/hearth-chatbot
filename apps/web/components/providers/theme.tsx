"use client";

import { createContext, useContext, useEffect, useState } from "react";

// Theme choice, applied as data-theme on <html> (globals.css maps each value to
// a palette). Mirrors HearthThemeChoice (Dark / True black / Light / System).

export type ThemeChoice = "dark" | "true-black" | "light" | "system";

const STORAGE_KEY = "hearth-theme";

interface ThemeContextValue {
  choice: ThemeChoice;
  setChoice: (c: ThemeChoice) => void;
}

const ThemeContext = createContext<ThemeContextValue>({
  choice: "dark",
  setChoice: () => {},
});

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [choice, setChoice] = useState<ThemeChoice>("dark");

  // Load the saved choice on mount (SSR renders the default dark palette).
  useEffect(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY) as ThemeChoice | null;
      if (saved) setChoice(saved);
    } catch {
      /* storage unavailable */
    }
  }, []);

  useEffect(() => {
    document.documentElement.dataset.theme = choice;
    try {
      localStorage.setItem(STORAGE_KEY, choice);
    } catch {
      /* storage unavailable */
    }
  }, [choice]);

  return (
    <ThemeContext.Provider value={{ choice, setChoice }}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => useContext(ThemeContext);
