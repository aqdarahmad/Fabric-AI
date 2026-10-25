// Fabric-AI web server
// 1) serves the compiled Flutter web app (build/web)
// 2) proxies the AI calls so the API keys never reach the browser
import express from "express";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { FABRIC_TYPE_PROMPT, AUTHENTICITY_PROMPT } from "./prompts.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEB_DIR = path.resolve(__dirname, "..", "build", "web");
const PORT = process.env.PORT || 5000;

const ROBOFLOW_API_KEY = process.env.ROBOFLOW_API_KEY || "";
const ROBOFLOW_MODEL = process.env.ROBOFLOW_MODEL || "fabric-defect-detection-lbvbi-1kwag";
const ROBOFLOW_VERSION = process.env.ROBOFLOW_VERSION || "1";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";
const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";

const app = express();
app.set("trust proxy", 1);
// CSP is off because Flutter web loads CanvasKit/fonts from Google CDNs.
app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
app.use(express.json({ limit: "12mb" }));

app.get("/api/health", (_req, res) =>
  res.json({
    ok: true,
    roboflow: Boolean(ROBOFLOW_API_KEY),
    openai: Boolean(OPENAI_API_KEY),
  }),
);

// Limits cost abuse of your paid keys.
const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests, please wait a minute." },
});
app.use("/api/ai", aiLimiter);

function validImage(b64) {
  return typeof b64 === "string" && b64.length > 100 && b64.length < 11_000_000 && /^[A-Za-z0-9+/=\s]+$/.test(b64);
}

async function timedFetch(url, options, ms) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), ms);
  try {
    return await fetch(url, { ...options, signal: ctrl.signal });
  } finally {
    clearTimeout(t);
  }
}

// ---- 1) defect detection (Roboflow)
app.post("/api/ai/defects", async (req, res) => {
  try {
    if (!ROBOFLOW_API_KEY) return res.status(500).json({ error: "ROBOFLOW_API_KEY is not set on the server." });
    const { image, confidence } = req.body || {};
    if (!validImage(image)) return res.status(400).json({ error: "Invalid image." });
    const conf = Math.min(100, Math.max(1, Math.round(Number(confidence) || 35)));
    const url =
      `https://detect.roboflow.com/${ROBOFLOW_MODEL}/${ROBOFLOW_VERSION}` +
      `?api_key=${encodeURIComponent(ROBOFLOW_API_KEY)}&confidence=${conf}`;
    const r = await timedFetch(
      url,
      { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: image },
      25000,
    );
    const text = await r.text();
    res.status(r.status).type("application/json").send(text);
  } catch (e) {
    console.error("defects error:", e.message);
    res.status(502).json({ error: "Defect detection service unavailable." });
  }
});

// ---- 2) / 3) OpenAI vision
async function askOpenAI({ image, prompt, maxTokens, temperature }) {
  const r = await timedFetch(
    "https://api.openai.com/v1/chat/completions",
    {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${OPENAI_API_KEY}` },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "user",
            content: [
              { type: "image_url", image_url: { url: `data:image/jpeg;base64,${image}` } },
              { type: "text", text: prompt },
            ],
          },
        ],
        max_tokens: maxTokens,
        temperature,
      }),
    },
    30000,
  );
  if (!r.ok) throw new Error(`OpenAI ${r.status}`);
  const data = await r.json();
  return JSON.parse(data.choices[0].message.content);
}

function openaiRoute(prompt, maxTokens, temperature) {
  return async (req, res) => {
    try {
      if (!OPENAI_API_KEY) return res.status(500).json({ error: "OPENAI_API_KEY is not set on the server." });
      const { image } = req.body || {};
      if (!validImage(image)) return res.status(400).json({ error: "Invalid image." });
      res.json(await askOpenAI({ image, prompt, maxTokens, temperature }));
    } catch (e) {
      console.error("openai error:", e.message);
      res.status(502).json({ error: "AI analysis service unavailable." });
    }
  };
}
app.post("/api/ai/fabric-type", openaiRoute(FABRIC_TYPE_PROMPT, 300, 0.3));
app.post("/api/ai/authenticity", openaiRoute(AUTHENTICITY_PROMPT, 400, 0.0));

// ---- Flutter web app
if (fs.existsSync(WEB_DIR)) {
  app.use(express.static(WEB_DIR, { maxAge: "1h", index: false }));
  app.get(/^\/(?!api\/).*/, (_req, res) => res.sendFile(path.join(WEB_DIR, "index.html")));
} else {
  app.get("/", (_req, res) =>
    res.status(503).send("Flutter web build not found. Run: flutter build web --release"),
  );
}

app.listen(PORT, () => console.log(`Fabric-AI server on :${PORT} (web build: ${fs.existsSync(WEB_DIR)})`));
