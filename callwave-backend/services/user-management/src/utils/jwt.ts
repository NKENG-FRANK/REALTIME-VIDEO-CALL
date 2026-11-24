import jwt from 'jsonwebtoken';
import { config } from '@callwave/config';
import crypto from 'crypto';

// The user ID payload
export interface JwtPayload {
  userId: string;
}

export function generateAccessToken(payload: JwtPayload): string {
  // Access token valid for 7 days in development
  return jwt.sign(payload, config.app.jwtSecret, { expiresIn: '7d' });
}

export function generateRefreshToken(): string {
  // Generate a random string to use as a refresh token
  return crypto.randomBytes(40).toString('hex');
}

export function hashRefreshToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function verifyAccessToken(token: string): JwtPayload {
  return jwt.verify(token, config.app.jwtSecret) as JwtPayload;
}
