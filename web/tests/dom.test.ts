// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { attributeText } from '../src/ui/dom';

describe('attributes on the screen', () => {
  it('an ARIA state is the word true or false, never an empty mark', () => {
    expect(attributeText('aria-pressed', true)).toBe('true');
    expect(attributeText('aria-pressed', false)).toBe('false');
    expect(attributeText('aria-modal', 'true')).toBe('true');
  });

  it('an HTML switch is there or not', () => {
    expect(attributeText('disabled', true)).toBe('');
    expect(attributeText('disabled', false)).toBeNull();
    expect(attributeText('rows', 3)).toBe('3');
    expect(attributeText('lang', null)).toBeNull();
  });
});
