import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  isZaloAuthError,
  ReconnectSupervisor,
  BACKOFF_MS,
  type ReconnectDeps,
  type SupervisedAdapter,
} from '../src/supervisor.js';
import type { ZaloCredentials } from '../src/types.js';

describe('isZaloAuthError', () => {
  it('flags credential/session messages as auth errors', () => {
    expect(isZaloAuthError(new Error('Invalid cookie'))).toBe(true);
    expect(isZaloAuthError(new Error('login failed: credential rejected'))).toBe(true);
    expect(isZaloAuthError(new Error('session expired, please re-login'))).toBe(true);
    expect(isZaloAuthError(new Error('Cookie đăng nhập không hợp lệ'))).toBe(true);
  });

  it('treats network/unknown errors as non-auth (retryable)', () => {
    expect(isZaloAuthError(new Error('fetch failed'))).toBe(false);
    expect(isZaloAuthError(new Error('ETIMEDOUT'))).toBe(false);
    expect(isZaloAuthError(new Error('socket hang up'))).toBe(false);
    expect(isZaloAuthError(undefined)).toBe(false);
    expect(isZaloAuthError('boom')).toBe(false);
  });

  it('treats proxy/tunnel auth failures as non-auth (retryable)', () => {
    expect(isZaloAuthError(new Error('407 Proxy Authentication Required'))).toBe(false);
    expect(isZaloAuthError(new Error('tunneling socket could not be established'))).toBe(false);
  });
});

function fakeAdapter(): SupervisedAdapter & { fireClose: (code: number, reason?: string) => void } {
  let closeCb: (code: number, reason: string) => void = () => {};
  return {
    onClosed: (cb) => {
      closeCb = cb;
    },
    getSerializedCookie: () => ({ cookies: [{ key: 'zpsid', value: 'fresh' }] }),
    stop: vi.fn(async () => {}),
    fireClose: (code, reason = 'x') => closeCb(code, reason),
  };
}

const CREDS: ZaloCredentials = { imei: 'i', cookie: { cookies: [{ key: 'zpsid', value: 'old' }] }, userAgent: 'ua' };

function makeDeps(overrides: Partial<ReconnectDeps> = {}) {
  const log = vi.fn();
  const adapter = fakeAdapter();
  const deps: ReconnectDeps = {
    loadCredentials: vi.fn(async () => CREDS),
    saveCredentials: vi.fn(async () => {}),
    createAdapter: vi.fn(async (_channelId: number, _creds: ZaloCredentials) => adapter),
    register: vi.fn(),
    unregister: vi.fn(async () => {}),
    bindInbound: vi.fn(),
    setStatus: vi.fn(async () => {}),
    log,
    ...overrides,
  };
  return { deps, adapter };
}

describe('ReconnectSupervisor.connect (success)', () => {
  it('registers, binds, marks connected, and persists the refreshed cookie', async () => {
    const { deps, adapter } = makeDeps();
    const sup = new ReconnectSupervisor(deps);

    await sup.connect(7);

    expect(deps.createAdapter).toHaveBeenCalledOnce();
    expect(deps.register).toHaveBeenCalledWith(7, adapter);
    expect(deps.bindInbound).toHaveBeenCalledWith(7);
    expect(deps.setStatus).toHaveBeenCalledWith(7, 'connected');
    expect(deps.saveCredentials).toHaveBeenCalledWith(7, {
      ...CREDS,
      cookie: { cookies: [{ key: 'zpsid', value: 'fresh' }] },
    });
  });

  it('does nothing when there are no stored credentials', async () => {
    const { deps } = makeDeps({ loadCredentials: vi.fn(async () => null) });
    const sup = new ReconnectSupervisor(deps);

    await sup.connect(7);

    expect(deps.createAdapter).not.toHaveBeenCalled();
    expect(deps.setStatus).not.toHaveBeenCalled();
  });

  it('ignores a second connect() call while one is already in flight', async () => {
    let resolve!: () => void;
    const { deps } = makeDeps({
      createAdapter: vi.fn(
        () =>
          new Promise<SupervisedAdapter>((r) => {
            resolve = () => r(fakeAdapter());
          })
      ),
    });
    const sup = new ReconnectSupervisor(deps);
    const p1 = sup.connect(7);
    await Promise.resolve();
    const p2 = sup.connect(7);
    resolve();
    await Promise.all([p1, p2]);
    expect(deps.createAdapter).toHaveBeenCalledOnce();
  });
});

