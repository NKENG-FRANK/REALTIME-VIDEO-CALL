import assert from 'node:assert/strict';
import { createHmac, randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';

const secret = process.env.JWT_SECRET;
assert.ok(secret, 'JWT_SECRET is required');
const endpoint = process.env.SIGNALING_URL ?? 'ws://127.0.0.1:3002/socket.io/?EIO=4&transport=websocket';

function tokenFor(userId) {
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const payload = `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode({ userId })}`;
  return `${payload}.${createHmac('sha256', secret).update(payload).digest('base64url')}`;
}

async function connect(userId) {
  const socket = new WebSocket(endpoint);
  const events = [];
  const acknowledgements = new Map();
  let nextId = 0;
  let connected;
  let failed;
  const ready = new Promise((resolve, reject) => { connected = resolve; failed = reject; });
  const timeout = setTimeout(() => failed(new Error('Socket connection timed out')), 10000);
  socket.addEventListener('error', () => failed(new Error('Socket connection failed')));
  socket.addEventListener('message', ({ data }) => {
    if (data.startsWith('0')) socket.send(`40${JSON.stringify({ token: tokenFor(userId) })}`);
    else if (data === '2') socket.send('3');
    else if (data.startsWith('40')) connected();
    else if (data.startsWith('44')) failed(new Error('Socket authentication failed'));
    else if (data.startsWith('42')) events.push(JSON.parse(data.slice(2)));
    else if (data.startsWith('43')) {
      const match = /^43(\d+)(\[.*\])$/.exec(data);
      if (match) {
        acknowledgements.get(Number(match[1]))?.(JSON.parse(match[2])[0]);
        acknowledgements.delete(Number(match[1]));
      }
    }
  });
  try {
    await ready;
  } finally {
    clearTimeout(timeout);
  }
  return {
    events,
    emit(event, data) { socket.send(`42${JSON.stringify([event, data])}`); },
    async request(event, data) {
      const id = nextId++;
      let timer;
      try {
        return await new Promise((resolve, reject) => {
          timer = setTimeout(() => reject(new Error(`${event} acknowledgement timed out`)), 10000);
          acknowledgements.set(id, resolve);
          socket.send(`42${id}${JSON.stringify([event, data])}`);
        });
      } finally {
        clearTimeout(timer);
        acknowledgements.delete(id);
      }
    },
    close() { socket.close(); },
  };
}

const roomId = randomUUID();
const firstId = randomUUID();
const secondId = randomUUID();
const outsiderId = randomUUID();
const sockets = [];
try {
  const first = await connect(firstId); sockets.push(first);
  const second = await connect(secondId); sockets.push(second);
  const outsider = await connect(outsiderId); sockets.push(outsider);
  const otherSocket = await connect(firstId); sockets.push(otherSocket);
  for (let attempt = 0; attempt < 5; attempt++) {
    const concurrentRoom = randomUUID();
    const joined = await Promise.all([
      first.request('room:join', { roomId: concurrentRoom, callType: 'DIRECT_VIDEO' }),
      second.request('room:join', { roomId: concurrentRoom, callType: 'DIRECT_VIDEO' }),
    ]);
    assert.ok(joined.every((result) => result.status === 'ok'));
    const members = await first.request('room:participants', { roomId: concurrentRoom });
    assert.equal(members.data.length, 2, 'simultaneous joins share one room');
    first.emit('room:leave', { roomId: concurrentRoom });
    second.emit('room:leave', { roomId: concurrentRoom });
  }
  assert.equal((await first.request('room:join', { roomId, callType: 'DIRECT_VIDEO' })).status, 'ok');
  await delay(250);
  const invite = { roomId, calleeUserId: secondId, callType: 'DIRECT_VIDEO', callerName: 'Test', callerMatricule: '' };
  outsider.emit('call:invite', invite);
  await delay(250);
  assert.equal(second.events.filter(([name]) => name === 'call:incoming').length, 0);
  otherSocket.emit('call:invite', invite);
  await delay(250);
  assert.equal(second.events.filter(([name]) => name === 'call:incoming').length, 1);
  outsider.emit('call:decline', { roomId, callerUserId: firstId });
  second.emit('call:decline', { roomId, callerUserId: outsiderId });
  await delay(250);
  assert.equal(first.events.filter(([name]) => name === 'call:declined').length, 0);
  second.emit('call:decline', { roomId });
  await delay(250);
  assert.equal(first.events.filter(([name]) => name === 'call:declined').length, 1);
  second.emit('call:decline', { roomId, callerUserId: firstId });
  await delay(250);
  assert.equal(first.events.filter(([name]) => name === 'call:declined').length, 1);
  otherSocket.emit('call:invite', invite);
  await delay(250);
  assert.equal(second.events.filter(([name]) => name === 'call:incoming').length, 2);
  assert.equal((await second.request('room:join', { roomId, callType: 'DIRECT_VIDEO' })).status, 'ok');
  second.emit('call:decline', { roomId });
  await delay(250);
  assert.equal(first.events.filter(([name]) => name === 'call:declined').length, 1, 'accepted invitation cannot be declined');
  for (const event of [
    'room:participants', 'transport:create', 'transport:connect', 'producer:create',
    'producer:pause', 'producer:resume', 'consumer:create', 'consumer:pause', 'consumer:resume',
  ]) {
    const result = await otherSocket.request(event, { roomId, direction: 'send' });
    assert.equal(result.status, 'error', `${event} rejects a different socket for the same user`);
    assert.equal(result.message, 'Room access denied');
    assert.equal((await otherSocket.request(event, null)).status, 'error', `${event} rejects a missing payload`);
  }
  assert.equal((await first.request('room:participants', { roomId })).status, 'ok');

  const reusedRoom = randomUUID();
  assert.equal((await first.request('room:join', { roomId: reusedRoom, callType: 'DIRECT_VIDEO' })).status, 'ok');
  otherSocket.emit('call:invite', { ...invite, roomId: reusedRoom, calleeUserId: outsiderId });
  await delay(250);
  assert.equal(outsider.events.filter(([name]) => name === 'call:incoming').length, 1);
  first.emit('room:leave', { roomId: reusedRoom });
  await delay(250);
  assert.equal((await first.request('room:join', { roomId: reusedRoom, callType: 'DIRECT_VIDEO' })).status, 'ok');
  outsider.emit('call:decline', { roomId: reusedRoom });
  await delay(250);
  assert.equal(first.events.filter(([name]) => name === 'call:declined').length, 1, 'old invitation cannot affect a recreated room');
  first.emit('room:leave', { roomId: reusedRoom });

  for (const event of ['webrtc:offer', 'webrtc:answer', 'webrtc:candidate', 'webrtc:request_keyframe']) {
    const before = second.events.filter(([name]) => name === event).length;
    first.emit(event, { roomId, to: secondId, sdp: 'test', candidate: 'test' });
    outsider.emit(event, { roomId, to: secondId, sdp: 'unauthorized', candidate: 'unauthorized' });
    otherSocket.emit(event, { roomId, to: secondId, sdp: 'unauthorized', candidate: 'unauthorized' });
    first.emit(event, { roomId, to: outsiderId, sdp: 'unauthorized', candidate: 'unauthorized' });
    await delay(250);
    const received = second.events.filter(([name]) => name === event).slice(before);
    assert.equal(received.length, 1, `${event}: exactly one authorized delivery`);
    assert.equal(received[0][1].senderUserId, firstId);
    assert.equal(outsider.events.filter(([name]) => name === event).length, 0, `${event}: outsider received no events`);
  }

  first.emit('webrtc:offer', { roomId, sdp: 'broadcast' });
  await delay(250);
  assert.equal(second.events.filter(([name, data]) => name === 'webrtc:offer' && data.sdp === 'broadcast').length, 1);
  assert.equal(outsider.events.filter(([name]) => name === 'webrtc:offer').length, 0);
  const replacement = await connect(firstId); sockets.push(replacement);
  assert.equal((await replacement.request('room:join', { roomId, callType: 'DIRECT_VIDEO' })).status, 'ok');
  second.emit('webrtc:offer', { roomId, sdp: 'after-reconnect' });
  await delay(250);
  assert.equal(first.events.filter(([name, data]) => name === 'webrtc:offer' && data.sdp === 'after-reconnect').length, 0);
  assert.equal(replacement.events.filter(([name, data]) => name === 'webrtc:offer' && data.sdp === 'after-reconnect').length, 1);
  first.emit('room:leave', { roomId });
  await delay(250);
  replacement.emit('webrtc:offer', { roomId, to: secondId, sdp: 'still-connected' });
  await delay(250);
  assert.equal(second.events.filter(([name, data]) => name === 'webrtc:offer' && data.sdp === 'still-connected').length, 1);
  second.close();
  await delay(250);
  assert.equal(replacement.events.filter(([name, data]) => name === 'room:participant_left' && data.userId === secondId).length, 1);
  replacement.emit('room:leave', { roomId });
  await delay(250);
  console.log('Signaling smoke test passed');
} finally {
  for (const socket of sockets) socket.close();
}