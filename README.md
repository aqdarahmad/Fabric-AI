# Fabric AI

Smart fabric inspection: **defect detection** (Roboflow), **fabric type analysis** and **quality / authenticity check** (OpenAI vision), with scan history, dashboard, PDF reports and CSV export. Built with Flutter (web + mobile) and a small Node server that keeps the API keys private.

## Architecture

```
Browser (Flutter web)  ──►  Node server (server/index.js)  ──►  Roboflow / OpenAI
                              │  serves build/web
                              └─ keeps API keys in env vars
```

## Deploy on Render (Web Service)

1. Render → **New → Web Service** → connect this repo.
2. Runtime **Node**, Build Command: `bash render-build.sh`, Start Command: `node server/index.js`  
   (or just use the included `render.yaml` as a Blueprint).
3. Add Environment Variables:

| Key | Value |
|---|---|
| `ROBOFLOW_API_KEY` | your Roboflow key |
| `OPENAI_API_KEY` | your OpenAI key |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET` | from Firebase console → Project settings → *Your apps* → **Web app** config |

4. In Firebase console → Authentication → Settings → **Authorized domains** → add your `*.onrender.com` domain.

The first build installs Flutter and takes several minutes.

## Run locally

```bash
flutter pub get
flutter build web --release   # add the --dart-define=FIREBASE_* values
cd server && npm install && ROBOFLOW_API_KEY=... OPENAI_API_KEY=... node index.js
```

## Notes

- On the hosted website, the Raspberry Pi camera option is hidden (a website cannot reach a device on your local network). It stays available in mobile builds.
- Scan history is stored in the browser (Hive / IndexedDB) per device.
- For mobile builds pass `--dart-define=API_BASE_URL=https://<your-service>.onrender.com`.
