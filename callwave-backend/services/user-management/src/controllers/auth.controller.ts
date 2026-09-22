import { Request, Response, NextFunction } from 'express';
import { pool } from '@callwave/database';
import { hashPassword, verifyPassword } from '../utils/password.js';
import { generateAccessToken, generateRefreshToken } from '../utils/jwt.js';
import { formatMatricule } from '../utils/matricule.js';

export async function register(req: Request, res: Response, next: NextFunction) {
  try {
    const { username, password, firstName, lastName } = req.body;
    const matricule = formatMatricule(req.body.matricule);
    // Build display name from first + last name; fall back to username
    const displayName = [firstName, lastName].filter(Boolean).join(' ').trim() || username;

    // Check if user exists
    const userExists = await pool.query(
      'SELECT id FROM users WHERE username = $1 OR matricule = $2',
      [username, matricule]
    );

    if (userExists.rowCount && userExists.rowCount > 0) {
      return res.status(409).json({ error: 'Username or Matricule already in use' });
    }

    const hashedPassword = await hashPassword(password);

    // Use a transaction for creating user + profile + settings
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const userRes = await client.query(
        `INSERT INTO users (username, matricule, password_hash)
         VALUES ($1, $2, $3) RETURNING id`,
        [username, matricule, hashedPassword]
      );
      const userId = userRes.rows[0].id;

      // Default profile — store name from registration
      await client.query(
        `INSERT INTO user_profiles (user_id, display_name, first_name, last_name)
         VALUES ($1, $2, $3, $4)`,
        [userId, displayName, firstName ?? null, lastName ?? null]
      );

      // Default settings
      await client.query(
        `INSERT INTO user_settings (user_id) VALUES ($1)`,
        [userId]
      );

      // Default presence
      await client.query(
        `INSERT INTO user_presences (user_id, current_status) VALUES ($1, 'OFFLINE')`,
        [userId]
      );

      await client.query('COMMIT');

      res.status(201).json({ message: 'User registered successfully', userId });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
}

export async function login(req: Request, res: Response, next: NextFunction) {
  try {
    const matricule = formatMatricule(req.body.matricule);
    const { password, clientInfo } = req.body;
    const ipAddress = req.ip || req.socket.remoteAddress;

    const userRes = await pool.query(
      'SELECT id, password_hash, status FROM users WHERE matricule = $1',
      [matricule]
    );

    if (userRes.rowCount === 0) {
      return res.status(404).json({ error: 'Account does not exist' });
    }

    const user = userRes.rows[0];

    if (user.status !== 'ACTIVE') {
      return res.status(403).json({ error: `Account is ${user.status}` });
    }

    const isMatch = await verifyPassword(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ error: 'Wrong password' });
    }

    const accessToken = generateAccessToken({ userId: user.id });
    const refreshToken = generateRefreshToken();

    // Store session
    // Refresh tokens in DB should ideally be hashed, but for simplicity here we store it
    const refreshExpire = new Date();
    refreshExpire.setDate(refreshExpire.getDate() + 7); // 7 days

    const sessionRes = await pool.query(
      `INSERT INTO user_sessions (user_id, refresh_token_hash, client_info, ip_address, expires_at)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [user.id, refreshToken, clientInfo || 'Unknown Client', ipAddress, refreshExpire]
    );

    // Update last login
    await pool.query(
      'UPDATE users SET last_login_at = CURRENT_TIMESTAMP, last_ip_address = $1 WHERE id = $2',
      [ipAddress, user.id]
    );

    // Fetch user profile to return with the token
    const profileRes = await pool.query(
      `SELECT u.matricule, u.username, p.display_name, p.first_name, p.last_name,
              p.department, p.ministry, p.division, p.position_title, p.office_location
       FROM users u
       LEFT JOIN user_profiles p ON p.user_id = u.id
       WHERE u.id = $1`,
      [user.id]
    );

    const profile = profileRes.rows[0] ?? {};

    res.json({
      accessToken,
      refreshToken,
      sessionId: sessionRes.rows[0].id,
      user: {
        id: user.id,
        matricule: profile.matricule,
        username: profile.username,
        display_name: profile.display_name ?? profile.username,
        first_name: profile.first_name ?? '',
        last_name: profile.last_name ?? '',
        department: profile.department ?? '',
        ministry: profile.ministry ?? '',
        division: profile.division ?? '',
        position_title: profile.position_title ?? '',
        office_location: profile.office_location ?? '',
      },
    });
  } catch (error) {
    next(error);
  }
}

export async function refreshToken(req: Request, res: Response, next: NextFunction) {
  try {
    const { refreshToken } = req.body;

    const sessionRes = await pool.query(
      'SELECT id, user_id, is_revoked, expires_at FROM user_sessions WHERE refresh_token_hash = $1',
      [refreshToken]
    );

    if (sessionRes.rowCount === 0) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    const session = sessionRes.rows[0];

    if (session.is_revoked || new Date() > new Date(session.expires_at)) {
      return res.status(401).json({ error: 'Refresh token expired or revoked' });
    }

    const newAccessToken = generateAccessToken({ userId: session.user_id });
    
    // Update last activity
    await pool.query(
      'UPDATE user_sessions SET last_activity_at = CURRENT_TIMESTAMP WHERE id = $1',
      [session.id]
    );

    res.json({ accessToken: newAccessToken });
  } catch (error) {
    next(error);
  }
}

export async function logout(req: Request, res: Response, next: NextFunction) {
  try {
    const { sessionId } = req.body;
    const userId = req.user?.userId;

    if (!sessionId) {
      return res.status(400).json({ error: 'sessionId is required' });
    }

    const updateRes = await pool.query(
      'UPDATE user_sessions SET is_revoked = TRUE WHERE id = $1 AND user_id = $2 RETURNING id',
      [sessionId, userId]
    );

    if (updateRes.rowCount === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }

    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    next(error);
  }
}
