import assert from 'node:assert/strict';
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { createServer } from 'node:http';

const require = createRequire('/app/package.json');
const express = require('express');
const jwt = require('jsonwebtoken');
const { default: router } = await import('/app/services/video-calls/dist/routes/video.routes.js');
const app = express();
app.use('/api/v1/video', router);
const server = createServer(app);
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const baseUrl = `http://127.0.0.1:${server.address().port}/api/v1/video/turn-credentials`;
const userId = randomUUID();
const token = jwt.sign({ userId }, process.env.JWT_SECRET);
const request = (authorization) => fetch(baseUrl, { headers: authorization ? { authorization } : {} });
try {
  assert.equal((await request()).status, 401);
  assert.equal((await request('Bearer invalid')).status, 401);
  delete process.env.TURN_SHARED_SECRET;
  process.env.TURN_URLS = 'turn:example.test:3478?transport=udp,turn:example.test:3478?transport=tcp';
  assert.equal((await request(`Bearer ${token}`)).status, 503);
  process.env.TURN_SHARED_SECRET = randomBytes(32).toString('hex');
  const response = await request(`Bearer ${token}`);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const data = await response.json();
  assert.equal(data.urls.length, 2);
  assert.equal(data.username, `${data.expiresAt}:${userId}`);
  assert.ok(data.expiresAt >= Math.floor(Date.now() / 1000) + 3590);
  assert.ok(data.expiresAt <= Math.floor(Date.now() / 1000) + 3600);
  assert.equal(data.credential, createHmac('sha1', process.env.TURN_SHARED_SECRET).update(data.username).digest('base64'));
  process.env.TURN_URLS = 'http://example.test/';
  assert.equal((await request(`Bearer ${token}`)).status, 503);
  console.log('TURN credential endpoint smoke test passed');
} finally {
  await new Promise((resolve) => server.close(resolve));
}