"use client";

import React, { createContext, useContext, useState, useEffect } from "react";

type Theme = "dark" | "light";
type Language = "en" | "my";

interface ThemeContextType {
  theme: Theme;
  language: Language;
  toggleTheme: () => void;
  setLanguage: (lang: Language) => void;
  t: (en: string, my: string) => string;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>("dark");
  const [language, setLanguageState] = useState<Language>("en");

  useEffect(() => {
    const savedTheme = (localStorage.getItem("admin_theme") as Theme) || "dark";
    const savedLang = (localStorage.getItem("admin_lang") as Language) || "en";
    setTheme(savedTheme);
    setLanguageState(savedLang);

    if (savedTheme === "light") {
      document.documentElement.classList.add("light");
    } else {
      document.documentElement.classList.remove("light");
    }
  }, []);

  const toggleTheme = () => {
    const nextTheme = theme === "dark" ? "light" : "dark";
    setTheme(nextTheme);
    localStorage.setItem("admin_theme", nextTheme);
    if (nextTheme === "light") {
      document.documentElement.classList.add("light");
    } else {
      document.documentElement.classList.remove("light");
    }
  };

  const setLanguage = (lang: Language) => {
    setLanguageState(lang);
    localStorage.setItem("admin_lang", lang);
  };

  const t = (en: string, my: string) => (language === "my" ? my : en);

  return (
    <ThemeContext.Provider value={{ theme, language, toggleTheme, setLanguage, t }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
}
