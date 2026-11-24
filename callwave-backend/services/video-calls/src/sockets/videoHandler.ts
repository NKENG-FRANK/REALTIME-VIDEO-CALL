import { Server, Socket } from 'socket.io';
import { redis } from '@callwave/redis';
import { publishCallEvent } from '../utils/rabbitmq.js';
import {
  getOrCreateRoom,
  addParticipant,
  removeParticipant,
  createWebRtcTransport,
  getRoomParticipants,
  getRoom,
} from '../mediasoup/roomManager.js';

const isRoomCapability = (roomId: string): boolean =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(roomId);

const invitationKey = (roomId: string, calleeUserId: string): string =>
  `video:invitation:${roomId}:${calleeUserId}`;

export function registerVideoHandlers(io: Server, socket: Socket) {
  const userId = socket.data.userId;

  // Track which rooms this socket has already left to prevent double-leave
  const leftRooms = new Set<string>();

  function authorizeRoomSocket(roomId: string | undefined, callback?: (res: any) => void): boolean {
    if (roomId && getRoom(roomId)?.participants.get(userId)?.socketId === socket.id) return true;
    if (typeof callback === 'function') callback({ status: 'error', message: 'Room access denied' });
    return false;
  }

  // ─── Call Signaling ─────────────────────────────────────────────────────

  /**
  * The caller must already be a room participant on one of their sockets.
   * The backend looks up the callee's live socket from Redis presence and
   * forwards a `call:incoming` event so their app can show the incoming call UI.
   */
  socket.on(
    'call:invite',
    async (data: {
      calleeUserId: string;
      roomId: string;
      callType: 'DIRECT_VIDEO' | 'DIRECT_AUDIO';
      callerName: string;
      callerMatricule: string;
    }) => {
      try {
        const { calleeUserId, roomId, callType, callerName, callerMatricule } = data;
        const room = getRoom(roomId);
        if (!isRoomCapability(roomId) || !room?.participants.has(userId)) {
          socket.emit('error', { message: 'Call invite is not authorized' });
          return;
        }
        const isOnline = await redis.hexists('video:presence', calleeUserId);

        if (!isOnline) {
          console.log(`[VideoHandler] Callee ${calleeUserId} NOT found in Redis presence (callee offline)`);
          socket.emit('call:callee_offline', { calleeUserId });
          return;
        }

        if (!getRoom(roomId)?.participants.has(userId)) return;
        await redis.set(invitationKey(roomId, calleeUserId), JSON.stringify({ callerUserId: userId, roomInstanceId: room.instanceId }), 'EX', 90);
        if (getRoom(roomId) !== room || !room.participants.has(userId)) return;
        console.log(`[VideoHandler] Forwarding call:incoming to callee user room ${calleeUserId}`);
        io.to(calleeUserId).emit('call:incoming', {
          roomId,
          callType,
          callerUserId: userId,
          callerName,
          callerMatricule,
        });

        // Acknowledge to the caller that the invite was delivered
        socket.emit('call:invite_sent', { calleeUserId, roomId });
      } catch (error: any) {
        console.error(`[VideoHandler] Error handling call:invite:`, error);
        socket.emit('error', { message: error.message });
      }
    }
  );

  /**
   * Callee declines — notify the caller that the call was rejected.
   */
  socket.on('call:decline', async (data: { callerUserId?: string; roomId: string }) => {
    try {
      if (!data || !isRoomCapability(data.roomId)) return;
      const invitation = await redis.eval(
        "local value = redis.call('GET', KEYS[1]); if not value then return nil end; local invite = cjson.decode(value); if ARGV[1] ~= '' and invite.callerUserId ~= ARGV[1] then return nil end; redis.call('DEL', KEYS[1]); return value",
        1,
        invitationKey(data.roomId, userId),
        data.callerUserId || ''
      );
      if (typeof invitation !== 'string') return;
      const { callerUserId, roomInstanceId } = JSON.parse(invitation);
      const room = getRoom(data.roomId);
      if (!room || room.instanceId !== roomInstanceId || !room.participants.has(callerUserId)) return;
      io.to(callerUserId).emit('call:declined', { calleeUserId: userId, roomId: data.roomId });
    } catch (error: any) {
      console.error('[VideoHandler] Error handling call:decline:', error.message);
    }
  });

  // ─── Room Lifecycle ──────────────────────────────────────────────────────

  socket.on('room:join', async (data: { roomId: string; callType: string }, callback?: (res: any) => void) => {
    try {
      const { roomId, callType } = data;
      if (!isRoomCapability(roomId)) {
        throw new Error('Invalid room capability');
      }
      const room = await getOrCreateRoom(roomId);
      const previous = room.participants.get(userId);
      if (previous && previous.socketId !== socket.id) {
        io.sockets.sockets.get(previous.socketId)?.leave(roomId);
      }
      addParticipant(roomId, userId, socket.id);
      redis.del(invitationKey(roomId, userId)).catch((error) => {
        console.error('[VideoHandler] Error clearing invitation:', error.message);
      });

      socket.join(roomId);
      leftRooms.delete(roomId);

      const participants = getRoomParticipants(roomId)
        .filter((p) => p.userId !== userId)
        .map((p) => ({
          userId: p.userId,
          producerIds: Array.from(p.producers.keys()),
          producers: Array.from(p.producers.values()).map((prod) => ({
            id: prod.id,
            kind: prod.kind,
          })),
        }));

      const joinPayload = {
        roomId,
        rtpCapabilities: room.router.rtpCapabilities,
        participants,
      };

      if (typeof callback === 'function') {
        callback({ status: 'ok', data: joinPayload });
      }

      // Send router RTP capabilities (codec info) to the client
      socket.emit('room:joined', joinPayload);

      // Notify others in the room
      socket.to(roomId).emit('room:participant_joined', { userId });
    } catch (error: any) {
      if (typeof callback === 'function') {
        callback({ status: 'error', message: error.message });
      }
      socket.emit('error', { message: error.message });
    }
  });

  socket.on('room:leave', async (data: { roomId: string; durationSeconds?: number }) => {
    const { roomId, durationSeconds } = data;
    if (!leftRooms.has(roomId)) {
      leftRooms.add(roomId);
      await leaveRoom(socket, io, userId, roomId, durationSeconds);
    }
  });

  socket.on('disconnecting', async () => {
    // Clean up only call rooms (not the userId presence room or socket.id room).
    // Use a snapshot of rooms because socket.rooms will mutate during iteration.
    const roomsSnapshot = Array.from(socket.rooms);
    for (const roomId of roomsSnapshot) {
      if (roomId !== socket.id && roomId !== userId && !leftRooms.has(roomId)) {
        leftRooms.add(roomId);
        await leaveRoom(socket, io, userId, roomId);
      }
    }
  });

  // ─── WebRTC Transport ────────────────────────────────────────────────────

  socket.on('transport:create', async (data: { roomId: string; direction: 'send' | 'recv' }, callback?: (res: any) => void) => {
    if (!authorizeRoomSocket(data?.roomId, callback)) return;
    try {
      const { roomId, direction } = data;
      const transport = await createWebRtcTransport(roomId, userId, direction);

      const payload = {
        direction,
        transportId: transport.id,
        id: transport.id,
        iceParameters: transport.iceParameters,
        iceCandidates: transport.iceCandidates,
        dtlsParameters: transport.dtlsParameters,
        sctpParameters: transport.sctpParameters,
      };

      if (typeof callback === 'function') {
        callback({ status: 'ok', data: payload });
      }

      socket.emit('transport:created', payload);
    } catch (error: any) {
      if (typeof callback === 'function') {
        callback({ status: 'error', message: error.message });
      }
      socket.emit('error', { message: error.message });
    }
  });

  socket.on(
    'transport:connect',
    async (
      data: { roomId: string; transportId: string; dtlsParameters: any; direction: 'send' | 'recv' },
      callback?: (res: any) => void
    ) => {
      if (!authorizeRoomSocket(data?.roomId, callback)) return;
      try {
        const { roomId, dtlsParameters, direction } = data;
        const room = getRoom(roomId);
        if (!room) {
          const err = 'Room not found';
          if (typeof callback === 'function') callback({ status: 'error', message: err });
          return socket.emit('error', { message: err });
        }

        const participant = room.participants.get(userId);
        if (!participant) {
          const err = 'Not in room';
          if (typeof callback === 'function') callback({ status: 'error', message: err });
          return socket.emit('error', { message: err });
        }

        const transport = direction === 'send' ? participant.sendTransport : participant.recvTransport;
        if (!transport) {
          const err = 'Transport not found';
          if (typeof callback === 'function') callback({ status: 'error', message: err });
          return socket.emit('error', { message: err });
        }

        await transport.connect({ dtlsParameters });

        if (typeof callback === 'function') {
          callback({ status: 'ok', data: { direction } });
        }
        socket.emit('transport:connected', { direction });
      } catch (error: any) {
        if (typeof callback === 'function') {
          callback({ status: 'error', message: error.message });
        }
        socket.emit('error', { message: error.message });
      }
    }
  );

  // ─── Producers (Publishing Media) ────────────────────────────────────────

  socket.on(
    'producer:create',
    async (
      data: { roomId: string; kind: 'audio' | 'video'; rtpParameters: any; appData?: any },
      callback?: (res: any) => void
    ) => {
      if (!authorizeRoomSocket(data?.roomId, callback)) return;
      try {
        const { roomId, kind, rtpParameters, appData } = data;
        const room = getRoom(roomId);
        if (!room) {
          const err = 'Room not found';
          if (typeof callback === 'function') callback({ status: 'error', message: err });
          return socket.emit('error', { message: err });
        }

        const participant = room.participants.get(userId);
        if (!participant || !participant.sendTransport) {
          const err = 'Send transport not ready';
          if (typeof callback === 'function') callback({ status: 'error', message: err });
          return socket.emit('error', { message: err });
        }

        const producer = await participant.sendTransport.produce({ kind, rtpParameters, appData });
        participant.producers.set(producer.id, producer);

        producer.on('transportclose', () => {
          producer.close();
          participant.producers.delete(producer.id);
        });

        const payload = { producerId: producer.id, id: producer.id, kind };
        if (typeof callback === 'function') {
          callback({ status: 'ok', data: payload });
        }

        socket.emit('producer:created', payload);

        // Notify other participants about the new producer so they can consume it
        socket.to(roomId).emit('room:new_producer', {
          userId,
          producerId: producer.id,
          kind,
        });
      } catch (error: any) {
        if (typeof callback === 'function') {
          callback({ status: 'error', message: error.message });
        }
        socket.emit('error', { message: error.message });
      }
    }
  );

  socket.on('producer:pause', async (data: { roomId: string; producerId: string }, callback?: (res: any) => void) => {
    if (!authorizeRoomSocket(data?.roomId, callback)) return;
    const { roomId, producerId } = data;
    const room = getRoom(roomId);
    const participant = room?.participants.get(userId);
    const producer = participant?.producers.get(producerId);
    if (producer) {
      await producer.pause();
      if (typeof callback === 'function') callback({ status: 'ok' });
      socket.to(roomId).emit('producer:paused', { userId, producerId });
    } else {
      if (typeof callback === 'function') callback({ status: 'error', message: 'Producer not found' });
    }
  });

  socket.on('producer:resume', async (data: { roomId: string; producerId: string }, callback?: (res: any) => void) => {
    if (!authorizeRoomSocket(data?.roomId, callback)) return;
    const { roomId, producerId } = data;
    const room = getRoom(roomId);
    const participant = room?.participants.get(userId);
    const producer = participant?.producers.get(producerId);
    if (producer) {
      await producer.resume();
      if (typeof callback === 'function') callback({ status: 'ok' });
      socket.to(roomId).emit('producer:resumed', { userId, producerId });
    } else {
      if (typeof callback === 'function') callback({ status: 'error', message: 'Producer not found' });
    }
  });

  // ─── Consumers (Subscribing to Media) ────────────────────────────────────

  socket.on(
    'consumer:create',
    async (
      data: { roomId: string; producerId: string; producerUserId: string; rtpCapabilities: any },
      callback?: (res: any) => void
    ) => {
      if (!authorizeRoomSocket(data?.roomId, callback)) return;
      try {
        const { roomId, producerId, producerUserId, rtpCapabilities } = data;
        const room = getRoom(roomId);
        if (!room) {
          const err = 'Room not found';
          if (typeof callback === 'function') callback({ status: 'error', message: err });
          return socket.emit('error', { message: err });
        }

        // Verify router can route this consumer's capabilities
        if (!room.router.canConsume({ producerId, rtpCapabilities })) {
          const err = 'Cannot consume producer (codec mismatch)';
          if (typeof callback === 'function') callback({ status: 'error', message: err });
          return socket.emit('error', { message: err });
        }

        const participant = room.participants.get(userId);
        if (!participant || !participant.recvTransport) {
          const err = 'Recv transport not ready';
          if (typeof callback === 'function') callback({ status: 'error', message: err });
          return socket.emit('error', { message: err });
        }

        const consumer = await participant.recvTransport.consume({
          producerId,
          rtpCapabilities,
          paused: true, // Start paused, client resumes when ready
        });

        participant.consumers.set(consumer.id, consumer);

        consumer.on('transportclose', () => consumer.close());
        consumer.on('producerclose', () => {
          consumer.close();
          participant.consumers.delete(consumer.id);
          socket.emit('consumer:closed', { consumerId: consumer.id, producerId });
        });

        const payload = {
          consumerId: consumer.id,
          id: consumer.id,
          producerId: consumer.producerId,
          kind: consumer.kind,
          rtpParameters: consumer.rtpParameters,
          producerUserId,
        };

        if (typeof callback === 'function') {
          callback({ status: 'ok', data: payload });
        }

        socket.emit('consumer:created', payload);
      } catch (error: any) {
        if (typeof callback === 'function') {
          callback({ status: 'error', message: error.message });
        }
        socket.emit('error', { message: error.message });
      }
    }
  );

  socket.on('consumer:resume', async (data: { roomId: string; consumerId: string }, callback?: (res: any) => void) => {
    if (!authorizeRoomSocket(data?.roomId, callback)) return;
    const { roomId, consumerId } = data;
    const room = getRoom(roomId);
    const consumer = room?.participants.get(userId)?.consumers.get(consumerId);
    if (consumer) {
      await consumer.resume();
      if (typeof callback === 'function') callback({ status: 'ok' });
    } else {
      if (typeof callback === 'function') callback({ status: 'error', message: 'Consumer not found' });
    }
  });

  socket.on('consumer:pause', async (data: { roomId: string; consumerId: string }, callback?: (res: any) => void) => {
    if (!authorizeRoomSocket(data?.roomId, callback)) return;
    const { roomId, consumerId } = data;
    const room = getRoom(roomId);
    const consumer = room?.participants.get(userId)?.consumers.get(consumerId);
    if (consumer) {
      await consumer.pause();
      if (typeof callback === 'function') callback({ status: 'ok' });
    } else {
      if (typeof callback === 'function') callback({ status: 'error', message: 'Consumer not found' });
    }
  });

  // ─── Room Participants ────────────────────────────────────────────────────

  socket.on('room:participants', (data: { roomId: string }, callback?: (res: any) => void) => {
    if (!authorizeRoomSocket(data?.roomId, callback)) return;
    const participants = getRoomParticipants(data.roomId).map((p) => ({
      userId: p.userId,
      producerIds: Array.from(p.producers.keys()),
      producers: Array.from(p.producers.values()).map((prod) => ({
        id: prod.id,
        kind: prod.kind,
      })),
    }));
    if (typeof callback === 'function') {
      callback({ status: 'ok', data: participants });
    }
    socket.emit('room:participants', participants);
  });

  // ─── Call End ─────────────────────────────────────────────────────────────

  socket.on('call:end', async (data: { roomId: string; durationSeconds: number }) => {
    const { roomId, durationSeconds } = data;
    if (!leftRooms.has(roomId)) {
      leftRooms.add(roomId);
      await leaveRoom(socket, io, userId, roomId, durationSeconds, 'COMPLETED');
    }
  });

  // ─── WebRTC Direct Peer-to-Peer Signaling ───────────────────────────────────

  function relayToRoom(event: string, data: { roomId: string; to?: string }, payload: Record<string, any>) {
    const room = getRoom(data.roomId);
    if (!room || room.participants.get(userId)?.socketId !== socket.id) return;

    if (data.to) {
      const target = room.participants.get(data.to);
      if (!target || target.userId === userId) return;
      io.to(target.socketId).emit(event, payload);
    } else {
      socket.to(data.roomId).emit(event, payload);
    }
  }

  socket.on('webrtc:offer', async (data: { roomId: string; to?: string; sdp: any; isIceRestart?: boolean }) => {
    const payload: Record<string, any> = {
      senderUserId: userId,
      targetUserId: data.to,
      sdp: data.sdp,
    };
    // Forward optional ICE-restart flag so the remote peer can schedule
    // delayed video restoration correctly (Device B asymmetric reconnect path).
    if (data.isIceRestart) payload.isIceRestart = true;
    relayToRoom('webrtc:offer', data, payload);
  });

  socket.on('webrtc:answer', async (data: { roomId: string; to?: string; sdp: any }) => {
    const payload = {
      senderUserId: userId,
      targetUserId: data.to,
      sdp: data.sdp,
    };
    relayToRoom('webrtc:answer', data, payload);
  });

  socket.on('webrtc:candidate', async (data: { roomId: string; to?: string; candidate: any }) => {
    const payload = {
      senderUserId: userId,
      targetUserId: data.to,
      candidate: data.candidate,
    };
    relayToRoom('webrtc:candidate', data, payload);
  });

  socket.on('webrtc:request_keyframe', async (data: { roomId: string; to?: string }) => {
    const payload = {
      senderUserId: userId,
      targetUserId: data.to,
    };
    relayToRoom('webrtc:request_keyframe', data, payload);
  });
}

// ─── Shared Leave Helper ──────────────────────────────────────────────────────

async function leaveRoom(
  socket: Socket,
  io: Server,
  userId: string,
  roomId: string,
  durationSeconds?: number,
  status = 'COMPLETED'
) {
  if (getRoom(roomId)?.participants.get(userId)?.socketId !== socket.id) return;
  removeParticipant(roomId, userId);
  socket.leave(roomId);

  // Notify REMAINING participants only (not the socket that just left).
  // Using socket.to() instead of io.to() excludes the sender's own socket,
  // preventing the leaving socket from receiving its own call:ended and
  // triggering endCall() again on the Flutter side.
  const remainingParticipants = getRoomParticipants(roomId);
  if (remainingParticipants.length > 0) {
    socket.to(roomId).emit('room:participant_left', { userId, roomId });
  }

  // Publish to RabbitMQ asynchronously in background (non-blocking for instant signaling)
  publishCallEvent('call.completed', {
    roomId,
    userId,
    durationSeconds: durationSeconds ?? 0,
    status,
  }).catch((err: any) => console.error('[VideoHandler] Background RabbitMQ event error:', err.message));
}
