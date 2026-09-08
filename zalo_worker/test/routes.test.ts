import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import Fastify, { type FastifyInstance } from 'fastify';
import multipart from '@fastify/multipart';
import { registerRoutes, type RouteDeps } from '../src/routes.js';
import { NoSessionError } from '../src/sessionManager.js';
import { ZaloFileRejectedError, ZaloThreadKind } from '../src/types.js';

vi.mock('../src/qrLogin.js', () => ({
  startQrLogin: vi.fn(async () => ({ qrSessionId: 'qr-1', qrImage: 'data:image/png;base64,xx' })),
}));

const SECRET = 'test-secret';

function fakeSessions() {
  return {
    sendText: vi.fn(async () => ({ msgId: 'text-1' })),
    sendAttachment: vi.fn(async () => ({ msgId: 'att-1' })),
    getUserInfo: vi.fn(async () => ({ uid: 'u1', displayName: 'User Name', avatar: 'http://a' })),
    getGroupInfo: vi.fn(async () => ({ groupId: 'g1', name: 'Group Name', avatar: null })),
    ids: vi.fn(() => [1]),
  };
}

function fakeSupervisor() {
  return {
    connect: vi.fn(async () => {}),
    remove: vi.fn(async () => {}),
  };
}

async function buildApp(deps: Partial<RouteDeps> = {}): Promise<{ app: FastifyInstance; deps: RouteDeps }> {
  const app = Fastify();
  await app.register(multipart, { limits: { fileSize: 10 * 1024 * 1024 } });
  const fullDeps: RouteDeps = {
    sessions: fakeSessions() as never,
    supervisor: fakeSupervisor() as never,
    credentials: new Map(),
    reportQrLogin: vi.fn(async () => {}),
    reportQrFailure: vi.fn(async () => {}),
    secret: SECRET,
    log: vi.fn(),
    ...deps,
  };
  registerRoutes(app, fullDeps);
  await app.ready();
  return { app, deps: fullDeps };
}

function buildMultipart(fields: Record<string, string>, file: { filename: string; content: Buffer }) {
  const boundary = '----zaloWorkerTestBoundary';
  const parts: Buffer[] = [];
  for (const [key, val] of Object.entries(fields)) {
    parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${key}"\r\n\r\n${val}\r\n`));
  }
  parts.push(
    Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${file.filename}"\r\nContent-Type: application/octet-stream\r\n\r\n`
    )
  );
  parts.push(file.content);
  parts.push(Buffer.from(`\r\n--${boundary}--\r\n`));
  return { body: Buffer.concat(parts), contentType: `multipart/form-data; boundary=${boundary}` };
}

describe('auth hook', () => {
  it('rejects a request with a missing or wrong secret', async () => {
    const { app } = await buildApp();
    const res = await app.inject({ method: 'GET', url: '/health', headers: { 'x-zalo-worker-secret': 'wrong' } });
    expect(res.statusCode).toBe(401);
  });

  it('allows a request with the correct secret', async () => {
    const { app } = await buildApp();
    const res = await app.inject({ method: 'GET', url: '/health', headers: { 'x-zalo-worker-secret': SECRET } });
    expect(res.statusCode).toBe(200);
  });
});

describe('POST /qr/start', () => {
  it('returns the qr session id and image from startQrLogin', async () => {
    const { app } = await buildApp();
    const res = await app.inject({ method: 'POST', url: '/qr/start', headers: { 'x-zalo-worker-secret': SECRET } });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ qr_session_id: 'qr-1', qr_image: 'data:image/png;base64,xx' });
  });
});

describe('POST /sessions/:channelId/connect', () => {
  it('stores the credentials, kicks off supervisor.connect, and returns 202 without waiting', async () => {
    const supervisor = fakeSupervisor();
    const { app, deps } = await buildApp({ supervisor: supervisor as never });
    const res = await app.inject({
      method: 'POST',
      url: '/sessions/5/connect',
      headers: { 'x-zalo-worker-secret': SECRET, 'content-type': 'application/json' },
      payload: { credentials: { imei: 'i', cookie: {}, userAgent: 'ua' } },
    });
    expect(res.statusCode).toBe(202);
    expect(res.json()).toEqual({ status: 'connecting' });
    expect(deps.credentials.get(5)).toEqual({ imei: 'i', cookie: {}, userAgent: 'ua' });
    expect(supervisor.connect).toHaveBeenCalledWith(5);
  });
});

describe('DELETE /sessions/:channelId', () => {
  it('removes the supervised session and forgets stored credentials', async () => {
    const supervisor = fakeSupervisor();
    const { app, deps } = await buildApp({ supervisor: supervisor as never });
    deps.credentials.set(5, { imei: 'i', cookie: {}, userAgent: 'ua' });

    const res = await app.inject({ method: 'DELETE', url: '/sessions/5', headers: { 'x-zalo-worker-secret': SECRET } });

    expect(res.statusCode).toBe(204);
    expect(supervisor.remove).toHaveBeenCalledWith(5);
    expect(deps.credentials.has(5)).toBe(false);
  });
});

