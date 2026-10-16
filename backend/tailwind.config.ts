import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          primary: "#0F4C81",
          secondary: "#00B4D8",
          safety: "#15803D",
        },
        surface: {
          bg: "#F8FAFC",
          card: "#FFFFFF",
          dark: "#0B192C",
          muted: "#F1F5F9",
        },
        risk: {
          low: "#16A34A",
          medium: "#EAB308",
          high: "#F97316",
          critical: "#DC2626",
        },
      },
      fontFamily: {
        sans: ["var(--font-sans)", "Inter", "sans-serif"],
        mono: ["var(--font-mono)", "JetBrains Mono", "monospace"],
      },
    },
  },
  plugins: [],
};
export default config;
