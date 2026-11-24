import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';

import { config } from '@callwave/config';

declare global {
  namespace Express {
    interface Request {
      authUserId?: string;
    }
  }
}

export function requireHttpAuth(req: Request, res: Response, next: NextFunction) {
  const authorization = req.header('authorization');
  const match = authorization?.match(/^Bearer\s+(.+)$/i);

  if (!match) {
    return res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
  }

  try {
    const payload = jwt.verify(match[1], config.app.jwtSecret) as { userId?: unknown };
    if (typeof payload.userId !== 'string' || payload.userId.length === 0) {
      return res.status(401).json({ error: 'Unauthorized: Invalid token' });
    }

    req.authUserId = payload.userId;
    next();
  } catch {
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
}