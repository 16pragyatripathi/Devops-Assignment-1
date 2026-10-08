import { defineConfig } from "vite";

// During `npm run dev` the browser calls /api on the Vite server, which forwards to FastAPI.
export default defineConfig({
  server: { port: 5173, proxy: { "/api": "http://localhost:8000" } },
});
