# webtest — one-file voice test page (Safari/iPhone + AirPods)

`index.html` (no framework, no build): hold the button -> Safari speech recognition (sv-SE) -> `/answer` (anonymous sign-in, publishable key) -> `/tts` (voice "Adam" via `/voices`) -> playback. Shows the transcript, the answer and timings in ms (released -> transcript -> first text -> first sound).
TTS starts per finished sentence. A text box covers devices without speech recognition. The publishable key in the file is public by design.
Deploy: static site on Vercel (Hobby/free), root directory `backend/webtest`, framework "Other", no build command.

Rizzläge panel (D43): style chips, 'Den andra sa …' text box + mic, 'Tystnad' (stall) and 'Öppningsrad' (opener) buttons, optional interests/profile. Calls `/answer` with `persona:"social"` + `social{}`, speaks the best option through `/tts`, lists all options (tap = say it again and add it to the in-page conversation). Nothing is stored.
