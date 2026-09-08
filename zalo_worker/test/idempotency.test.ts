import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { once } from '../src/idempotency.js';

describe('once', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('sends immediately when no key is given', async () => {
    const send = vi.fn(async () => ({ msgId: 'a' }));
    const result = await once(undefined, send);
    expect(result).toEqual({ msgId: 'a' });
    expect(send).toHaveBeenCalledTimes(1);

    // A second call with no key sends again — there is nothing to dedupe against.
    await once(undefined, send);
    expect(send).toHaveBeenCalledTimes(2);
  });

  it('returns the original msgId on a repeat of a completed key without sending again', async () => {
    const send = vi.fn(async () => ({ msgId: 'first' }));
    const first = await once('msg:1', send);
    const second = await once('msg:1', send);

    expect(first).toEqual({ msgId: 'first' });
    expect(second).toEqual({ msgId: 'first' });
    expect(send).toHaveBeenCalledTimes(1);
  });

  it('awaits the same in-flight send for concurrent calls with the same key', async () => {
    let resolveSend: (v: { msgId: string }) => void;
    const send = vi.fn(
      () =>
        new Promise<{ msgId: string }>((resolve) => {
          resolveSend = resolve;
        })
    );

    const p1 = once('msg:2', send);
    const p2 = once('msg:2', send);
    resolveSend!({ msgId: 'concurrent' });

    expect(await p1).toEqual({ msgId: 'concurrent' });
    expect(await p2).toEqual({ msgId: 'concurrent' });
    expect(send).toHaveBeenCalledTimes(1);
  });

  it('sends again once the completed entry has expired', async () => {
    const send = vi.fn(async () => ({ msgId: 'stale-then-fresh' }));
    await once('msg:3', send);

    vi.advanceTimersByTime(5 * 60 * 1000 + 1);

    await once('msg:3', send);
    expect(send).toHaveBeenCalledTimes(2);
  });

  it('does not cache a rejected send, so a retry with the same key sends again', async () => {
    const send = vi
      .fn()
      .mockRejectedValueOnce(new Error('boom'))
      .mockResolvedValueOnce({ msgId: 'recovered' });

    await expect(once('msg:4', send)).rejects.toThrow('boom');
    const result = await once('msg:4', send);

    expect(result).toEqual({ msgId: 'recovered' });
    expect(send).toHaveBeenCalledTimes(2);
  });
});
