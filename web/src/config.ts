/// Kevin's backend (backend/README.md, "Connect the app"). The publishable key is public by design: it grants
/// nothing without a user's token. No other key is, or may ever be, in the web beta.
export interface BackendConfig {
  projectURL: string;
  publishableKey: string;
}

export const backend: BackendConfig = {
  projectURL: 'https://xjczbzfkmbjdebwlccki.supabase.co',
  publishableKey: 'sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8',
};

/// D180: test traffic (Toby, Oscar, CI) asks the server for silent audio and is counted apart from users.
/// On with `?test=1` in the address (or `?test=oscar-qa`, `?test=oscar-qa+slow`: who is testing and how the fake
/// audio should behave, K64/K100); off with `?test=0`. It stays on for the tab. Returns what `x-earmind-test` carries,
/// or null for a user.
export function testTraffic(search: string, session: Pick<Storage, 'getItem' | 'setItem'> | null): string | null {
  const asked = new URLSearchParams(search).get('test');
  if (asked !== null) {
    const words = asked.toLowerCase().replace(/[^a-z0-9 -]/g, '').trim().slice(0, 40);
    session?.setItem('earmind.test', asked === '0' || words === '' ? '' : words === '1' ? 'web' : words);
  }
  const kept = session?.getItem('earmind.test') ?? '';
  return kept === '' ? null : kept;
}
