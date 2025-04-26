// Type definitions for teaBASE
// Project: https://github.com/teaxyz/teaBASE

declare module 'teabase' {
  /**
   * Initialize teaBASE with optional configuration
   * @param config - Optional settings object
   */
  export function init(config?: { 
    debug?: boolean 
  }): void;

  /**
   * Retrieve a value by key
   * @param key - The lookup key
   * @returns The stored value or undefined
   */
  export function get(key: string): unknown;

  /**
   * Store a value
   * @param key - The storage key
   * @param value - The value to store
   * @returns true if successful
   */
  export function set(key: string, value: unknown): boolean;
}