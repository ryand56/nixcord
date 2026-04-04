import { createViteConfig } from '../../vite.config.shared.js';

export default createViteConfig({
  mode: 'lib',
  external: [/^node:/, '@nixcord/ast', '@nixcord/shared', 'change-case'],
  testTimeout: 20000,
  testPool: 'threads',
});
