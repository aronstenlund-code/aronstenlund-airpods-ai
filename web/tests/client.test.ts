import { describe, expect, it } from 'vitest';
import { ApiError, Client, OfflineError } from '../src/api/client';
import { DrillApi, examBody, saidBody } from '../src/api/drill';
import { testTraffic } from '../src/config';
import { FakeServer, MemoryStorage, token } from './fakes';

const config = { projectURL: 'https://example.supabase.co', publishableKey: 'pk' };
const t0 = 1_700_000_000_000;

function client(server: FakeServer, storage = new MemoryStorage(), now = () => t0, test: string | null = null, lang: 'en' | 'sv' = 'en'): Client {
  return new Client(config, server.fetch, storage, now, test, lang);
}

describe('the sign-in (anonymous, as in the app)', () => {
  it('makes an account for this browser at the first call, and keeps it', async () => {
    const storage = new MemoryStorage();
    const server = new FakeServer([token('jwt1', 'r1'), { status: 200, body: { limit: 1500, remaining: 1500 } }, { status: 200, body: { limit: 1500 } }]);
    const c = client(server, storage);
    expect(c.hasAccount).toBe(false);
    await c.call('drill', { action: 'quota' });
    await c.call('drill', { action: 'quota' });
    expect(server.paths()).toEqual(['/auth/v1/signup', '/functions/v1/drill', '/functions/v1/drill']);
    expect(server.requests[0].body).toEqual({});
    expect(server.requests[0].headers.apikey).toBe('pk');
    expect(server.requests[1].headers.Authorization).toBe('Bearer jwt1');
    expect(server.requests[1].headers.apikey).toBe('pk');
    // A new tab finds the same account.
    expect(client(new FakeServer([]), storage).hasAccount).toBe(true);
  });

  it('renews the token before it runs out, with the refresh token', async () => {
    const storage = new MemoryStorage();
    let now = t0;
    const server = new FakeServer([token('jwt1', 'r1', 3600), { status: 200, body: {} }, token('jwt2', 'r2'), { status: 200, body: {} }]);
    const c = client(server, storage, () => now);
    await c.call('drill', { action: 'quota' });
    now += 3_590_000; // ten seconds left
    await c.call('drill', { action: 'quota' });
    expect(server.paths()[2]).toBe('/auth/v1/token?grant_type=refresh_token');
    expect(server.requests[2].body).toEqual({ refresh_token: 'r1' });
    expect(server.requests[3].headers.Authorization).toBe('Bearer jwt2');
  });

  it('a 401 from a function renews the token and asks once more', async () => {
    const server = new FakeServer([token('jwt1', 'r1'), { status: 401, body: { error: { code: 'unauthorized' } } }, token('jwt2', 'r2'), { status: 200, body: { ok: true } }]);
    const c = client(server);
    expect(await c.call('drill', { action: 'quota' })).toEqual({ ok: true });
    expect(server.paths()).toEqual(['/auth/v1/signup', '/functions/v1/drill', '/auth/v1/token?grant_type=refresh_token', '/functions/v1/drill']);
  });

  it('only a real no ends the account: a server fault keeps it', async () => {
    const storage = new MemoryStorage();
    storage.setItem(Client.storageKey, JSON.stringify({ accessToken: 'old', refreshToken: 'r0', expiresAt: t0 - 1 }));
    const fault = new FakeServer([{ status: 503, body: { msg: 'down' } }]);
    await expect(client(fault, storage).call('drill', {})).rejects.toBeInstanceOf(ApiError);
    expect(storage.getItem(Client.storageKey)).toContain('r0'); // still the same account next time

    const refused = new FakeServer([{ status: 400, body: { error_code: 'refresh_token_not_found' } }, token('new', 'r9'), { status: 200, body: {} }]);
    await client(refused, storage).call('drill', {});
    expect(refused.paths()).toEqual(['/auth/v1/token?grant_type=refresh_token', '/auth/v1/signup', '/functions/v1/drill']);
    expect(storage.getItem(Client.storageKey)).toContain('new');
  });

  it('two calls at once share one sign-in', async () => {
    const server = new FakeServer([token('jwt1', 'r1'), { status: 200, body: {} }, { status: 200, body: {} }]);
    const c = client(server);
    await Promise.all([c.call('drill', {}), c.call('voices')]);
    expect(server.paths().filter((p) => p === '/auth/v1/signup')).toHaveLength(1);
    expect(server.requests[2].method).toBe('GET');
  });

  it('gives the server\'s words when it says no, and says offline when there is no answer', async () => {
    const server = new FakeServer([
      token('jwt1', 'r1'),
      { status: 402, body: { error: { code: 'quota_exceeded', message: 'Det här kostar 1 909 krediter. Du har 1 500 kvar.' }, cost: 1909, remaining: 1500 } },
    ]);
    const error = await client(server).call('drill', {}).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).isOutOfCredits).toBe(true);
    expect((error as ApiError).message).toContain('1 909');
    expect((error as ApiError).body.remaining).toBe(1500);

    const dead = new Client(config, async () => { throw new TypeError('Failed to fetch'); }, new MemoryStorage(), () => t0);
    await expect(dead.call('drill', {})).rejects.toBeInstanceOf(OfflineError);
  });

  it('marks test traffic, and only then (D180: silent audio, counted apart)', async () => {
    const plain = new FakeServer([token('a', 'b'), { status: 200, body: {} }]);
    await client(plain).call('drill', {});
    expect(plain.requests[1].headers['x-earmind-test']).toBeUndefined();
    const marked = new FakeServer([token('a', 'b'), { status: 200, body: {} }]);
    await client(marked, new MemoryStorage(), () => t0, 'web', 'sv').call('drill', {});
    expect(marked.requests[1].headers['x-earmind-test']).toBe('web');
    expect(marked.requests[1].headers['x-earmind-lang']).toBe('sv'); // K114: the server's words in the web's language

    const tab = new MemoryStorage();
    expect(testTraffic('', tab)).toBeNull();
    expect(testTraffic('?test=1', tab)).toBe('web');
    expect(testTraffic('', tab)).toBe('web'); // it stays on for the tab
    expect(testTraffic('?test=oscar-qa+slow', tab)).toBe('oscar-qa slow'); // who tests, and how the fake audio behaves
    expect(testTraffic('?test=0', tab)).toBeNull();
  });
});

