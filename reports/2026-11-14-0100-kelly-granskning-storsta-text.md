# Kelly: största text i repetitionsflödet (A87, SYSTEM §10)

Datum: 2026-11-14 01:00. Bilder: CI "Simulator screenshots" **43528102988** (iPhone 17 Pro) och **43528108671** (iPhone
SE), största textstorlek (accessibility5), kod 84889b9, ljust. Kontaktblad: `reports/2026-11-14-storsta-text/`
(`g1`/`g2` 17 Pro, `g3`/`g4` SE). Regler: `docs/design/SYSTEM.md` §10 (förtydligad 2026-11-14) och §0.1 fråga 2
(nästa steg ska synas).

## Det som håller
- **Rubriker:** "Prov från din skola" och provets namn är inline i navigationsraden och står som första rad med
  radbrytning (regel 4). "Prov" på Hem är kort och får vara stor.
- **Avstavning med bindestreck** ("Biologipro-vet", "fotosynte-sen", "Kungshol-mens") är tillåten (regel 1, förtydligad).
- **Formulären** (Nytt prov, Publicera prov, Redigera): etiketten står över värdet, och inget kapas.
- **Huvudknappen** (Starta prov, Skapa frågor, Publicera prov, Lägg till i mina prov) ligger fast nederst och syns
  på båda telefonerna.
- **K4 stängd:** `repShare` visar "Ljud: 4 av 6 klara · Görs i spelordning" och en grå Dela-knapp.
- Kontrollskärmen börjar med instruktionen ("Tryck en gång nu"), och den syns.

## Fynd
| # | Scen | Fynd | Ska vara | Nivå |
|---|---|---|---|---|
| **S1** | `moreModes` (Välj läge), 17 Pro och SE | Ord bryts **utan bindestreck** bredvid BETA-märket: "Stan / dardl / äge", "Provlä / ge", "Intervj / u", och på SE även märket "BET / A". | Vid `dynamicTypeSize >= .accessibility1` står BETA **under** namnet, eller tas märket bort från raderna och står i sektionens fotnot (Ke53 punkt 11). Ett ord bryts aldrig utan bindestreck (§10 regel 1). | **Hög** |
| **S2** | `repPlayFirst`, `repPlayThink`, `repPaused`, främst på SE | Frågan kapas nederst ("fotosynte-sen?" halvt), och **"Tryck på AirPods för svaret" syns inte** på SE (på 17 Pro syns bara "Tryck på AirPods för"). I pausat läge skyms "Pausad" och "Tryck på AirPods för att fortsätta". Det är skärmens viktigaste rad för en ny användare (N1). | Vid tillgänglighetsstorlekar: ringen blir texten "6 s" på samma rad som "Fråga 1 av 5", och tryckraden (●/●●/●●●) visas inte. Den står på kontrollskärmen och som VoiceOver-tips. Ordningen blir frågan, därefter N1-raden eller pausraden, och sist Avsluta. Allt ska synas utan att rulla på SE. | **Hög** |
| **S3** | `repHomeEmpty`, `repHome` | Knapparna i nedre raden ("Fler lägen · Beta", "⊕ Nytt prov", "Öppna länk") flyter **ovanpå texten**: ingressen "och läser upp …" och raden "Frågor och svar" syns igenom. | Ge nedre raden systemets bakgrund (`.toolbarBackground(.visible, for: .bottomBar)`) eller luft nederst i listan som är minst lika hög som raden. På tillgänglighetsstorlekar: flytta "Öppna länk" till en meny uppe till höger, som Angela Fable föreslog, så att nedre raden bara har Nytt prov. | Medel |
| S4 | `repControls`, `repControlsMissing` | "Medan frågan spelas:" och raderna under den skyms av Starta prov-raden innan man rullar. | Det får rulla, men lägg en tunn skiljelinje eller bakgrund på den fasta nedre delen (som S3), så att det syns att innehållet fortsätter. | Låg |
| S5 | `repMaterial` | Raden "Lägg till dokument" står halvt under den fasta knappen innan man rullar. | Samma som S3: bakgrund på den fasta delen. | Låg |

## Till Angela Fable
S1 och S2 först. De bryter mot SYSTEM §10 och mot "nästa steg syns alltid" (D160). Sedan S3 (bakgrund på nedre raden,
som löser S4 och S5 på samma gång). Skärmbilder med största text på SE räcker för att bekräfta.

## Test
Simulatorbilder i största textstorlek, inte telefon. Mörkt läge i största text är inte granskat (bara ljust finns i
kontaktbladen; mörkt bör följa samma layout).
