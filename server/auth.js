// Simple email + password auth (Postgres + JWT) for Fabric-AI
import { Router } from "express";
import pg from "pg";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import crypto from "node:crypto";
import rateLimit from "express-rate-limit";

const DATABASE_URL = process.env.DATABASE_URL || "";
const JWT_SECRET =
  process.env.JWT_SECRET ||
  (DATABASE_URL ? crypto.createHash("sha256").update("fabric-ai:" + DATABASE_URL).digest("hex") : "");

export const authEnabled = Boolean(DATABASE_URL && JWT_SECRET);

const isLocal = /localhost|127\.0\.0\.1|\/tmp/.test(DATABASE_URL);
const pool = authEnabled
  ? new pg.Pool({
      connectionString: DATABASE_URL,
      ssl: isLocal ? false : { rejectUnauthorized: false },
      max: 5,
    })
  : null;

export async function initAuthDb() {
  if (!pool) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS fabric_users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`);
}

const sign = (u) => jwt.sign({ id: u.id, email: u.email }, JWT_SECRET, { expiresIn: "30d" });
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function requireAuth(req, res, next) {
  if (!authEnabled) return res.status(500).json({ error: "Auth is not configured (DATABASE_URL missing)." });
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: "Please log in again." });
  }
}

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 40,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many attempts, try again later." },
});

export const authRouter = Router();
authRouter.use(limiter);

authRouter.post("/signup", async (req, res) => {
  try {
    if (!authEnabled) return res.status(500).json({ error: "Auth is not configured (DATABASE_URL missing)." });
    const email = String(req.body?.email || "").trim().toLowerCase();
    const password = String(req.body?.password || "");
    if (!EMAIL_RE.test(email)) return res.status(400).json({ error: "The email address is invalid." });
    if (password.length < 6) return res.status(400).json({ error: "Password must be at least 6 characters." });
    const hash = await bcrypt.hash(password, 10);
    try {
      const r = await pool.query(
        "INSERT INTO fabric_users (email, password_hash) VALUES ($1, $2) RETURNING id, email",
        [email, hash],
      );
      res.status(201).json({ token: sign(r.rows[0]), email });
    } catch (e) {
      if (e.code === "23505") return res.status(409).json({ error: "An account already exists for that email." });
      throw e;
    }
  } catch (e) {
    console.error("signup:", e.message);
    res.status(500).json({ error: "Could not create the account." });
  }
});

authRouter.post("/login", async (req, res) => {
  try {
    if (!authEnabled) return res.status(500).json({ error: "Auth is not configured (DATABASE_URL missing)." });
    const email = String(req.body?.email || "").trim().toLowerCase();
    const password = String(req.body?.password || "");
    const r = await pool.query("SELECT id, email, password_hash FROM fabric_users WHERE email = $1", [email]);
    const u = r.rows[0];
    if (!u || !(await bcrypt.compare(password, u.password_hash)))
      return res.status(401).json({ error: "Invalid email or password." });
    res.json({ token: sign(u), email: u.email });
  } catch (e) {
    console.error("login:", e.message);
    res.status(500).json({ error: "Could not log in." });
  }
});

authRouter.get("/me", requireAuth, (req, res) => res.json({ email: req.user.email }));

authRouter.delete("/me", requireAuth, async (req, res) => {
  try {
    await pool.query("DELETE FROM fabric_users WHERE id = $1", [req.user.id]);
    res.json({ ok: true });
  } catch (e) {
    console.error("delete:", e.message);
    res.status(500).json({ error: "Could not delete the account." });
  }
});
