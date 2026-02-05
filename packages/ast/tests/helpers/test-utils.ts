import { expect } from 'vitest';
import { Project, ModuleKind } from 'ts-morph';
import { createMinimalProps } from '../../src/extractor/type-inference/types.js';
import type { SettingProperties } from '../../src/extractor/type-inference/types.js';

export function createProject(): Project {
  return new Project({
    skipAddingFilesFromTsConfig: true,
    skipFileDependencyResolution: true,
    skipLoadingLibFiles: true,
    compilerOptions: {
      target: 99, // ES2022
      module: ModuleKind.ESNext,
      jsx: 2, // React
      allowJs: true,
      skipLibCheck: true,
    },
  });
}

export function createSettingProperties(
  overrides: Partial<SettingProperties> = {}
): SettingProperties {
  return { ...createMinimalProps(), ...overrides };
}

export function unwrapResult<T>(result: {
  ok: boolean;
  value?: T;
  error?: { message: string };
}): T | undefined {
  if (result.ok) return result.value;
  throw new Error(result.error?.message ?? 'Unexpected error');
}

export function expectResultError(
  result: {
    ok: boolean;
    error?: { message: string };
  },
  matcher?: string | RegExp
): string {
  expect(result.ok).toBe(false);
  const message = result.error?.message ?? '';
  if (typeof matcher === 'string') {
    expect(message).toContain(matcher);
  } else if (matcher) {
    expect(message).toMatch(matcher);
  }
  return message;
}
