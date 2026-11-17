"""K94 (Kevin moln): fetch Apple Root CA - G3 (public) and print its base64 DER and SHA-256, so the server can pin it.
No secrets, no Supabase calls. Usage: python scripts/k94-apple-root.py"""
import base64, hashlib, urllib.request
der = urllib.request.urlopen("https://www.apple.com/certificateauthority/AppleRootCA-G3.cer", timeout=30).read()
print("SHA256", hashlib.sha256(der).hexdigest())
print("LEN", len(der))
b = base64.b64encode(der).decode()
for i in range(0, len(b), 100): print("B64", b[i:i + 100])
