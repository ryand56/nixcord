import { createViteConfig } from '../../vite.config.shared.js';

export default createViteConfig({
  mode: 'lib',
  external: [/^node:/, 'consola', 'type-fest', 'zod', 'zod-validation-error'],
});
