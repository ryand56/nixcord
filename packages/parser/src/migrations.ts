import type { PluginMigrationInfo } from '@nixcord/git-analyzer';

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
