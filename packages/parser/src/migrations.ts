import { join } from 'pathe';
import fse from 'fs-extra';
import { exec } from 'child_process';
import { promisify } from 'util';
import type { Logger } from '@nixcord/shared';
import { AUTO_GENERATED_HEADER } from '@nixcord/shared';
import type { PluginMigrationInfo } from '@nixcord/git-analyzer';
import type { SettingRename } from '@nixcord/shared';

const execAsync = promisify(exec);

export type DeprecatedRenameEntry = {
  to: string;
  date?: string;
};

export type DeprecatedRemovalEntry = {
  date: string;
};

export type DeprecatedData = {
  renames: Record<string, DeprecatedRenameEntry>;
  removals: Record<string, DeprecatedRemovalEntry>;
  settingRenames: Record<string, Record<string, string>>;
};

const RENAME_EXPIRY_DAYS = 40;
const REMOVAL_EXPIRY_DAYS = 50;

/** Plugin names must be valid Nix identifiers (no dots or other special chars). */
function isValidPluginName(name: string): boolean {
  return /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(name);
}

function isExpired(dateStr: string, expiryDays: number): boolean {
  const date = new Date(dateStr);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = diffMs / (1000 * 60 * 60 * 24);
  return diffDays > expiryDays;
}

export async function extractMigrations(
  repoPath: string,
  pluginsDirs: string[]
): Promise<PluginMigrationInfo> {
  try {
    const { extractPluginMigrations } = await import('@nixcord/git-analyzer');
    return await extractPluginMigrations(repoPath, pluginsDirs);
  } catch {
    return { renames: [], deletions: [] };
  }
}

/**
 * Read and parse deprecated.nix using `nix eval --json`.
 * This is authoritative — no custom Nix parser needed.
 */
async function readDeprecatedNix(filePath: string): Promise<DeprecatedData> {
  const empty: DeprecatedData = { renames: {}, removals: {}, settingRenames: {} };
  try {
    const { stdout } = await execAsync(`nix eval --json --file "${filePath}"`);
    const parsed = JSON.parse(stdout) as {
      renames?: Record<string, unknown>;
      removals?: Record<string, unknown>;
      settingRenames?: Record<string, Record<string, string>>;
    };
    const data: DeprecatedData = { renames: {}, removals: {}, settingRenames: {} };

    for (const [name, val] of Object.entries(parsed.renames ?? {})) {
      const v = val as { to?: string; date?: string };
      if (v.to && isValidPluginName(name) && isValidPluginName(v.to)) {
        data.renames[name] = { to: v.to, ...(v.date ? { date: v.date } : {}) };
      }
    }
    for (const [name, val] of Object.entries(parsed.removals ?? {})) {
      const v = val as { date?: string };
      if (v.date && isValidPluginName(name)) {
        data.removals[name] = { date: v.date };
      }
    }
    for (const [pluginName, settings] of Object.entries(parsed.settingRenames ?? {})) {
      if (typeof settings === 'object' && settings !== null) {
        data.settingRenames[pluginName] = settings;
      }
    }

    return data;
  } catch {
    return empty;
  }
}

function generateDeprecatedNix(data: DeprecatedData): string {
  const lines: string[] = [...AUTO_GENERATED_HEADER.split('\n'), '', '{'];

  // Renames
  lines.push('  renames = {');
  const permanentRenames = Object.entries(data.renames)
    .filter(([, v]) => !v.date)
    .sort(([a], [b]) => a.localeCompare(b));
  const datedRenames = Object.entries(data.renames)
    .filter(([, v]) => v.date)
    .sort(([a], [b]) => a.localeCompare(b));

  for (const [name, entry] of permanentRenames) {
    lines.push(`    ${name} = { to = "${entry.to}"; };`);
  }
  for (const [name, entry] of datedRenames) {
    lines.push(`    ${name} = { to = "${entry.to}"; date = "${entry.date}"; };`);
  }
  lines.push('  };');

  // Removals
  lines.push('  removals = {');
  const sortedRemovals = Object.entries(data.removals).sort(([a], [b]) => a.localeCompare(b));
  for (const [name, entry] of sortedRemovals) {
    lines.push(`    ${name} = { date = "${entry.date}"; };`);
  }
  lines.push('  };');

  // Setting renames
  lines.push('  settingRenames = {');
  const sortedSettingRenames = Object.entries(data.settingRenames).sort(([a], [b]) =>
    a.localeCompare(b)
  );
  for (const [pluginName, settings] of sortedSettingRenames) {
    const settingPairs = Object.entries(settings)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([old, newName]) => `${old} = "${newName}";`)
      .join(' ');
    lines.push(`    ${pluginName} = { ${settingPairs} };`);
  }
  lines.push('  };');

  lines.push('}');
  return lines.join('\n') + '\n';
}

