import { describe, it, expect, vi } from 'vitest';
import { SessionManager, NoSessionError } from '../src/sessionManager.js';
import { ZaloThreadKind, type ZaloApi } from '../src/types.js';

function fakeApi(overrides: Partial<ZaloApi> = {}): ZaloApi {
  return {
    sendText: vi.fn(async () => ({ msgId: '1' })),
    sendAttachment: vi.fn(async () => ({ msgId: '2' })),
    getUserInfo: vi.fn(async () => ({ uid: 'u1', displayName: 'User' })),
    getGroupInfo: vi.fn(async () => ({ groupId: 'g1', name: 'Group' })),
    onMessage: vi.fn(),
    onReaction: vi.fn(),
    onUndo: vi.fn(),
    onClosed: vi.fn(),
    getSerializedCookie: vi.fn(() => null),
    stop: vi.fn(async () => {}),
    ...overrides,
  };
}

describe('SessionManager', () => {
  it('throws NoSessionError for an unregistered channel', async () => {
    const sessions = new SessionManager();
    await expect(sessions.sendText(1, 't', ZaloThreadKind.User, 'hi')).rejects.toThrow(NoSessionError);
  });

  it('reports whether a channel has a live session', () => {
    const sessions = new SessionManager();
    const api = fakeApi();
    sessions.register(9, api);
    expect(sessions.has(9)).toBe(true);
    expect(sessions.has(10)).toBe(false);
    expect(sessions.ids()).toEqual([9]);
  });

  it('delegates sendText/sendAttachment/profile lookups to the registered adapter', async () => {
    const sessions = new SessionManager();
    const api = fakeApi();
    sessions.register(9, api);

    await sessions.sendText(9, 'thread', ZaloThreadKind.Group, 'hello');
    expect(api.sendText).toHaveBeenCalledWith('thread', ZaloThreadKind.Group, 'hello', undefined);

    await sessions.sendAttachment(9, 'thread', ZaloThreadKind.User, { filename: 'a.jpg', data: Buffer.from('x') }, 'cap');
    expect(api.sendAttachment).toHaveBeenCalledWith('thread', ZaloThreadKind.User, { filename: 'a.jpg', data: Buffer.from('x') }, 'cap');

    await sessions.getUserInfo(9, 'u1');
    expect(api.getUserInfo).toHaveBeenCalledWith('u1');

    await sessions.getGroupInfo(9, 'g1');
    expect(api.getGroupInfo).toHaveBeenCalledWith('g1');
  });

  it('binds message/reaction/undo handlers scoped to the channel id', () => {
    const sessions = new SessionManager();
    const api = fakeApi();
    sessions.register(9, api);

    const onMessage = vi.fn();
    const onReaction = vi.fn();
    const onUndo = vi.fn();
    sessions.registerEventHandlers({ onMessage, onReaction, onUndo });
    sessions.bindInbound(9);

    const messageCb = (api.onMessage as ReturnType<typeof vi.fn>).mock.calls[0][0];
    const msg = { kind: ZaloThreadKind.User } as never;
    messageCb(msg);
    expect(onMessage).toHaveBeenCalledWith(9, msg);

    const reactionCb = (api.onReaction as ReturnType<typeof vi.fn>).mock.calls[0][0];
    const evt = { kind: ZaloThreadKind.User } as never;
    reactionCb(evt);
    expect(onReaction).toHaveBeenCalledWith(9, evt);

    const undoCb = (api.onUndo as ReturnType<typeof vi.fn>).mock.calls[0][0];
    const undo = { kind: ZaloThreadKind.User } as never;
    undoCb(undo);
    expect(onUndo).toHaveBeenCalledWith(9, undo);
  });

  it('bindInbound throws NoSessionError for an unregistered channel', () => {
    const sessions = new SessionManager();
    expect(() => sessions.bindInbound(1)).toThrow(NoSessionError);
  });

  describe('remove', () => {
    it('stops the adapter and forgets the channel', async () => {
      const sessions = new SessionManager();
      const api = fakeApi();
      sessions.register(9, api);

      await sessions.remove(9);

      expect(api.stop).toHaveBeenCalled();
      expect(sessions.has(9)).toBe(false);
    });

    it('is a no-op for a channel that was never registered', async () => {
      const sessions = new SessionManager();
      await expect(sessions.remove(404)).resolves.toBeUndefined();
    });

    it('swallows a stop() failure — the channel is still forgotten', async () => {
      const sessions = new SessionManager();
      const api = fakeApi({ stop: vi.fn(async () => { throw new Error('already closed'); }) });
      sessions.register(9, api);

      await sessions.remove(9);

      expect(sessions.has(9)).toBe(false);
    });
  });

  describe('stopAll', () => {
    it('stops every session and clears the registry', async () => {
      const sessions = new SessionManager();
      const a = fakeApi();
      const b = fakeApi();
      sessions.register(1, a);
      sessions.register(2, b);

      await sessions.stopAll();

      expect(a.stop).toHaveBeenCalled();
      expect(b.stop).toHaveBeenCalled();
      expect(sessions.ids()).toEqual([]);
    });
  });
});
