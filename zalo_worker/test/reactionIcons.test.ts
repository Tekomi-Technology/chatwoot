import { describe, it, expect } from 'vitest';
import { isReactionRemoval, reactionEmoji } from '../src/reactionIcons.js';

describe('isReactionRemoval', () => {
  it('treats the empty code as a removal', () => {
    expect(isReactionRemoval('')).toBe(true);
  });

  it('treats any non-empty code as not a removal', () => {
    expect(isReactionRemoval('/-heart')).toBe(false);
  });
});

describe('reactionEmoji', () => {
  it('maps known zca-js codes to their emoji', () => {
    expect(reactionEmoji('/-heart')).toBe('❤️');
    expect(reactionEmoji('/-strong')).toBe('👍');
    expect(reactionEmoji(':>')).toBe('😆');
    expect(reactionEmoji('/-no')).toBe('🚫');
  });

  it('falls back to a heart for an unmapped code', () => {
    expect(reactionEmoji('/-unknown-code')).toBe('❤️');
  });
});
