import { describe, test, expect } from 'vitest';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';
import fse from 'fs-extra';
import { parsePlugins } from '../../src/index.js';
import type { PluginSetting } from '@nixcord/shared';
import { createTsConfig, createPluginFile, createPlugin } from '../helpers/test-utils.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// findPluginSourceFile() is tested indirectly through parseSinglePlugin tests
// No need for separate tests since it's a private function

describe('parseSinglePlugin()', () => {
  test('parses valid plugin', async () => {
    const tempDir = await fse.mkdtemp(join(__dirname, 'test-'));
    try {
      await createPlugin(tempDir, 'valid-plugin', {
        indexContent: `export function definePlugin(definition: { name: string; description: string }) {
          return definition;
        }

        export function definePluginSettings(settings: Record<string, unknown>) {
          return settings;
        }

        export const plugin = definePlugin({
          name: "Valid Plugin",
          description: "A valid test plugin",
        });

        export const settings = definePluginSettings({
          setting: {
            type: "STRING",
            description: "A setting",
            default: "value",
          },
        });`,
      });

      await createTsConfig(tempDir);

      const result = await parsePlugins(tempDir);
      const plugin = result.vencordPlugins['Valid Plugin'];
      expect(plugin).toBeDefined();
      expect(plugin?.settings.setting).toBeDefined();
    } finally {
      await fse.remove(tempDir);
    }
  });

  test('handles missing source file', async () => {
    const tempDir = await fse.mkdtemp(join(__dirname, 'test-'));
    try {
      const pluginsDir = join(tempDir, 'src', 'plugins');
      const pluginDir = join(pluginsDir, 'missing-plugin');
      await fse.ensureDir(pluginDir);
      // Don't create index.ts

      await createTsConfig(tempDir);

      const result = await parsePlugins(tempDir);
      // Plugin without source file should not be in results
      expect(result.vencordPlugins['missing-plugin']).toBeUndefined();
    } finally {
      await fse.remove(tempDir);
    }
  });

  test('handles missing plugin name', async () => {
    const tempDir = await fse.mkdtemp(join(__dirname, 'test-'));
    try {
      await createPlugin(tempDir, 'no-name-plugin', {
        indexContent: `export function definePluginSettings(settings: Record<string, unknown>) {
          return settings;
        }

        export const settings = definePluginSettings({
          setting: {
            type: "STRING",
            description: "A setting",
          },
        });`,
      });

      await createTsConfig(tempDir);

      const result = await parsePlugins(tempDir);
      // Plugin name should be derived from directory name
      const plugin = result.vencordPlugins['NoNamePlugin'];
      expect(plugin).toBeDefined();
    } finally {
      await fse.remove(tempDir);
    }
  });

  test('handles plugin without settings', async () => {
    const tempDir = await fse.mkdtemp(join(__dirname, 'test-'));
    try {
      await createPlugin(tempDir, 'no-settings-plugin', {
        indexContent: `export function definePlugin(definition: { name: string; description: string }) {
          return definition;
        }

        export const plugin = definePlugin({
          name: "No Settings Plugin",
          description: "A plugin without settings",
        });`,
      });

      await createTsConfig(tempDir);

      const result = await parsePlugins(tempDir);
      const plugin = result.vencordPlugins['No Settings Plugin'];
      expect(plugin).toBeDefined();
      expect(plugin?.settings).toEqual({});
    } finally {
      await fse.remove(tempDir);
    }
  });

  test('handles settings in separate settings.ts file', async () => {
    const tempDir = await fse.mkdtemp(join(__dirname, 'test-'));
    try {
      await createPlugin(tempDir, 'test-plugin-settings-file', {
        indexContent: `import definePlugin from "@utils/types";

        export default definePlugin({
          name: "Test Plugin With Separate Settings",
          description: "Plugin with settings in separate file",
        });`,
        settingsContent: `import { definePluginSettings } from "@api/Settings";
        import { OptionType } from "@utils/types";

        export default definePluginSettings({
          enabled: {
            type: OptionType.BOOLEAN,
            description: "Enable the feature",
            default: true,
          },
          message: {
            type: OptionType.STRING,
            description: "Message to display",
            default: "Hello from settings file",
          },
        });`,
      });

      await createTsConfig(tempDir);

      const result = await parsePlugins(tempDir);
      const plugin = result.vencordPlugins['Test Plugin With Separate Settings'];
      expect(plugin).toBeDefined();
      expect(plugin?.settings.enabled).toBeDefined();
      expect(plugin?.settings.message).toBeDefined();
      expect((plugin?.settings.enabled as PluginSetting).name).toBe('enabled');
      expect((plugin?.settings.message as PluginSetting).name).toBe('message');
    } finally {
      await fse.remove(tempDir);
    }
  });
});
