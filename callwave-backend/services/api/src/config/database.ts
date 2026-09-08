import pg from "pg";

const { Pool } = pg;

export const pool = new Pool({
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || "callwave",
  user: process.env.DB_USER || "callwave",
  password: process.env.DB_PASSWORD,

  max: 10,

  idleTimeoutMillis: 30_000,

  connectionTimeoutMillis: 5_000,
});