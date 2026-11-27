# Ke93 – Kellys fem saker, och texten som hörs

Angela Schrute (moln, Opus 5.5), 2026-11-27. Uppdrag: Deangelo 02:59 ("Kellys fem rader till dig (Ke93) om de inte är gjorda"); kön rad 584 (Kellys svar på D269) och 585 (Ke93). Kellys bilder: `kelly/screens-d269`.

## Gjort

1. **Aktiveringsraden som ett block.** Meningen står hel: "Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI." / "Question you're not prepared for? Say [ … ] so our AI activates." Fältet ligger på egen rad under, i hela bredden, med platshållaren "t.ex. Hjälp mig" / "e.g. Help me". Samma vy i Inställningar.
2. **Inte före första svaret.** Lyssnar visar aktiveringsraden först när det har kommit ett svar, i det här passet eller någon gång förut (Historik), eller när ord redan är ifyllda. Första gången syns bara "Fråga vad du vill. Svaret kommer i örat och här." (`ListeningModel.showsActivationWords`).
3. **Välkommens rad om mikrofonen:** "… Starta prov och Säg i AirPods använder aldrig mikrofonen. Att fråga högt gör det, när du har sagt ja på nästa skärm." / "… Start quiz and Say in AirPods never use the microphone. Asking out loud does, after you say yes on the next screen."
4. **Felkortet säger inte "Försök igen" två gånger:** undertexten är "Vår server är upptagen." / "Our server is busy.", och knappen heter Försök igen.
5. **Engelska demodata:** i `listening`, `cannotAnswer` och `listeningProv` följer frågorna, svaren och proven appens språk, som i `listeningActivation`. Simulatorn sparar proven mellan bilderna, så den engelska körningen byter ut de svenska.
- **Kellys svar på D269 (a): texten som hörs.** Den står grå under brickan "● Lyssnar" medan man talar, högst två rader där slutet syns, och försvinner när orden är klara och svaret kommer (`ListeningModel.heardLine`). Appens egen röst visas inte. VoiceOver: "Hör: …" / "Hearing: …".
- (b) Ingen "jag hörde dig"-ton, som Kelly bestämde.

## Testresultat

BYGGRAD

- `LumenTests/Ke93Tests.swift`, 6 tester:
  - kortets nya undertext och knapp;
  - Arons mening hel;
  - aktiveringsraden visas inte före första svaret, men efter ett svar, med ifyllda ord och med ett svar i Historik;
  - texten som hörs: den syns, slutet visas när den är lång, och den försvinner när orden är klara.
- **Röd först:** bara kortets text kunde prövas med befintligt API (`angela/ke93-test-rod`); resten använder nytt API.

BILDRAD

## Kvar

Kelly har inte sett Historik under ⋯ eller sökfältet på bild. Bilderna finns nu (`fable/screens-historik`).
