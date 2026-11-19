import { defineConfig } from 'vitest/config';

export default defineConfig({
  // Relative asset paths, so the build works from any sub-path.
  base: './',
  server: { port: 5174, strictPort: true },
  build: {
    target: 'es2022',
    rollupOptions: {
      input: { main: 'index.html', 'how-it-works': 'how-it-works.html' },
    },
  },
});