describe('GET /sessions/:channelId/profile', () => {
  it('returns a user profile for kind=user', async () => {
    const { app } = await buildApp();
    const res = await app.inject({
      method: 'GET',
      url: '/sessions/5/profile?kind=user&id=u1',
      headers: { 'x-zalo-worker-secret': SECRET },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ name: 'User Name', avatar_url: 'http://a' });
  });

  it('returns a group profile for kind=group', async () => {
    const { app } = await buildApp();
    const res = await app.inject({
      method: 'GET',
      url: '/sessions/5/profile?kind=group&id=g1',
      headers: { 'x-zalo-worker-secret': SECRET },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ name: 'Group Name', avatar_url: null });
  });

  it('returns 409 when there is no live session', async () => {
    const sessions = fakeSessions();
    sessions.getUserInfo.mockRejectedValueOnce(new NoSessionError(5));
    const { app } = await buildApp({ sessions: sessions as never });
    const res = await app.inject({
      method: 'GET',
      url: '/sessions/5/profile?kind=user&id=u1',
      headers: { 'x-zalo-worker-secret': SECRET },
    });
    expect(res.statusCode).toBe(409);
  });

  it('returns 502 when the profile lookup fails for another reason', async () => {
    const sessions = fakeSessions();
    sessions.getUserInfo.mockRejectedValueOnce(new Error('boom'));
    const { app } = await buildApp({ sessions: sessions as never });
    const res = await app.inject({
      method: 'GET',
      url: '/sessions/5/profile?kind=user&id=u1',
      headers: { 'x-zalo-worker-secret': SECRET },
    });
    expect(res.statusCode).toBe(502);
  });
});

describe('POST /sessions/:channelId/send (text)', () => {
  it('sends text and returns the msg_id', async () => {
    const sessions = fakeSessions();
    const { app } = await buildApp({ sessions: sessions as never });
    const res = await app.inject({
      method: 'POST',
      url: '/sessions/5/send',
      headers: { 'x-zalo-worker-secret': SECRET, 'content-type': 'application/json' },
      payload: { thread_id: '111', kind: 'group', content: 'hello group' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ msg_id: 'text-1' });
    expect(sessions.sendText).toHaveBeenCalledWith(5, '111', ZaloThreadKind.Group, 'hello group', undefined);
  });

  it('maps NoSessionError to 409', async () => {
    const sessions = fakeSessions();
    sessions.sendText.mockRejectedValueOnce(new NoSessionError(5));
    const { app } = await buildApp({ sessions: sessions as never });
    const res = await app.inject({
      method: 'POST',
      url: '/sessions/5/send',
      headers: { 'x-zalo-worker-secret': SECRET, 'content-type': 'application/json' },
      payload: { thread_id: '111', kind: 'user', content: 'hi' },
    });
    expect(res.statusCode).toBe(409);
    expect(res.json().error).toBe('no_session');
  });

  it('maps an unexpected error to 500', async () => {
    const sessions = fakeSessions();
    sessions.sendText.mockRejectedValueOnce(new Error('unexpected'));
    const { app } = await buildApp({ sessions: sessions as never });
    const res = await app.inject({
      method: 'POST',
      url: '/sessions/5/send',
      headers: { 'x-zalo-worker-secret': SECRET, 'content-type': 'application/json' },
      payload: { thread_id: '111', kind: 'user', content: 'hi' },
    });
    expect(res.statusCode).toBe(500);
    expect(res.json().error).toBe('send_failed');
  });
});

describe('POST /sessions/:channelId/send (attachment)', () => {
  it('streams the multipart file to sendAttachment and returns the msg_id', async () => {
    const sessions = fakeSessions();
    const { app } = await buildApp({ sessions: sessions as never });
    const { body, contentType } = buildMultipart(
      { thread_id: '222', kind: 'group', caption: 'a photo' },
      { filename: 'pic.jpg', content: Buffer.from('fake-image-bytes') }
    );

    const res = await app.inject({
      method: 'POST',
      url: '/sessions/5/send',
      headers: { 'x-zalo-worker-secret': SECRET, 'content-type': contentType },
      payload: body,
    });

    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ msg_id: 'att-1' });
    expect(sessions.sendAttachment).toHaveBeenCalledWith(
      5,
      '222',
      ZaloThreadKind.Group,
      { filename: 'pic.jpg', data: Buffer.from('fake-image-bytes') },
      'a photo'
    );
  });

  it('maps ZaloFileRejectedError to 422', async () => {
    const sessions = fakeSessions();
    sessions.sendAttachment.mockRejectedValueOnce(new ZaloFileRejectedError('pic.jpg', 'rejected'));
    const { app } = await buildApp({ sessions: sessions as never });
    const { body, contentType } = buildMultipart(
      { thread_id: '222', kind: 'user', caption: '' },
      { filename: 'pic.jpg', content: Buffer.from('x') }
    );

    const res = await app.inject({
      method: 'POST',
      url: '/sessions/5/send',
      headers: { 'x-zalo-worker-secret': SECRET, 'content-type': contentType },
      payload: body,
    });

    expect(res.statusCode).toBe(422);
    expect(res.json().error).toBe('file_rejected');
  });
});
