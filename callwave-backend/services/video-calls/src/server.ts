import express from 'express';
import cors from 'cors';
import { createServer } from 'node:http';
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';
import { config } from '@callwave/config';
import { socketAuthMiddleware } from './middlewares/auth.js';
import { registerVideoHandlers } from './sockets/videoHandler.js';
import { initWorkerPool } from './mediasoup/workerPool.js';
import { initRabbitMQ } from './utils/rabbitmq.js';
import videoRoutes from './routes/video.routes.js';
import { redis } from '@callwave/redis';

const service = 'video-calls';
const port = config.app.port + 2;

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/v1/video', videoRoutes);

app.get('/health', (_req, res) => {
  res.status(200).json({ service, status: 'ok', timestamp: new Date().toISOString() });
});

const httpServer = createServer(app);

// Socket.io server
const io = new Server(httpServer, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

// Redis Adapter for horizontal scaling
const pubClient = new Redis(config.redis.url, { lazyConnect: true });
const subClient = pubClient.duplicate();

Promise.all([pubClient.connect(), subClient.connect()]).then(() => {
  io.adapter(createAdapter(pubClient, subClient));
  console.log('Redis adapter connected (video-calls)');
});

// JWT auth middleware for Socket.io
io.use(socketAuthMiddleware);

// Handle connections
io.on('connection', async (socket) => {
  const userId = socket.data.userId;
  console.log(`Video socket connected: ${socket.id}, User: ${userId}`);

  // Track presence in Redis
  await redis.hset('video:presence', userId, socket.id);

  socket.on('disconnect', async () => {
    const current = await redis.hget('video:presence', userId);
    if (current === socket.id) {
      await redis.hdel('video:presence', userId);
    }
  });

  registerVideoHandlers(io, socket);
});

// Bootstrap
async function bootstrap() {
  await initWorkerPool();
  await initRabbitMQ();

  httpServer.listen(port, config.app.host, () => {
    console.log(`${service} listening on ${config.app.host}:${port}`);
  });
}

bootstrap().catch((err) => {
  console.error('Failed to start video-calls service:', err);
  process.exit(1);
});

process.on('SIGTERM', () => {
  httpServer.close();
  pubClient.quit();
  subClient.quit();
});
process.on('SIGINT', () => {
  httpServer.close();
  pubClient.quit();
  subClient.quit();
});
