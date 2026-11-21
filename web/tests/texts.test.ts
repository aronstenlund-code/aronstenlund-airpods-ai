import { describe, expect, it } from 'vitest';
import { allTexts, chosenLanguage, clockText, dayText, grouped, translator } from '../src/texts';

describe('the language (D253)', () => {
  it('always starts in English; Swedish only when the user has chosen it (D253)', () => {
    expect(chosenLanguage(null)).toBe('en');
    expect(chosenLanguage('sv')).toBe('sv');
    expect(chosenLanguage('en')).toBe('en');
    expect(chosenLanguage('de')).toBe('en'); // anything else that was stored is not a choice
  });

  it('has every text in both languages, with the same things to fill in', () => {
    const names = (text: string): string[] => (text.match(/\{[a-z]+\}/g) ?? []).sort();
    for (const key of Object.keys(allTexts.en) as (keyof typeof allTexts.en)[]) {
      expect(allTexts.sv[key], key).toBeTruthy();
      expect(names(allTexts.sv[key]), key).toEqual(names(allTexts.en[key]));
    }
    expect(Object.keys(allTexts.sv).sort()).toEqual(Object.keys(allTexts.en).sort());
  });

  it('fills in the numbers and names', () => {
    expect(translator('sv')('costShort', { n: 120, m: 88 })).toBe('120 krediter \u00b7 du har 88');
    expect(translator('en')('voiceLabel', { name: 'Astrid' })).toBe('Voice, Astrid');
    expect(grouped(1236, 'en')).toBe('1,236');
    expect(grouped(1236, 'sv')).toBe('1\u00a0236');
    expect(dayText('2026-12-01', 'en')).toBe('December 1');
    expect(dayText('2026-12-01T00:00:00Z', 'sv')).toBe('1 december');
    expect(clockText(452)).toBe('7:32');
  });

  it('says the screen must be on and how far away the phone may be (D250)', () => {
    expect(allTexts.sv.screenLine).toContain('skärmen');
    expect(allTexts.sv.screenLine).toContain('10\u00a0meter'); // the number is not broken from its unit
    expect(allTexts.en.screenLine).toContain('10\u00a0m (33\u00a0ft)');
    expect(allTexts.sv.guideIphoneSteps).toContain('Automatisk låsning');
    expect(allTexts.en.guideIphoneSteps).toContain('Auto-Lock');
    expect(allTexts.en.creditsBuy).toBe('Purchases come with the iOS app.');
    expect(allTexts.sv.creditsBuy).toBe('Köp kommer i iOS-appen.');
  });

  it('never offers to buy on the web (D249)', () => {
    for (const lang of ['en', 'sv'] as const) {
      const all = Object.values(allTexts[lang]).join(' ');
      expect(all).not.toMatch(/Top up|Fyll på|Weekly pass|Veckokort/);
    }
  });
});
