export { createProject } from './project.js';
export { parsePlugins } from './parse-plugins.js';
export type { ParsePluginsOptions } from './parse-plugins.js';
export {
  extractMigrations,
  updateDeprecatedPlugins,
  type DeprecatedData,
  type DeprecatedRenameEntry,
  type DeprecatedRemovalEntry,
} from './migrations.js';
export { categorizePlugins } from './categorize.js';
export type { PluginSource } from './plugin-source.js';
export { createVencordSource, createEquicordSource } from './plugin-source.js';
