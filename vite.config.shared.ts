import { defineConfig, type UserConfig } from 'vite';

type ViteConfigOptions = {
  mode: 'lib' | 'ssr';
  external: (string | RegExp)[];
  banner?: string;
  testTimeout?: number;
  testPool?: 'threads' | 'forks';
  testIsolate?: boolean;
  coverage?: UserConfig['test'] extends object ? UserConfig['test']['coverage'] : never;
};

export function createViteConfig(options: ViteConfigOptions): UserConfig {
  const { mode, external, banner, testTimeout, testPool, testIsolate, coverage } = options;

  const build: UserConfig['build'] =
    mode === 'ssr'
      ? {
          ssr: 'src/index.ts',
          outDir: 'dist',
          emptyOutDir: true,
          minify: false,
          sourcemap: true,
          rolldownOptions: {
            output: {
              format: 'esm',
              entryFileNames: 'index.js',
              ...(banner ? { banner } : {}),
            },
          },
        }
      : {
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
            external,
          },
        };

  const test: UserConfig['test'] = {
    globals: true,
    include: ['tests/**/*.test.ts'],
    ...(testTimeout !== undefined ? { testTimeout } : {}),
    ...(testPool !== undefined ? { pool: testPool } : {}),
    ...(testIsolate !== undefined ? { isolate: testIsolate } : {}),
    ...(coverage !== undefined ? { coverage } : {}),
  };

  return defineConfig({
    build,
    ...(mode === 'ssr' ? { ssr: { target: 'node', external } } : {}),
    test,
  });
}
