import { createViteConfig } from '../../vite.config.shared.js';

export default createViteConfig({
  mode: 'lib',
  external: [/^node:/, '@nixcord/ast', '@nixcord/shared', 'change-case', 'type-fest'],
  testTimeout: 20000,
  testPool: 'threads',
});
