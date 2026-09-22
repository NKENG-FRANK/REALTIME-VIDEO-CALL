import jwt from 'jsonwebtoken';
import { config } from '@callwave/config';
import { Socket } from 'socket.io';

type ExtendedError = Error & { data?: any };

export interface JwtPayload {
  userId: string;
}

export function socketAuthMiddleware(socket: Socket, next: (err?: ExtendedError) => void) {
  const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.split(' ')[1];

  if (!token) {
    return next(new Error('Unauthorized: No token provided'));
  }

  const secret = (config.app as any).jwtSecret || 'dev-secret-key-change-in-prod';
  
  try {
    const payload = jwt.verify(token, secret) as JwtPayload;
    // Attach the user ID to the socket
    socket.data.userId = payload.userId;
    next();
  } catch (error) {
    next(new Error('Unauthorized: Invalid token'));
  }
}
