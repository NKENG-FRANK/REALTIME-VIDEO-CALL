import express from 'express';
import cors from 'cors';
import { createServer } from 'node:http';
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';
import { config } from '@callwave/config';
import { socketAuthMiddleware } from './middlewares/auth.js';
import { registerCallHandlers } from './sockets/callHandler.js';
import { initRabbitMQ } from './utils/rabbitmq.js';
import statusRoutes from './routes/status.routes.js';

const service = 'audio-calls';
const port = config.app.port + 1;

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/v1/audio', statusRoutes);

app.get('/health', (req, res) => {
  res.status(200).json({ service, status: 'ok', timestamp: new Date().toISOString() });
});

const httpServer = createServer(app);

// Setup Socket.io
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Setup Redis Adapter for horizontal scaling
const pubClient = new Redis(config.redis.url, { lazyConnect: true });
const subClient = pubClient.duplicate();

Promise.all([pubClient.connect(), subClient.connect()]).then(() => {
  io.adapter(createAdapter(pubClient, subClient));
  console.log('Redis adapter connected');
});

// Init RabbitMQ
initRabbitMQ();

// Apply auth middleware
io.use(socketAuthMiddleware);

// Handle connections
io.on('connection', (socket) => {
  console.log(`Socket connected: ${socket.id}, User: ${socket.data.userId}`);
  
  // Register all events
  registerCallHandlers(io, socket);
});

httpServer.listen(port, config.app.host, () => {
  console.log(`${service} listening on ${config.app.host}:${port}`);
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
