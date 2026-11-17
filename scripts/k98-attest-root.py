"""K98 (Kevin moln): fetch Apple App Attestation Root CA (public) and print its base64 DER and SHA-256. No secrets."""
import base64, hashlib, re, urllib.request
pem = urllib.request.urlopen("https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem", timeout=30).read().decode()
der = base64.b64decode("".join(l for l in pem.splitlines() if l and not l.startswith("-----")))
print("SHA256", hashlib.sha256(der).hexdigest(), "LEN", len(der))
b = base64.b64encode(der).decode()
for i in range(0, len(b), 100): print("B64", b[i:i + 100])
