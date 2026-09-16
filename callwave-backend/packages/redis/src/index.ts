import { Redis } from 'ioredis';
import { config } from '@callwave/config';

export const redis = new Redis(config.redis.url, { lazyConnect: true });

export async function connectRedis(): Promise<void> {
  if (redis.status === 'wait') await redis.connect();
}

export async function checkRedis(): Promise<boolean> {
  return (await redis.ping()) === 'PONG';
}

export async function closeRedis(): Promise<void> {
  if (redis.status !== 'end') await redis.quit();
}
