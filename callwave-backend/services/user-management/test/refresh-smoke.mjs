import assert from 'node:assert/strict';
import { createHash, randomInt, randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';

const require = createRequire('/app/package.json');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});
const baseUrl = process.env.AUTH_URL ?? 'http://127.0.0.1:3000/api/v1/auth';
const hash = (token) => createHash('sha256').update(token).digest('hex');
async function post(path, body, token) {
  const response = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
}

let userId;
let callId;
try {
  let registration;
  for (let attempt = 0; attempt < 5; attempt++) {
    registration = await post('/register', {
      username: `smoke_${randomUUID().replaceAll('-', '')}`,
      matricule: `T${String(randomInt(10000000)).padStart(7, '0')}`,
      password: randomUUID(),
    });
    if (registration.status !== 409) break;
  }
  assert.equal(registration.status, 201);
  const session = registration.body;
  userId = session.user.id;
  const callEndpoint = 'http://127.0.0.1:3000/api/v1/calls/history';
  const callBody = { room_id: randomUUID(), call_type: 'DIRECT_VIDEO', participantIds: [userId] };
  const callRequest = (url, method, body, token) => fetch(url, {
    method,
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
  const invalidCall = await callRequest(callEndpoint, 'POST', { ...callBody, participantIds: ["' OR 1=1 --"] }, session.accessToken);
  assert.equal(invalidCall.status, 400);
  const createdCall = await callRequest(callEndpoint, 'POST', callBody, session.accessToken);
  assert.equal(createdCall.status, 201);
  callId = (await createdCall.json()).callId;
  const outsiderToken = jwt.sign({ userId: randomUUID() }, process.env.JWT_SECRET);
  assert.equal((await callRequest(`${callEndpoint}/${callId}`, 'PATCH', { durationSeconds: 10 }, outsiderToken)).status, 404);
  assert.equal((await callRequest(`${callEndpoint}/${callId}`, 'PATCH', { durationSeconds: 10 }, session.accessToken)).status, 200);
  const stored = await pool.query('SELECT refresh_token_hash FROM user_sessions WHERE id = $1', [session.sessionId]);
  assert.equal(stored.rows[0].refresh_token_hash, hash(session.refreshToken));

  const responses = await Promise.all([
    post('/refresh', { refreshToken: session.refreshToken }),
    post('/refresh', { refreshToken: session.refreshToken }),
  ]);
  assert.deepEqual(responses.map((response) => response.status).sort(), [200, 401]);
  const rotated = responses.find((response) => response.status === 200).body;
  assert.notEqual(rotated.refreshToken, session.refreshToken);
  assert.equal((await post('/refresh', { refreshToken: session.refreshToken })).status, 401);
  assert.equal((await pool.query('SELECT refresh_token_hash FROM user_sessions WHERE id = $1', [session.sessionId])).rows[0].refresh_token_hash, hash(rotated.refreshToken));

  const again = await post('/refresh', { refreshToken: rotated.refreshToken });
  assert.equal(again.status, 200);
  await pool.query("UPDATE user_sessions SET expires_at = CURRENT_TIMESTAMP - INTERVAL '1 second' WHERE id = $1", [session.sessionId]);
  assert.equal((await post('/refresh', { refreshToken: again.body.refreshToken })).status, 401);
  await pool.query("UPDATE user_sessions SET expires_at = CURRENT_TIMESTAMP + INTERVAL '1 minute' WHERE id = $1", [session.sessionId]);
  assert.equal((await post('/logout', { sessionId: session.sessionId }, again.body.accessToken)).status, 200);
  assert.equal((await post('/refresh', { refreshToken: again.body.refreshToken })).status, 401);
  console.log('Refresh token smoke test passed');
} finally {
  if (callId && userId) await pool.query('DELETE FROM call_logs WHERE id = $1 AND caller_id = $2', [callId, userId]);
  if (userId) await pool.query('DELETE FROM users WHERE id = $1', [userId]);
  await pool.end();
}