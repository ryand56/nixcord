/** Recursively makes all properties readonly. */
export type ReadonlyDeep<T> = T extends (...args: infer A) => infer R
  ? (...args: A) => R
  : T extends readonly (infer U)[]
    ? readonly ReadonlyDeep<U>[]
    : T extends object
      ? { readonly [K in keyof T]: ReadonlyDeep<T[K]> }
      : T;

/** Flattens an intersection into a single object type for cleaner display. */
export type Simplify<T> = { [K in keyof T]: T[K] } & {};

/** Makes the specified keys required. */
export type SetRequired<T, K extends keyof T> = Omit<T, K> & Required<Pick<T, K>>;

/** Makes the specified keys optional. */
export type SetOptional<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;

/** Ensures a type exactly matches a shape with no extra keys. */
export type Exact<T, Shape> = T extends Shape
  ? Exclude<keyof T, keyof Shape> extends never
    ? T
    : never
  : never;
