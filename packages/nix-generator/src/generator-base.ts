import { camelCase } from 'change-case';

import type { ReadonlyDeep } from 'type-fest';
import { isArray, isNonNullObject, isString, isNumber, isBoolean } from '@nixcord/shared';
import { escapeNixDoubleQuotedString, escapeNixString } from './utils/nix-escape.js';

const visitedObjects = new WeakSet<object>();

export type NixValue = string | number | boolean | null | NixValue[] | NixAttrSet | NixRaw;

export interface NixAttrSet {
  [key: string]: NixValue | undefined;
}

export type ReadonlyNixAttrSet = ReadonlyDeep<Record<string, NixValue | undefined>>;

export interface NixRaw {
  type: 'raw';
  value: string;
}

export interface NixGeneratorOptions {
  indent: string;
}

const DEFAULT_INDENT = '  ';
const NIX_NULL = 'null';
const NIX_RAW_TYPE = 'raw';
const NIX_LIST_OPEN = '[';
const NIX_LIST_CLOSE = ']';
const NIX_EMPTY_LIST = '[ ]';
const NIX_ATTR_SET_OPEN = '{';
const NIX_ATTR_SET_CLOSE = '}';
const NIX_EMPTY_ATTR_SET = '{ }';
const NIX_ASSIGNMENT = ' = ';
const NIX_LIST_SEPARATOR = '\n';
const NIX_STATEMENT_TERMINATOR = ';';
const NIX_MULTILINE_STRING_START = "''";
const NIX_MULTILINE_STRING_END = "''";
const NIX_DOUBLE_QUOTED_STRING_START = '"';
const NIX_DOUBLE_QUOTED_STRING_END = '"';
const NEWLINE_CHAR = '\n';

export class NixGenerator {
  private readonly options: Readonly<NixGeneratorOptions>;

  constructor(options?: Partial<NixGeneratorOptions>) {
    this.options = { indent: options?.indent ?? DEFAULT_INDENT };
  }

  private indent(level: number = 1): string {
    return this.options.indent.repeat(level);
  }

  string(str: string, multiline: boolean = false): string {
    return str.includes(NEWLINE_CHAR) || multiline
      ? `${NIX_MULTILINE_STRING_START}${escapeNixString(str)}${NIX_MULTILINE_STRING_END}`
      : `${NIX_DOUBLE_QUOTED_STRING_START}${escapeNixDoubleQuotedString(str)}${NIX_DOUBLE_QUOTED_STRING_END}`;
  }

  number(n: number): string {
    return n.toString();
  }

  boolean(b: boolean): string {
    return b.toString();
  }

  nullValue(): string {
    return NIX_NULL;
  }

  raw(value: string): NixRaw {
    return { type: NIX_RAW_TYPE, value };
  }

  list(items: readonly NixValue[], level: number = 0): string {
    if (items.length === 0) return NIX_EMPTY_LIST;
    const indent = this.indent(level);
    const itemIndent = this.indent(level + 1);
    return [
      NIX_LIST_OPEN,
      ...items.map((item) => `${itemIndent}${this.value(item, level + 1)}`),
      `${indent}${NIX_LIST_CLOSE}`,
    ].join(NIX_LIST_SEPARATOR);
  }

  attrSet(attrs: ReadonlyNixAttrSet | NixAttrSet, level: number = 0): string {
    const filteredAttrs = Object.fromEntries(
      Object.entries(attrs).filter(([, value]) => value !== undefined)
    );
    const rawKeys = Object.keys(filteredAttrs).sort();
    const enableIdx = rawKeys.indexOf('enable');
    const sortedKeys =
      enableIdx !== -1 ? ['enable', ...rawKeys.filter((_, i) => i !== enableIdx)] : rawKeys;

    if (sortedKeys.length === 0) return NIX_EMPTY_ATTR_SET;

    const indent = this.indent(level);
    const propIndent = this.indent(level + 1);
    return [
      NIX_ATTR_SET_OPEN,
      ...sortedKeys
        .filter((key) => filteredAttrs[key] !== undefined)
        .map(
          (key) =>
            `${propIndent}${this.identifier(key)}${NIX_ASSIGNMENT}${this.value(filteredAttrs[key] as NixValue, level + 1)}${NIX_STATEMENT_TERMINATOR}`
        ),
      `${indent}${NIX_ATTR_SET_CLOSE}`,
    ].join(NIX_LIST_SEPARATOR);
  }

  value(val: NixValue, level: number = 0): string {
    const isRaw =
      isNonNullObject(val) &&
      !isArray(val) &&
      'type' in val &&
      (val as unknown as NixRaw).type === NIX_RAW_TYPE;
    if (isRaw) return (val as unknown as NixRaw).value;

    const isPlainObject = isNonNullObject(val) && !isArray(val);
    if (isPlainObject) {
      if (visitedObjects.has(val)) return 'null';
      visitedObjects.add(val);
    }

    try {
      if (isArray(val)) return this.list(val as readonly NixValue[], level);
      if (isString(val)) return this.string(val);
      if (isNumber(val)) return this.number(val);
      if (isBoolean(val)) return this.boolean(val);
      if (val === null) return this.nullValue();
      if (isPlainObject) return this.attrSet(val as unknown as NixAttrSet, level);
      return NIX_NULL;
    } finally {
      if (isPlainObject && !isRaw) visitedObjects.delete(val);
    }
  }

  private static readonly PARENTHESES_PATTERN = /\s*\([^)]*\)\s*/g;
  private static readonly INVALID_CHARS_PATTERN = /[^A-Za-z0-9_'-]/g;
  private static readonly LEADING_TRAILING_UNDERSCORES_PATTERN = /^_+|_+$/g;
  private static readonly MULTIPLE_UNDERSCORES_PATTERN = /_+/g;
  private static readonly VALID_IDENTIFIER_START_PATTERN = /^[A-Za-z_]/;
  private static readonly LEADING_UNDERSCORE_PREFIX = '_';

  identifier(name: string): string {
    const originalStartsWithUnderscore = name.startsWith('_');
    const originalEndsWithUnderscore = name.endsWith('_');
    let sanitized = name
      .replace(NixGenerator.PARENTHESES_PATTERN, '')
      .replace(NixGenerator.INVALID_CHARS_PATTERN, '_')
      .replace(NixGenerator.LEADING_TRAILING_UNDERSCORES_PATTERN, '')
      .replace(NixGenerator.MULTIPLE_UNDERSCORES_PATTERN, '_');

    const needsPrefix =
      sanitized.length === 0 || !NixGenerator.VALID_IDENTIFIER_START_PATTERN.test(sanitized);

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
      NixGenerator.VALID_IDENTIFIER_START_PATTERN.test(sanitized)
    )
      return '_' + sanitized;
    if (
      needsPrefix ||
      sanitized.length === 0 ||
      !NixGenerator.VALID_IDENTIFIER_START_PATTERN.test(sanitized)
    )
      sanitized = NixGenerator.LEADING_UNDERSCORE_PREFIX + sanitized;

    return sanitized;
  }
}
