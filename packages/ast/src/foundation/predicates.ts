import type { Node } from 'ts-morph';
import { SyntaxKind } from 'ts-morph';
import { unwrapNode } from './unwrap.js';

export const isLiteralKind = (kind: SyntaxKind): boolean =>
  kind === SyntaxKind.StringLiteral ||
  kind === SyntaxKind.NumericLiteral ||
  kind === SyntaxKind.NoSubstitutionTemplateLiteral ||
  kind === SyntaxKind.TrueKeyword ||
  kind === SyntaxKind.FalseKeyword;

export const isCollectionKind = (kind: SyntaxKind): boolean =>
  kind === SyntaxKind.ArrayLiteralExpression || kind === SyntaxKind.ObjectLiteralExpression;

export const isEmptyValue = (value: unknown): boolean =>
  value === null || value === undefined || value === '' || value === 0 || value === false;

export const isLiteralNode = (node: Node): boolean => isLiteralKind(unwrapNode(node).getKind());

export const isWrappedNode = (node: Node): boolean =>
  node.getKind() === SyntaxKind.AsExpression ||
  node.getKind() === SyntaxKind.TypeAssertionExpression ||
  node.getKind() === SyntaxKind.ParenthesizedExpression;
