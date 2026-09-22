import express from 'express';
import cors from 'cors';
import { createServer } from 'node:http';
import { config } from '@callwave/config';
import { errorHandler } from './middlewares/error.js';
import authRoutes from './routes/auth.routes.js';
import usersRoutes from './routes/users.routes.js';
import contactsRoutes from './routes/contacts.routes.js';
import settingsRoutes from './routes/settings.routes.js';
import presenceRoutes from './routes/presence.routes.js';
import callsRoutes from './routes/calls.routes.js';

const service = 'user-management';
const port = config.app.port;

const app = express();

app.use(cors());
app.use(express.json());

// Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', usersRoutes);
app.use('/api/v1/contacts', contactsRoutes);
app.use('/api/v1/settings', settingsRoutes);
app.use('/api/v1/presence', presenceRoutes);
app.use('/api/v1/calls', callsRoutes);

app.get('/health', (req, res) => {
  res.status(200).json({ service, status: 'ok', timestamp: new Date().toISOString() });
});

// Error handling middleware
app.use(errorHandler);

const server = createServer(app);

server.listen(port, config.app.host, () => {
  console.log(`${service} listening on ${config.app.host}:${port}`);
});

process.on('SIGTERM', () => server.close());
process.on('SIGINT', () => server.close());
