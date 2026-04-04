import { createViteConfig } from '../../vite.config.shared.js';

export default createViteConfig({
  mode: 'lib',
  external: [
    /^node:/,
    'child_process',
    'util',
    '@nixcord/ast',
    '@nixcord/git-analyzer',
    '@nixcord/shared',
    'fast-glob',
    'fs-extra',
    'p-limit',
    'pathe',
    'ts-morph',
    'zod',
  ],
  testTimeout: 20000,
  testPool: 'threads',
});
