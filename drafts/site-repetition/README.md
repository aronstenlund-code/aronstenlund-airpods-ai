# Utkast: demosidan för repetitionsläget i Apple-stil (Kelly, Ke51 → Ke54, D160)

**Publiceras inte.** Mappen ligger utanför `site/` (Pages publicerar bara `site/**`), och sidan har
`noindex, nofollow`. Den läggs in i `site/` först när **Aron har sagt ja** och Tobys T18 är godkänt på telefon.

## Vad sidan är (Ke54)
En fristående sida (`index.html`) enligt `docs/design/SYSTEM.md` §0:
- **Systemtypsnitt** (SF Pro på Apple-enheter, inget webbtypsnitt att ladda), Apples gråskala och vår blå som enda
  färg. Ljust och mörkt följer telefonen.
- **En knapp:** "Mejla mig när appen finns", som leder till väntelistan. I sidhuvudet står samma sak som en textlänk.
- **Rubriken:** "Plugga med AirPods utan att röra mobilen." och under den "Fota materialet. Få provfrågor med A-svar."
  (Deangelos budskap i Ke54).
- **Tre steg med riktiga skärmbilder från appen** (Fota materialet, Få frågor med A-svar, Tryck Starta prov).
- **Styr med ett tryck:** en grå ruta med en tryckdemo utan server (tre påhittade frågor; 1 tryck långt svar,
  2 kort, 3 paus, och under paus fortsätter vilket tryck som helst), plus tre korta fakta.
- **Väntelistan** med samma anrop, samtyckestext och version (`2026-11-06`) som `site/index.html`.
- Inga kort i kort, ingen skugga, ingen gradient, ingen glöd och ingen Elias-hero. Elias kan komma tillbaka i
  annonserna, men sidan visar produkten.

Ke51:s byggdelar (`build.py`, `hero.html`, `steps.html`, `draft.css`, `draft.js`) är borttagna, eftersom sidan inte
längre bygger på `site/index.html`.

## Skärmbilderna
`img/*.webp` (600 px breda, ljust och mörkt) kommer från **A87** (CI "Simulator screenshots" 43519509067, 3382ae2,
iPhone 17 Pro): `repPlayFirst`, `repMaterial`, `repList` och `repHome`. Byt igen om skärmarna ändras före publicering.

## Före publicering
1. Arons ja och T18 godkänt på telefon.
2. **Kontrollera påståendena mot telefonen:** "Ingen mikrofon" (R9, orange prick), "Samma ordning varje varv"
   (R5d) och "Dela med klassen" (A81/K47). Det som inte är provat får texten "Kommer snart" eller stryks.
3. Skärmbilder från A87.
4. Flytta till `site/`. Då behövs: `og`-bild med den nya rubriken, FAQ/JSON-LD om repetitionsläget, canonical,
   Lighthouse minst 95 och `site/` högst 2 MB.
5. Den gamla livedemon (Standardläge och Förhör mig) och "Vad kan Earmind?" finns inte på den här sidan. Ska de vara
   kvar, blir de en egen sida ("Fler lägen, beta") som den här länkar till.

## Skärmbilder av utkastet
`node drafts/site-repetition/shots.js` med en http-server från repots rot (typsnitt och bilder blockeras under
`file://`): `python -m http.server 8765` och `BASE=http://127.0.0.1:8765`. Bilderna hamnar i `bilder/`.
