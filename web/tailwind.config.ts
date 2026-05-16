import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: "#097456",
        secondary: "#FFB27E",
        accent: "#E8D7FF",
      },
    },
  },
  plugins: [],
};
export default config;
