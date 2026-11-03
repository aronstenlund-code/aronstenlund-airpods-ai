# Swedish short prompts — STT benchmark (exact-match set)

Phase 1 reference material (assignment §3.8). Thirty short items of the kind the product must
detect and answer: incomplete phrases, single terms, spoken arithmetic and short questions.
Scored by WER/CER **and** exact-match rate after normalisation (whole item correct or not).

Rules for the reader: say each item once, as a natural utterance, with a clear pause of at least
two seconds before and after. Numbers are spoken as written in the "Spoken" column. The
"Reference" column is the exact scoring text; the normaliser maps digits ↔ Swedish number words,
so a transcriber that writes "100" for "hundra" is not penalised.

| # | Category | Spoken (reader says) | Reference (scoring text) |
|---|---|---|---|
| 1 | maths | roten ur hundra | roten ur hundra |
| 2 | maths | fem plus två | fem plus två |
| 3 | maths | tolv gånger åtta | tolv gånger åtta |
| 4 | maths | hundra delat med fyra | hundra delat med fyra |
| 5 | maths | vad är sju i kvadrat | vad är sju i kvadrat |
| 6 | maths | tjugofem procent av tvåhundra | tjugofem procent av tvåhundra |
| 7 | maths | vad är pi | vad är pi |
| 8 | maths | derivatan av x i kvadrat | derivatan av x i kvadrat |
| 9 | science | fotosyntes | fotosyntes |
| 10 | science | vad är ljusvågor | vad är ljusvågor |
| 11 | science | vad är en atom | vad är en atom |
| 12 | science | hur många kromosomer har en människa | hur många kromosomer har en människa |
| 13 | science | vad är ljudets hastighet | vad är ljudets hastighet |
| 14 | science | vad är mitokondrier | vad är mitokondrier |
| 15 | science | newtons andra lag | newtons andra lag |
| 16 | science | vad är ph-värde | vad är ph-värde |
| 17 | history | när började andra världskriget | när började andra världskriget |
| 18 | history | vem var gustav vasa | vem var gustav vasa |
| 19 | history | när föll berlinmuren | när föll berlinmuren |
| 20 | history | franska revolutionen | franska revolutionen |
| 21 | history | vem var sveriges första statsminister | vem var sveriges första statsminister |
| 22 | history | när blev sverige medlem i eu | när blev sverige medlem i eu |
| 23 | language | vad betyder ambivalent | vad betyder ambivalent |
| 24 | language | vad är ett adverb | vad är ett adverb |
| 25 | language | hur stavas man restaurang | hur stavas man restaurang |
| 26 | geography | vad är huvudstaden i australien | vad är huvudstaden i australien |
| 27 | geography | hur många invånare har sverige | hur många invånare har sverige |
| 28 | geography | vilket är världens längsta flod | vilket är världens längsta flod |
| 29 | general | förklara växthuseffekten | förklara växthuseffekten |
| 30 | general | kan någon förklara det igen | kan någon förklara det igen |

Notes:
- Items 1–8 exercise spoken arithmetic and maths vocabulary (the "roten ur" / "plus" family from the
  product spec). Items 9–16 are bare terms and short science questions. Items 17–22 are history,
  23–28 language and geography, 29–30 imperative/colloquial forms that the question gate must catch.
- Item 16: the reference keeps the hyphen in "ph-värde"; the normaliser treats a hyphen as a word
  boundary, so "pH-värde" and "ph värde" both match while "phvärde" does not (rule in `LumenScoring/TextNormalizer`).
- Item 25 is deliberately ungrammatical ("hur stavas man") because that is how students actually ask.
