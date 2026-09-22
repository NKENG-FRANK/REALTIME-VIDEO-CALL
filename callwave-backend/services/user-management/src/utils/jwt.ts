import jwt from 'jsonwebtoken';
import { config } from '@callwave/config';
import crypto from 'crypto';

// The user ID payload
export interface JwtPayload {
  userId: string;
}

export function generateAccessToken(payload: JwtPayload): string {
  // Access token valid for 15 minutes by default
  const secret = (config.app as any).jwtSecret || 'dev-secret-key-change-in-prod';
  return jwt.sign(payload, secret, { expiresIn: '15m' });
}

export function generateRefreshToken(): string {
  // Generate a random string to use as a refresh token
  return crypto.randomBytes(40).toString('hex');
}

export function verifyAccessToken(token: string): JwtPayload {
  const secret = (config.app as any).jwtSecret || 'dev-secret-key-change-in-prod';
  return jwt.verify(token, secret) as JwtPayload;
}
