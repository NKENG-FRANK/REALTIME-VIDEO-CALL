import pg from 'pg';
import { config } from '@callwave/config';

const { Pool } = pg;

export const pool = new Pool(
  config.database.url
    ? { connectionString: config.database.url }
    : {
        host: config.database.host,
        port: config.database.port,
        database: config.database.name,
        user: config.database.user,
        password: config.database.password,
      },
);

export async function checkDatabase(): Promise<boolean> {
  const result = await pool.query('SELECT 1 AS connected');
  return result.rows[0]?.connected === 1;
}

export async function closeDatabase(): Promise<void> {
  await pool.end();
}
