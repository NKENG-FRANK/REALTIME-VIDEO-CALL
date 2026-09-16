export interface UserIdentity {
  id: string;
  email: string;
  displayName: string;
}

export interface CallSession {
  id: string;
  callerId: string;
  calleeId: string;
  kind: 'audio' | 'video';
  status: 'ringing' | 'active' | 'ended';
}

export interface ServiceHealth {
  service: string;
  status: 'ok' | 'degraded';
  timestamp: string;
}

export interface EventEnvelope<TPayload> {
  event: string;
  occurredAt: string;
  payload: TPayload;
}

export class AppError extends Error {
  constructor(
    message: string,
    public readonly statusCode = 500,
    public readonly code = 'INTERNAL_ERROR',
  ) {
    super(message);
    this.name = 'AppError';
  }
}
