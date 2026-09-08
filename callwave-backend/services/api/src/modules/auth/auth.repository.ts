import { pool } from "../../config/database.js";
import type { RegisterInput } from "./auth.types.js";

export async function findUserByEmail(email: string) {
  const result = await pool.query(
    `
      SELECT
        id,
        email,
        password_hash,
        first_name,
        last_name,
        avatar_url,
        is_active,
        is_verified
      FROM users
      WHERE email = $1
      LIMIT 1
    `,
    [email]
  );

  return result.rows[0] ?? null;
}

export async function findUserById(id: string) {
  const result = await pool.query(
    `
      SELECT
        id,
        email,
        first_name,
        last_name,
        avatar_url,
        is_active,
        is_verified
      FROM users
      WHERE id = $1
      LIMIT 1
    `,
    [id]
  );

  return result.rows[0] ?? null;
}

export async function createUser(
  input: RegisterInput,
  passwordHash: string
) {
  const result = await pool.query(
    `
      INSERT INTO users (
        email,
        password_hash,
        first_name,
        last_name
      )
      VALUES ($1, $2, $3, $4)
      RETURNING
        id,
        email,
        first_name,
        last_name,
        avatar_url,
        is_active,
        is_verified,
        created_at
    `,
    [
      input.email,
      passwordHash,
      input.firstName,
      input.lastName,
    ]
  );

  return result.rows[0];
}