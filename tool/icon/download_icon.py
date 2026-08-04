import requests
import sys

url = "https://toppng.com/uploads/preview/waze-logo-png-download-11662069635umvodtrsze.png"
headers = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://toppng.com/free-image/waze-logo-png-download-PNG-free-PNG-Images_478863",
    "Sec-Fetch-Dest": "image",
    "Sec-Fetch-Mode": "no-cors",
    "Sec-Fetch-Site": "same-origin",
}
out = "tool/icon/waze_logo.png"
try:
    r = requests.get(url, headers=headers, timeout=60, allow_redirects=True)
    print("HTTP:", r.status_code, "len:", len(r.content))
    if r.status_code == 200 and len(r.content) > 1000:
        with open(out, "wb") as f:
            f.write(r.content)
        print("Saved", out)
    else:
        print("FAILED - first bytes:", r.content[:120])
except Exception as e:
    print("ERROR:", e)
    sys.exit(1)