describe('what is sent to /drill', () => {
  const draft = { clientID: 'c0ffee00-0000-4000-8000-000000000001', text: 'Första.\n\nAndra.', title: 'Första.', style: ' lugnt ', voiceID: 'v1' };

  it('a said text is saved and started in one call, one part per line', () => {
    const body = saidBody(draft, 'sv');
    expect(body.action).toBe('save');
    expect(body.start).toBe(true);
    expect(body.defer_audio).toBeUndefined();
    expect(body.lang).toBe('sv');
    expect(body.items).toEqual([{ kind: 'para', text: 'Första.' }, { kind: 'para', text: 'Andra.' }]);
    expect(body.drill).toMatchObject({ kind: 'text', said: true, style: 'lugnt', voice_id: 'v1', client_id: draft.clientID });
    const plain = saidBody({ ...draft, style: '  ', voiceID: null }, 'en').drill as Record<string, unknown>;
    expect('style' in plain).toBe(false);
    expect('voice_id' in plain).toBe(false);
  });

  it('a new exam is saved without sound: the credits are counted at Start exam', () => {
    const body = examBody({ clientID: 'x', title: 'Bio', subject: 'Biologi', grade: '9', covers: 'c'.repeat(900), questions: [{ question: 'Q?', short: 'S.', long: 'S. Mer.' }] }, 'en');
    expect(body.defer_audio).toBe(true);
    expect(body.start).toBeUndefined();
    expect((body.drill as { covers: string }).covers).toHaveLength(400);
    expect(body.items).toEqual([{ question: 'Q?', short: 'S.', long: 'S. Mer.' }]);
  });

  it('the cost of a text is asked without saving, and voices under review are not offered', async () => {
    const server = new FakeServer([
      token('a', 'b'),
      { status: 200, body: { cost: 14, remaining: 1500, enough: true } },
      { status: 200, body: { catalog: [{ voice_id: 'v1', name: 'Astrid' }, { voice_id: 'v2', name: 'Prov', review: true }], default_voice: { name: 'Adam' } } },
    ]);
    const api = new DrillApi(client(server, new MemoryStorage(), () => t0, null, 'sv'));
    expect(await api.costOfSaid(draft)).toMatchObject({ cost: 14 });
    expect(server.requests[1].body).toMatchObject({ action: 'cost', lang: 'sv' });
    expect(server.requests[1].body && 'start' in server.requests[1].body).toBe(false);
    const voices = await api.voices();
    expect(voices.catalog.map((v) => v.name)).toEqual(['Astrid']);
    expect(voices.defaultName).toBe('Adam');
  });
});
