import { camelCase } from 'change-case';

const PARENTHESES_PATTERN = /\s*\([^)]*\)\s*/g;
const INVALID_CHARS_PATTERN = /[^A-Za-z0-9_'-]/g;
const LEADING_TRAILING_UNDERSCORES_PATTERN = /^_+|_+$/g;
const MULTIPLE_UNDERSCORES_PATTERN = /_+/g;
const VALID_IDENTIFIER_START_PATTERN = /^[A-Za-z_]/;
const LEADING_UNDERSCORE_PREFIX = '_';

/**
 * Sanitize and convert a name to a valid Nix identifier using camelCase.
 * Pure string→string function — no class instantiation needed.
 */
export function toNixIdentifier(name: string): string {
  const originalStartsWithUnderscore = name.startsWith('_');
  const originalEndsWithUnderscore = name.endsWith('_');
  let sanitized = name
    .replace(PARENTHESES_PATTERN, '')
    .replace(INVALID_CHARS_PATTERN, '_')
    .replace(LEADING_TRAILING_UNDERSCORES_PATTERN, '')
    .replace(MULTIPLE_UNDERSCORES_PATTERN, '_');

  const needsPrefix =
    sanitized.length === 0 || !VALID_IDENTIFIER_START_PATTERN.test(sanitized);

  const hasAcronym = /[A-Z]{2}/.test(sanitized);

  const needsCamelCase = sanitized.includes('_') || sanitized.includes(' ');
  if (!hasAcronym || needsCamelCase) {
    try {
      sanitized = camelCase(sanitized);
    } catch {}
  }

  if (
    originalStartsWithUnderscore &&
    !originalEndsWithUnderscore &&
    sanitized &&
    VALID_IDENTIFIER_START_PATTERN.test(sanitized)
  )
    return '_' + sanitized;
  if (
    needsPrefix ||
    sanitized.length === 0 ||
    !VALID_IDENTIFIER_START_PATTERN.test(sanitized)
  )
    sanitized = LEADING_UNDERSCORE_PREFIX + sanitized;

  return sanitized;
}
