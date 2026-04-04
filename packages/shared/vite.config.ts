import { createViteConfig } from '../../vite.config.shared.js';

export default createViteConfig({
  mode: 'lib',
  external: [/^node:/, 'consola', 'zod', 'zod-validation-error'],
});