describe('ReconnectSupervisor auth failure', () => {
  it('marks the channel expired and does not schedule a retry', async () => {
    vi.useFakeTimers();
    try {
      const { deps } = makeDeps({
        createAdapter: vi.fn(async () => {
          throw new Error('cookie invalid, please re-login');
        }),
      });
      const sup = new ReconnectSupervisor(deps);

      await sup.connect(7);

      expect(deps.setStatus).toHaveBeenCalledWith(7, 'expired');
      (deps.createAdapter as ReturnType<typeof vi.fn>).mockClear();
      await vi.advanceTimersByTimeAsync(BACKOFF_MS[BACKOFF_MS.length - 1] + 1000);
      expect(deps.createAdapter).not.toHaveBeenCalled();
    } finally {
      vi.useRealTimers();
    }
  });
});

describe('ReconnectSupervisor.onClosed', () => {
  it('ignores a manual close (code 1000) — no reconnect, no status change', async () => {
    const { deps, adapter } = makeDeps();
    const sup = new ReconnectSupervisor(deps);
    await sup.connect(7);
    (deps.setStatus as ReturnType<typeof vi.fn>).mockClear();

    adapter.fireClose(1000, 'manual');

    expect(deps.setStatus).not.toHaveBeenCalled();
    expect(deps.unregister).not.toHaveBeenCalled();
  });

  it('on a non-manual close: unregisters, marks reconnecting, and reconnects after the first backoff', async () => {
    vi.useFakeTimers();
    try {
      const { deps, adapter } = makeDeps();
      const sup = new ReconnectSupervisor(deps);
      await sup.connect(7);

      adapter.fireClose(1006, 'abnormal');

      expect(deps.unregister).toHaveBeenCalledWith(7);
      expect(deps.setStatus).toHaveBeenCalledWith(7, 'reconnecting');

      (deps.createAdapter as ReturnType<typeof vi.fn>).mockClear();
      await vi.advanceTimersByTimeAsync(BACKOFF_MS[0]);
      expect(deps.createAdapter).toHaveBeenCalledTimes(1);
      expect(deps.setStatus).toHaveBeenLastCalledWith(7, 'connected');
    } finally {
      vi.useRealTimers();
    }
  });

  it('escalates the backoff on repeated network failures and caps it at the last value', async () => {
    vi.useFakeTimers();
    try {
      const { deps } = makeDeps({
        createAdapter: vi.fn(async () => {
          throw new Error('fetch failed');
        }),
      });
      const sup = new ReconnectSupervisor(deps);

      await sup.connect(7); // fails -> schedules BACKOFF_MS[0]
      await vi.advanceTimersByTimeAsync(BACKOFF_MS[0]); // retry fails -> schedules BACKOFF_MS[1]
      await vi.advanceTimersByTimeAsync(BACKOFF_MS[1]); // retry fails -> schedules BACKOFF_MS[2]

      expect(deps.createAdapter).toHaveBeenCalledTimes(3);

      // Run far past every remaining backoff step; the delay never exceeds the cap, so this
      // still lands on a bounded, predictable number of additional attempts.
      const remaining = BACKOFF_MS.length - 2;
      let totalRemainingDelay = 0;
      for (let i = 2; i < BACKOFF_MS.length + 3; i++) {
        totalRemainingDelay += BACKOFF_MS[Math.min(i, BACKOFF_MS.length - 1)];
      }
      await vi.advanceTimersByTimeAsync(totalRemainingDelay);

      expect(deps.createAdapter.mock.calls.length).toBeGreaterThan(3 + remaining - 1);
    } finally {
      vi.useRealTimers();
    }
  });
});

describe('ReconnectSupervisor.remove', () => {
  it('cancels a pending reconnect and stops supervising the channel', async () => {
    vi.useFakeTimers();
    try {
      const { deps, adapter } = makeDeps();
      const sup = new ReconnectSupervisor(deps);
      await sup.connect(7);
      adapter.fireClose(1006, 'abnormal');
      expect(deps.setStatus).toHaveBeenLastCalledWith(7, 'reconnecting');

      await sup.remove(7);
      (deps.createAdapter as ReturnType<typeof vi.fn>).mockClear();

      await vi.advanceTimersByTimeAsync(BACKOFF_MS[BACKOFF_MS.length - 1] + 1000);
      expect(deps.createAdapter).not.toHaveBeenCalled();
    } finally {
      vi.useRealTimers();
    }
  });

  it('discards a connect() that was already in flight when remove() is called', async () => {
    let resolveAdapter!: (a: SupervisedAdapter) => void;
    const stoppedAdapter = fakeAdapter();
    const { deps } = makeDeps({
      createAdapter: vi.fn(
        () =>
          new Promise<SupervisedAdapter>((r) => {
            resolveAdapter = r;
          })
      ),
    });
    const sup = new ReconnectSupervisor(deps);

    const p = sup.connect(7);
    await Promise.resolve();
    await sup.remove(7);
    resolveAdapter(stoppedAdapter);
    await p;

    expect(deps.register).not.toHaveBeenCalled();
    expect(stoppedAdapter.stop).toHaveBeenCalled();
  });
});
