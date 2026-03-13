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
        banner: 'import { fileURLToPath as __fileURLToPath } from "node:url"; import { dirname as __pathDirname } from "node:path"; const __filename = __fileURLToPath(import.meta.url); const __dirname = __pathDirname(__filename);',
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