/**
 * Remove circular rename pairs (A→B and B→A both present).
 * These arise from ping-pong renames in git history and cancel each other out.
 */
function removeCircularRenames(renames: Record<string, DeprecatedRenameEntry>): void {
  const toRemove = new Set<string>();
  for (const [from, entry] of Object.entries(renames)) {
    if (toRemove.has(from)) continue;
    const to = entry.to;
    if (renames[to]?.to === from) {
      toRemove.add(from);
      toRemove.add(to);
    }
  }
  for (const name of toRemove) {
    delete renames[name];
  }
}

export async function updateDeprecatedPlugins(
  migrations: PluginMigrationInfo,
  pluginsDir: string,
  verbose: boolean,
  logger: Logger,
  settingRenames: SettingRename[] = [],
  activePluginNames?: Set<string>,
  normalizePluginName?: (name: string) => string
): Promise<DeprecatedData> {
  const deprecatedPath = join(pluginsDir, 'deprecated.nix');
  let existing: DeprecatedData = { renames: {}, removals: {}, settingRenames: {} };

  if (await fse.pathExists(deprecatedPath)) {
    existing = await readDeprecatedNix(deprecatedPath);
  }

  // Merge new renames (skip dot-named plugins, don't overwrite existing entries)
  for (const rename of migrations.renames) {
    if (!isValidPluginName(rename.oldName) || !isValidPluginName(rename.newName)) continue;
    const dateStr = rename.commitDate.split('T')[0];
    if (!existing.renames[rename.oldName]) {
      existing.renames[rename.oldName] = { to: rename.newName, date: dateStr };
    }
  }

  // Merge new deletions (skip dot-named plugins)
  for (const deletion of migrations.deletions) {
    if (!isValidPluginName(deletion.pluginName)) continue;
    const dateStr = deletion.commitDate.split('T')[0];
    if (!existing.removals[deletion.pluginName]) {
      existing.removals[deletion.pluginName] = { date: dateStr };
    }
  }

  // Remove circular rename pairs (ping-pong renames that cancel each other out)
  removeCircularRenames(existing.renames);

  // Remove permanent (dateless) renames — they predate the date system and are well past expiry
  for (const [name, entry] of Object.entries(existing.renames)) {
    if (!entry.date) {
      delete existing.renames[name];
    }
  }

  // Prune expired dated entries
  for (const [name, entry] of Object.entries(existing.renames)) {
    if (entry.date && isExpired(entry.date, RENAME_EXPIRY_DAYS)) {
      delete existing.renames[name];
    }
  }
  for (const [name, entry] of Object.entries(existing.removals)) {
    if (isExpired(entry.date, REMOVAL_EXPIRY_DAYS)) {
      delete existing.removals[name];
    }
  }

  // Don't include removals for plugins that are also in renames (they were renamed, not deleted)
  // Use case-insensitive comparison since git may report different casings for the same plugin
  const renameKeysLower = new Map(Object.keys(existing.renames).map((k) => [k.toLowerCase(), k]));
  for (const name of Object.keys(existing.removals)) {
    if (existing.renames[name] || renameKeysLower.has(name.toLowerCase())) {
      delete existing.removals[name];
    }
  }

  // Remove removals for plugins that are still active (git may see a file move as a deletion)
  if (activePluginNames) {
    const normalize = normalizePluginName ?? ((n: string) => n);
    const normalizedActiveNames = new Set([...activePluginNames].map(normalize));
    for (const name of Object.keys(existing.removals)) {
      if (normalizedActiveNames.has(normalize(name))) {
        delete existing.removals[name];
      }
    }
  }

  // Merge setting renames from migratePluginSetting() calls
  const normalize = normalizePluginName ?? ((n: string) => n);
  for (const rename of settingRenames) {
    const nixName = normalize(rename.pluginName);
    if (!existing.settingRenames[nixName]) {
      existing.settingRenames[nixName] = {};
    }
    existing.settingRenames[nixName][rename.oldSetting] = rename.newSetting;
  }

  // Deduplicate settingRenames by normalized name (e.g. "PlatformIndicators" -> "platformIndicators")
  {
    const deduped: Record<string, Record<string, string>> = {};
    for (const [key, settings] of Object.entries(existing.settingRenames)) {
      const nixKey = normalize(key);
      if (!deduped[nixKey]) {
        deduped[nixKey] = {};
      }
      Object.assign(deduped[nixKey], settings);
    }
    existing.settingRenames = deduped;
  }

  const nixCode = generateDeprecatedNix(existing);
  await fse.writeFile(deprecatedPath, nixCode);

  if (verbose) {
    const renameCount = Object.keys(existing.renames).length;
    const deletionCount = Object.keys(existing.removals).length;
    logger.info(`Updated deprecated.nix: ${renameCount} renames, ${deletionCount} removals`);
  }

  return existing;
}
