import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    ssr: 'src/index.ts',
    outDir: 'dist',
    emptyOutDir: true,
    minify: false,
    sourcemap: true,
    rolldownOptions: {
      output: {
        format: 'esm',
        entryFileNames: 'index.js',
      },
    },
  },
  ssr: {
    target: 'node',
    external: [
      '@nixcord/git-analyzer',
      '@nixcord/nix-generator',
      '@nixcord/parser',
      '@nixcord/shared',
    ],
  },
  test: {
    globals: true,
    include: ['tests/**/*.test.ts'],
    testTimeout: 20000,
    maxWorkers: 4,
    pool: 'forks',
  },
});
