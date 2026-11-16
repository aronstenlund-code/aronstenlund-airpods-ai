# Nattlig apptest (T31)

`.github/workflows/apptest-nightly.yml` körs varje natt klockan 02:00 UTC (03:00 svensk vintertid) och går också att
starta för hand. Det kör T24 (`fullflow.sh`), T27 (`offline.sh`), T28 (`reading.sh`), T29 (`a107.sh`) och T30
(`t30.sh`) parallellt, på en macOS-runner var, med falskt ljud (D180, 0 ElevenLabs).

Sista jobbet skriver `YYYY-MM-DD.md` här: en rad per test, grön eller röd, med stegen som föll och en länk till
körningen. Simulatorn räknas inte som verifiering på enhet.
