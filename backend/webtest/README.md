# webtest — one-file voice test page (Safari/iPhone + AirPods)

`index.html` (no framework, no build): hold the button -> Safari speech recognition (sv-SE) -> `/answer` (anonymous sign-in, publishable key) -> `/tts` (voice "Adam" via `/voices`) -> playback. Shows the transcript, the answer and timings in ms (released -> transcript -> first text -> first sound).
TTS starts per finished sentence. A text box covers devices without speech recognition. The publishable key in the file is public by design.
Deploy: static site on Vercel (Hobby/free), root directory `backend/webtest`, framework "Other", no build command.
