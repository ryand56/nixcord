import { createViteConfig } from '../../vite.config.shared.js';

export default createViteConfig({
  mode: 'lib',
  external: [/^node:/, '@nixcord/shared', 'ts-morph'],
  testTimeout: 20000,
  testPool: 'threads',
  testIsolate: false,
  coverage: {
    provider: 'v8',
    reporter: ['text', 'json', 'html'],
    exclude: [
      'src/navigator/index.ts',
      'src/extractor/select/default/index.ts',
      'src/extractor/select/index.ts',
      'src/extractor/select/options/index.ts',
      'src/extractor/select/patterns/index.ts',
      'src/extractor/type-inference/index.ts',
      'src/extractor/constants.ts',
      'src/extractor/types.ts',
      'src/extractor/type-helpers.ts',
      'src/extractor/type-inference/types.ts',
      '**/*.test.ts',
      '**/dist/**',
    ],
  },
});
