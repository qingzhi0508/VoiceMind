import { defineConfig } from 'vite';

export default defineConfig({
  root: 'src',
  build: {
    outDir: '../src',
    emptyOutDir: true,
  },
  server: {
    port: 5173,
  },
});
