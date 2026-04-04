/**
 * Minimal Express app for cc-path harness demonstration.
 * Three routes: health check, list items, create item.
 */

import express, { Request, Response, NextFunction } from "express";
import dotenv from "dotenv";

dotenv.config();

const API_KEY = process.env.API_KEY;
if (!API_KEY) {
  console.error("ERROR: API_KEY is not set. Copy .env.example to .env and fill in values.");
  process.exit(1);
}

const app = express();
app.use(express.json());

// In-memory store — not for production use
interface Item {
  id: number;
  name: string;
  description?: string;
}
const items: Item[] = [];
let nextId = 1;

function requireApiKey(req: Request, res: Response, next: NextFunction): void {
  if (req.headers["x-api-key"] !== API_KEY) {
    res.status(401).json({ error: "Invalid or missing API key" });
    return;
  }
  next();
}

app.get("/health", (_req: Request, res: Response) => {
  res.json({ status: "ok" });
});

app.get("/items", requireApiKey, (_req: Request, res: Response) => {
  res.json(items);
});

app.post("/items", requireApiKey, (req: Request, res: Response) => {
  const { name, description } = req.body as { name?: string; description?: string };
  if (!name) {
    res.status(400).json({ error: "name is required" });
    return;
  }
  const item: Item = { id: nextId++, name, description };
  items.push(item);
  res.status(201).json(item);
});

const PORT = process.env.PORT ?? 3000;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

export default app;
