import type { ReadonlyDeep, PluginConfig, DeprecatedData } from '@nixcord/shared';
import { AUTO_GENERATED_HEADER, isNestedConfig, sortedEntries } from '@nixcord/shared';
import { toNixIdentifier } from './identifier.js';

const BASE_PATH = '["programs" "nixcord" "config" "plugins"';

/**
 * Collect all leaf setting names from a plugin config (flattened).
 * Always includes "enable".
 */
function collectSettingNames(config: ReadonlyDeep<PluginConfig>): string[] {
  const names = new Set<string>();
  names.add('enable');

  for (const [, setting] of Object.entries(config.settings)) {
    if (isNestedConfig(setting)) {
      for (const nestedName of collectSettingNames(setting)) {
        names.add(`${setting.name}.${nestedName}`);
      }
    } else {
      names.add(setting.name);
    }
  }

  return Array.from(names);
}

/**
 * Generate a mkRenamedOptionModule call for a single setting path.
 */
function mkRenamedLine(oldPlugin: string, newPlugin: string, settingPath: string): string {
  const parts = settingPath.split('.');
  const oldParts = parts.map((p) => `"${p}"`).join(' ');
  const newParts = parts.map((p) => `"${p}"`).join(' ');
  const oldId = toNixIdentifier(oldPlugin);
  const newId = toNixIdentifier(newPlugin);
  return `    (lib.modules.mkRenamedOptionModule (base ++ ["${oldId}" ${oldParts}]) (base ++ ["${newId}" ${newParts}]))`;
}

/**
 * Generate a removal shim module for a deleted plugin.
 */
function mkRemovalShim(pluginName: string): string {
  const nixName = toNixIdentifier(pluginName);
  return `    ({ config, lib, ... }:
    {
      options.programs.nixcord.config.plugins.${nixName} = lib.mkOption {
        type = lib.types.anything;
        default = {};
        visible = false;
        description = "REMOVED: Plugin '${pluginName}' was removed upstream.";
      };
      config.warnings = lib.optional (config.programs.nixcord.config.plugins.${nixName}.enable or false)
        "Plugin '${pluginName}' has been removed upstream. Please remove it from your nixcord configuration. This shim will be removed soon.";
    })`;
}

export function generateMigrationsModule(
  deprecated: DeprecatedData,
  allPlugins: ReadonlyDeep<Record<string, PluginConfig>>,
  pluginSources?: ReadonlyDeep<Record<string, PluginConfig>>[]
): string {
  // Build lookup of active plugin nix identifiers to skip conflicting migrations
  const activeNixNames = new Set(Object.keys(allPlugins).map((k) => toNixIdentifier(k)));

  // Pre-filter setting rename entries, deduplicating by Nix identifier
  // Multiple source names (e.g. "platformIndicators" and "PlatformIndicators")
  // can map to the same Nix identifier, so we merge their settings.
  const settingRenamesByNixName = new Map<string, Record<string, string>>();
  for (const [pluginName, settings] of sortedEntries(deprecated.settingRenames ?? {})) {
    const nixName = toNixIdentifier(pluginName);
    if (!activeNixNames.has(nixName)) continue;
    const existing = settingRenamesByNixName.get(nixName) ?? {};
    Object.assign(existing, settings);
    settingRenamesByNixName.set(nixName, existing);
  }
  const settingRenameEntries = Array.from(settingRenamesByNixName.entries());

  // Pre-filter rename entries to know if we need the `let base` binding
  const renameEntries = sortedEntries(deprecated.renames).filter(([oldName, entry]) => {
    const oldNixName = toNixIdentifier(oldName);
    const newNixName = toNixIdentifier(entry.to);
    return !activeNixNames.has(oldNixName) && activeNixNames.has(newNixName);
  });

  const hasSettingRenames = settingRenameEntries.length > 0;
  const hasRenames = renameEntries.length > 0;

  const lines: string[] = [...AUTO_GENERATED_HEADER.split('\n'), ''];

  if (!hasRenames && !hasSettingRenames) {
    lines.push('');
  }
  if (hasRenames || hasSettingRenames) {
    lines.push('{ lib, ... }:', 'let', `  base = ${BASE_PATH}];`, 'in');
  }

  lines.push('{', '  imports = [');

  for (const [oldName, entry] of renameEntries) {
    const newName = entry.to;

    const targetPlugin = allPlugins[newName];

    lines.push(`    # ${oldName} -> ${newName}`);

    if (!targetPlugin) {
      // Target plugin not found in parsed data - just forward enable
      lines.push(mkRenamedLine(oldName, newName, 'enable'));
    } else {
      const settingNames = collectSettingNames(targetPlugin);
      for (const setting of settingNames.sort()) {
        lines.push(mkRenamedLine(oldName, newName, setting));
      }
    }
    lines.push('');
  }

  // Build a lookup from nix identifier to ALL setting names across all plugin versions.
  // A plugin may exist in both vencord and equicord with different settings;
  // we need the union of all settings to detect conflicts correctly.
  const allSettingsByNixName = new Map<string, Set<string>>();
  const sources = pluginSources ?? [allPlugins];
  for (const source of sources) {
    for (const [name, config] of Object.entries(source)) {
      const nixName = toNixIdentifier(name);
      const existing = allSettingsByNixName.get(nixName) ?? new Set<string>();
      for (const s of collectSettingNames(config)) {
        existing.add(s);
      }
      allSettingsByNixName.set(nixName, existing);
    }
  }

  // Generate setting rename migrations
  for (const [nixName, settings] of settingRenameEntries) {
    // Filter out renames where the old setting name still exists on the active plugin,
    // as mkRenamedOptionModule would conflict with the existing option declaration.
    const activeSettingNames = allSettingsByNixName.get(nixName) ?? new Set<string>();

    const validRenames = Object.entries(settings)
      .filter(([oldSetting]) => !activeSettingNames.has(oldSetting))
      .sort(([a], [b]) => a.localeCompare(b));

    if (validRenames.length === 0) continue;

    lines.push(`    # Setting renames: ${nixName}`);
    for (const [oldSetting, newSetting] of validRenames) {
      lines.push(
        `    (lib.modules.doRename { from = base ++ ["${nixName}" "${oldSetting}"]; to = base ++ ["${nixName}" "${newSetting}"]; visible = false; warn = true; use = x: x; })`
      );
    }
    lines.push('');
  }

  // Generate removal shims
  const removalEntries = sortedEntries(deprecated.removals);

  for (const [pluginName] of removalEntries) {
    // Skip removal shims for plugins that still have active definitions
    // (e.g. deleted from one repo but still present in another)
    if (activeNixNames.has(toNixIdentifier(pluginName))) continue;

    lines.push(`    # Removed: ${pluginName}`);
    lines.push(mkRemovalShim(pluginName));
    lines.push('');
  }

  lines.push('  ];');
  lines.push('}');

  return lines.join('\n') + '\n';
}
