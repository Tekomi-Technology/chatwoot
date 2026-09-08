import type { ZaloCredentials } from './types.js';

export type SessionStatus = 'connected' | 'reconnecting' | 'expired';

export function isZaloAuthError(err: unknown): boolean {
  const msg = String((err as { message?: unknown })?.message ?? '').toLowerCase();
  if (!msg) return false;
  return /cookie|credential|unauthor|đăng nhập|(login|session|token).*(fail|expired|invalid|reject)|(invalid|expired|reject).*(login|session|token)/.test(
    msg
  );
}

export interface SupervisedAdapter {
  onClosed(cb: (code: number, reason: string) => void): void;
  getSerializedCookie(): unknown;
  stop(): Promise<void>;
}

export interface ReconnectDeps {
  loadCredentials(channelId: number): Promise<ZaloCredentials | null>;
  saveCredentials(channelId: number, creds: ZaloCredentials): Promise<void>;
  createAdapter(channelId: number, creds: ZaloCredentials): Promise<SupervisedAdapter>;
  register(channelId: number, adapter: SupervisedAdapter): void;
  unregister(channelId: number): Promise<void>;
  bindInbound(channelId: number): void;
  setStatus(channelId: number, status: SessionStatus): Promise<void>;
  log(obj: Record<string, unknown>, msg: string): void;
}

export const BACKOFF_MS = [5_000, 15_000, 45_000, 120_000, 300_000];
const MANUAL_CLOSE = 1000;

export const MAX_AUTH_FAILURES = 3;

interface ChannelState {
  attempt: number;
  authFailures: number;
  connecting: boolean;
  stopped: boolean;
  epoch: number;
  adapter?: SupervisedAdapter;
  timer?: NodeJS.Timeout;
}

export class ReconnectSupervisor {
  private state = new Map<number, ChannelState>();

  constructor(private deps: ReconnectDeps) {}

  async persistAllCookies(): Promise<void> {
    for (const [channelId, st] of this.state) {
      if (!st.adapter) continue;
      try {
        const creds = await this.deps.loadCredentials(channelId);
        if (creds) await this.persistCookie(channelId, st.adapter, creds);
      } catch (err) {
        this.deps.log({ channelId, err: String(err) }, 'failed to persist refreshed cookie');
      }
    }
  }

  async remove(channelId: number): Promise<void> {
    const st = this.ensure(channelId);
    st.stopped = true;
    st.epoch++; 
    if (st.timer) clearTimeout(st.timer);
    st.timer = undefined;
    st.adapter = undefined;
    await this.deps.unregister(channelId).catch(() => {});
  }

  async connect(channelId: number): Promise<void> {
    const st = this.ensure(channelId);
    if (st.connecting) return; 
    st.connecting = true;
    st.stopped = false;
    const epoch = ++st.epoch; 
    const isCurrent = () => st.epoch === epoch && !st.stopped;
    try {
      const creds = await this.deps.loadCredentials(channelId);
      if (!creds || !isCurrent()) return;
      const adapter = await this.deps.createAdapter(channelId, creds); // may throw
      if (!isCurrent()) {
        await adapter.stop().catch(() => {});
        return;
      }
      this.deps.register(channelId, adapter);
      this.deps.bindInbound(channelId);
      adapter.onClosed((code, reason) => this.onClosed(channelId, code, reason));
      st.adapter = adapter;
      st.attempt = 0;
      st.authFailures = 0;
      await this.transition(channelId, 'connected');
      if (!isCurrent()) return; 
      await this.persistCookie(channelId, adapter, creds);
    } catch (err) {
      st.adapter = undefined;
      if (isZaloAuthError(err)) {
        st.authFailures++;
        if (st.authFailures >= MAX_AUTH_FAILURES) {
          this.deps.log(
            { channelId, err: String(err), attempts: st.authFailures },
            'zalo re-login rejected repeatedly; marking expired'
          );
          await this.transition(channelId, 'expired');
          return;
        }
        this.deps.log(
          { channelId, err: String(err), attempt: st.authFailures },
          'zalo re-login rejected; retrying before giving up'
        );
        await this.transition(channelId, 'reconnecting');
        this.scheduleReconnect(channelId);
        return;
      }
      this.deps.log({ channelId, err: String(err) }, 'zalo connect failed; will retry');
      await this.transition(channelId, 'reconnecting');
      this.scheduleReconnect(channelId);
    } finally {
      st.connecting = false;
    }
  }

  private async transition(channelId: number, status: SessionStatus): Promise<void> {
    this.deps.log({ channelId, status }, 'channel status changed');
    await this.deps.setStatus(channelId, status).catch(() => {});
  }

  private async persistCookie(channelId: number, adapter: SupervisedAdapter, creds: ZaloCredentials): Promise<void> {
    try {
      const cookie = adapter.getSerializedCookie();
      if (cookie == null) return;
      await this.deps.saveCredentials(channelId, { ...creds, cookie });
    } catch (err) {
      this.deps.log({ channelId, err: String(err) }, 'failed to persist refreshed cookie');
    }
  }

  private ensure(channelId: number): ChannelState {
    let s = this.state.get(channelId);
    if (!s) {
      s = { attempt: 0, authFailures: 0, connecting: false, stopped: false, epoch: 0 };
      this.state.set(channelId, s);
    }
    return s;
  }

  private onClosed(channelId: number, code: number, reason: string): void {
    const st = this.ensure(channelId);
    st.adapter = undefined;
    st.epoch++; 
    if (st.stopped) return;
    if (code === MANUAL_CLOSE) return; // we closed it on purpose
    this.deps.log({ channelId, code, reason }, 'zalo session closed; scheduling reconnect');
    void this.deps.unregister(channelId).catch(() => {});
    void this.transition(channelId, 'reconnecting');
    this.scheduleReconnect(channelId);
  }

  private scheduleReconnect(channelId: number): void {
    const st = this.ensure(channelId);
    if (st.timer) clearTimeout(st.timer);
    const ms = BACKOFF_MS[Math.min(st.attempt, BACKOFF_MS.length - 1)];
    st.attempt++;
    st.timer = setTimeout(() => {
      st.timer = undefined;
      if (st.stopped) return;
      void this.connect(channelId);
    }, ms);
  }
}
