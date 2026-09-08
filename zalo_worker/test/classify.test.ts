import { describe, it, expect } from 'vitest';
import { classifyMessage } from '../src/classify.js';

describe('classifyMessage', () => {
  it('classifies a plain webchat message as text', () => {
    expect(classifyMessage({ msgType: 'webchat', content: 'hello' })).toEqual({
      kind: 'text',
      text: 'hello',
    });
  });

  it('classifies a string content payload as text regardless of msgType', () => {
    expect(classifyMessage({ msgType: 'chat.text', content: 'hi there' })).toEqual({
      kind: 'text',
      text: 'hi there',
    });
  });

  it('classifies a photo as media with a derived filename', () => {
    const result = classifyMessage({
      msgType: 'chat.photo',
      content: { href: 'https://example.com/photos/pic.jpg?sig=abc' },
    });
    expect(result).toEqual({
      kind: 'media',
      mediaType: 'image',
      href: 'https://example.com/photos/pic.jpg?sig=abc',
      filename: 'pic.jpg',
      caption: '',
    });
  });

  it('falls back to a labelled placeholder when a photo href is not fetchable', () => {
    expect(classifyMessage({ msgType: 'chat.photo', content: { href: '' } })).toEqual({
      kind: 'fallback',
      text: '[Ảnh]',
    });
  });

  it('ensures a voice message filename has the m4a extension', () => {
    const result = classifyMessage({
      msgType: 'chat.voice',
      content: { href: 'https://example.com/voice/clip', title: 'clip' },
    });
    expect(result).toMatchObject({ kind: 'media', mediaType: 'audio', filename: 'clip.m4a' });
  });

  it('carries the description as caption for a video message', () => {
    const result = classifyMessage({
      msgType: 'chat.video.msg',
      content: { href: 'https://example.com/v.mp4', description: 'a caption' },
    });
    expect(result).toMatchObject({ kind: 'media', mediaType: 'video', caption: 'a caption' });
  });

  it('classifies a shared file', () => {
    const result = classifyMessage({
      msgType: 'share.file',
      content: { href: 'https://example.com/doc.pdf', title: 'doc.pdf' },
    });
    expect(result).toEqual({ kind: 'media', mediaType: 'file', href: 'https://example.com/doc.pdf', filename: 'doc.pdf', caption: '' });
  });

  it('classifies a sticker as a fallback placeholder (resolved later by the adapter)', () => {
    expect(classifyMessage({ msgType: 'chat.sticker', content: { id: 1, catId: 2 } })).toEqual({
      kind: 'fallback',
      text: '[Sticker]',
    });
  });

  it('builds a Google Maps link for a location message', () => {
    const result = classifyMessage({
      msgType: 'chat.location.new',
      content: { params: JSON.stringify({ lat: 10.5, lng: 106.7 }) },
    });
    expect(result).toEqual({
      kind: 'fallback',
      text: '📍 Vị trí: https://www.google.com/maps?q=10.5,106.7',
    });
  });

  it('falls back to a generic location label when coordinates are missing', () => {
    expect(classifyMessage({ msgType: 'chat.location.new', content: { params: {} } })).toEqual({
      kind: 'fallback',
      text: '📍 Vị trí',
    });
  });

  it('formats a shared contact card with name and phone', () => {
    const result = classifyMessage({
      msgType: 'chat.recommended',
      content: { params: { name: 'An', phone: '0900000000' } },
    });
    expect(result).toEqual({ kind: 'fallback', text: '👤 Danh thiếp: An — 0900000000' });
  });

  it('formats a link message with title and href', () => {
    const result = classifyMessage({
      msgType: 'chat.link',
      content: { href: 'https://example.com', title: 'Example' },
    });
    expect(result).toEqual({ kind: 'fallback', text: '🔗 Example\nhttps://example.com' });
  });

  it('formats a todo reminder', () => {
    const result = classifyMessage({
      msgType: 'chat.todo',
      content: { params: { content: 'Gọi khách' } },
    });
    expect(result).toEqual({ kind: 'fallback', text: '☑️ Nhắc việc: Gọi khách' });
  });

  it('degrades an unrecognised message type to a readable fallback instead of going blank', () => {
    const result = classifyMessage({ msgType: 'chat.something.new', content: {} });
    expect(result).toEqual({ kind: 'fallback', text: '[Tin Zalo loại chat.something.new — mở app để xem]' });
  });

  it('labels a completely unknown message type when msgType itself is missing', () => {
    const result = classifyMessage({});
    expect(result).toEqual({ kind: 'fallback', text: '[Tin Zalo loại không rõ — mở app để xem]' });
  });
});
