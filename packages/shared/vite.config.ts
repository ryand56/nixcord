import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    lib: {
      entry: 'src/index.ts',
      formats: ['es'],
      fileName: 'index',
    },
    outDir: 'dist',
    emptyOutDir: true,
    minify: false,
    sourcemap: true,
    rolldownOptions: {
      external: [/^node:/, 'consola', 'type-fest', 'zod'],
    },
  },
  test: {
    globals: true,
    include: ['tests/**/*.test.ts'],
  },
});
