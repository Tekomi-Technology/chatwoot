import { describe, it, expect } from 'vitest';
import {
  ZaloThreadKind,
  encodeSourceId,
  toZcaThreadType,
  normalizeIncoming,
  normalizeReaction,
  normalizeUndo,
} from '../src/types.js';

describe('encodeSourceId', () => {
  it('prefixes the thread id with its kind so a user id can never collide with a group id', () => {
    expect(encodeSourceId(ZaloThreadKind.User, '123')).toBe('user:123');
    expect(encodeSourceId(ZaloThreadKind.Group, '123')).toBe('group:123');
  });
});

describe('toZcaThreadType', () => {
  it('maps thread kinds to the zca-js ThreadType ordinals', () => {
    expect(toZcaThreadType(ZaloThreadKind.User)).toBe(0);
    expect(toZcaThreadType(ZaloThreadKind.Group)).toBe(1);
  });
});

describe('normalizeIncoming', () => {
  it('normalizes a 1:1 text message', () => {
    const raw = {
      type: 0,
      threadId: '111',
      isSelf: false,
      data: { msgId: '999', uidFrom: '222', dName: 'Khách', msgType: 'webchat', content: 'hi' },
    };
    const msg = normalizeIncoming(raw);
    expect(msg).toMatchObject({
      kind: ZaloThreadKind.User,
      threadId: '111',
      msgId: '999',
      senderUid: '222',
      senderName: 'Khách',
      text: 'hi',
      isSelf: false,
    });
    expect(msg.quoteMsgId).toBeUndefined();
  });

  it('normalizes a group message (type 1)', () => {
    const raw = {
      type: 1,
      threadId: '555',
      data: { msgId: '1', uidFrom: '2', dName: 'Member', msgType: 'webchat', content: 'yo' },
    };
    expect(normalizeIncoming(raw).kind).toBe(ZaloThreadKind.Group);
  });

  it('treats uidFrom "0" as a self-sent message even without an explicit isSelf flag', () => {
    const raw = { type: 0, threadId: '1', data: { msgId: '1', uidFrom: '0', msgType: 'webchat', content: 'me' } };
    expect(normalizeIncoming(raw).isSelf).toBe(true);
  });

  it('uses the media caption as the display text for a media message', () => {
    const raw = {
      type: 0,
      threadId: '1',
      data: {
        msgId: '1',
        uidFrom: '2',
        msgType: 'chat.video.msg',
        content: { href: 'https://example.com/v.mp4', description: 'caption text' },
      },
    };
    const msg = normalizeIncoming(raw);
    expect(msg.text).toBe('caption text');
    expect(msg.classified).toMatchObject({ kind: 'media', mediaType: 'video' });
  });

  it('captures the quoted message id and a reconstructable quote source', () => {
    const raw = {
      type: 0,
      threadId: '1',
      data: {
        msgId: '10',
        uidFrom: '2',
        dName: 'X',
        msgType: 'webchat',
        content: 'reply body',
        cliMsgId: 'c1',
        ts: '123',
        ttl: 0,
        quote: { globalMsgId: '9' },
      },
    };
    const msg = normalizeIncoming(raw);
    expect(msg.quoteMsgId).toBe('9');
    expect(msg.quoteSrc).toMatchObject({ uidFrom: '2', msgId: '10', cliMsgId: 'c1', msgType: 'webchat' });
  });
});

describe('normalizeReaction', () => {
  it('extracts the reacted message id and emoji code from a group reaction', () => {
    const raw = {
      isGroup: true,
      threadId: '777',
      data: {
        uidFrom: '3',
        dName: 'An',
        content: { rMsg: [{ gMsgID: '42' }], rIcon: '/-heart' },
      },
    };
    const evt = normalizeReaction(raw);
    expect(evt).toMatchObject({
      kind: ZaloThreadKind.Group,
      threadId: '777',
      reactedMsgId: '42',
      icon: '/-heart',
      senderName: 'An',
      isSelf: false,
    });
  });

  it('defaults to an empty icon (removal) when rIcon is absent', () => {
    const raw = { threadId: '1', data: { content: { rMsg: [{ gMsgID: '1' }] } } };
    expect(normalizeReaction(raw).icon).toBe('');
  });
});

describe('normalizeUndo', () => {
  it('extracts the recalled message id and self flag', () => {
    const raw = { threadId: '1', isSelf: true, data: { uidFrom: '0', content: { globalMsgId: '55' } } };
    expect(normalizeUndo(raw)).toEqual({
      kind: ZaloThreadKind.User,
      threadId: '1',
      recalledMsgId: '55',
      isSelf: true,
    });
  });

  it('marks a group undo by isGroup or type 1', () => {
    const raw = { threadId: '1', type: 1, data: { content: { globalMsgId: '1' } } };
    expect(normalizeUndo(raw).kind).toBe(ZaloThreadKind.Group);
  });
});
