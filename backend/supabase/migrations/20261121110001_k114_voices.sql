-- K114 (D252): voices for the web beta and English users. Listing and catalog rows only: no audio is made and nobody
-- has listened (D180, Aron's rule). Metadata from ElevenLabs' library (kevin-live run 44895219661) and the account's
-- own voices (run 44894502864). Nothing is deleted, here or in ElevenLabs: retired rows get enabled=false.
insert into public.voice_catalog (voice_id,name,gender,age,accent,language,preview_url,description,sort,review) values
-- Aron's own voice "Chinese Americano." (cloned in the account); only its name in the app is new
('8XcXJz3rvAjZSQNgtWCy','PS3 character','male','young','american','en',null,'A character voice',40,false),
-- native English speakers (review=false)
('ljvo28cz3g2pJ1roaSVU','Niki','female','young','british','en','https://storage.googleapis.com/eleven-public-prod/database/workspace/3c39cff37cff49c59789ba8ef932d2d8/voices/ljvo28cz3g2pJ1roaSVU/4e3e132c-ee84-429e-8eb4-d5b37b161cb3.mp3','Calm and soothing, British',30,false),
('6pePhCBvwi0Dte0AkHf3','Chris','male','middle_aged','british','en','https://api.us.elevenlabs.io/v1/voices/6pePhCBvwi0Dte0AkHf3/previews/audio?payload=eyJ2b2ljZV9zb3VyY2UiOiJjdXN0b20iLCJ3b3Jrc3BhY2VfaWQiOiI1MGI4NjlkNWI5NDc0NTUyOTExMmYyOGE2ZDJkMTFlYSIsImZpbGVuYW1lIjoiOWNiZjU5MzktOWQzMi00MGFlLWJiNTYtNThjNjA1MzIzMzIxLm1wMyIsInRpbWVzdGFtcCI6MTc5NTI1NTIwMDAwMDAwMH0%3D','Clear and calm, South-East England',31,false),
('lB9K9mKVhRzwTiRZXQ3b','Paul','male','middle_aged','american','en','https://api.us.elevenlabs.io/v1/voices/lB9K9mKVhRzwTiRZXQ3b/previews/audio?payload=eyJ2b2ljZV9zb3VyY2UiOiJjdXN0b20iLCJ3b3Jrc3BhY2VfaWQiOiI1M2JkMGMyNmYyMDM0Y2QxYmNkOTM0ZTVlNTE0NGU2OCIsImZpbGVuYW1lIjoiZTE1MmE5ZWQtNzExNi00Y2ZlLWJjMmItM2ZlZGYzNGUyYmQyLm1wMyIsInRpbWVzdGFtcCI6MTc5NTI1NTIwMDAwMDAwMH0%3D','Friendly and warm, American',32,false),
('qIamWLq3y7Ucaa02ln95','Alyssa','female','middle_aged','american','en','https://storage.googleapis.com/eleven-public-prod/database/workspace/f6e90e0503f446e7a5fa455f81a2ef8a/voices/qIamWLq3y7Ucaa02ln95/741a2079-086e-4aa1-aa45-1de318f3c0aa.mp3','Natural and casual, American',33,false),
-- strong accents in English (review=true: admin only until Aron has listened)
('AuzRHzXe606dpYMHSHYp','Ajay','male','middle_aged','indian','en','https://api.us.elevenlabs.io/v1/voices/AuzRHzXe606dpYMHSHYp/previews/audio?payload=eyJ2b2ljZV9zb3VyY2UiOiJjdXN0b20iLCJ3b3Jrc3BhY2VfaWQiOiIwNjE3ZDAyYWRkNGU0ZjNlYTQzMjAyZmJlZGQyZTY4NiIsImZpbGVuYW1lIjoiZTg3ZTQ0ZTItZDhlMi00NDk2LWFlODItNDA0ODA3MzE4MDgxLm1wMyIsInRpbWVzdGFtcCI6MTc5NTI1NTIwMDAwMDAwMH0%3D','English with a strong Indian accent, deep',204,true),
('Qc0X0JnOfc5XzetLVusF','Wei','male','young','chinese','en','https://storage.googleapis.com/eleven-public-prod/database/workspace/79b9c36e127d4fca8391747eda70a00a/voices/Qc0X0JnOfc5XzetLVusF/n24Z6eGUFcCwFi2uquEz.mp3','English with a strong Chinese accent, warm',205,true)
on conflict (voice_id) do update set name=excluded.name, gender=excluded.gender, age=excluded.age, accent=excluded.accent,
  language=excluded.language, preview_url=excluded.preview_url, description=excluded.description, sort=excluded.sort, review=excluded.review, enabled=true;

-- Marlon (Aron's cloned voice) is no longer offered (also RETIRED_VOICE_IDS in tts/voices.ts); Hindi B and Kines B are
-- replaced by Ajay and Wei, whose library descriptions say "strong". Kept in the table, off.
update public.voice_catalog set enabled=false where voice_id in ('L5eqCY1Zc0lkxB6M9pRQ','9IAi5SvX5bAamiDIdLdI','PyMZFI2sitc2HbXqPlKW');
