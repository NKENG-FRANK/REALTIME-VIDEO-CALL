import { Server, Socket } from 'socket.io';
import { publishCallEvent } from '../utils/rabbitmq.js';
import {
  getOrCreateRoom,
  addParticipant,
  removeParticipant,
  createWebRtcTransport,
  getRoomParticipants,
  getRoom,
} from '../mediasoup/roomManager.js';

export function registerVideoHandlers(io: Server, socket: Socket) {
  const userId = socket.data.userId;

  // ─── Room Lifecycle ──────────────────────────────────────────────────────

  socket.on('room:join', async (data: { roomId: string; callType: string }) => {
    try {
      const { roomId, callType } = data;
      const room = await getOrCreateRoom(roomId);
      const participant = addParticipant(roomId, userId, socket.id);

      socket.join(roomId);

      // Send router RTP capabilities (codec info) to the client
      socket.emit('room:joined', {
        roomId,
        rtpCapabilities: room.router.rtpCapabilities,
        participants: getRoomParticipants(roomId)
          .filter((p) => p.userId !== userId)
          .map((p) => ({ userId: p.userId, producerIds: Array.from(p.producers.keys()) })),
      });

      // Notify others in the room
      socket.to(roomId).emit('room:participant_joined', { userId });
    } catch (error: any) {
      socket.emit('error', { message: error.message });
    }
  });

  socket.on('room:leave', async (data: { roomId: string; durationSeconds?: number }) => {
    const { roomId, durationSeconds } = data;
    await leaveRoom(socket, io, userId, roomId, durationSeconds);
  });

  socket.on('disconnect', async () => {
    // Find any rooms this user is in and clean up
    socket.rooms.forEach((roomId) => {
      if (roomId !== socket.id) {
        leaveRoom(socket, io, userId, roomId);
      }
    });
  });

  // ─── WebRTC Transport ────────────────────────────────────────────────────

  socket.on('transport:create', async (data: { roomId: string; direction: 'send' | 'recv' }) => {
    try {
      const { roomId, direction } = data;
      const transport = await createWebRtcTransport(roomId, userId, direction);

      socket.emit('transport:created', {
        direction,
        transportId: transport.id,
        iceParameters: transport.iceParameters,
        iceCandidates: transport.iceCandidates,
        dtlsParameters: transport.dtlsParameters,
        sctpParameters: transport.sctpParameters,
      });
    } catch (error: any) {
      socket.emit('error', { message: error.message });
    }
  });

  socket.on(
    'transport:connect',
    async (data: { roomId: string; transportId: string; dtlsParameters: any; direction: 'send' | 'recv' }) => {
      try {
        const { roomId, dtlsParameters, direction } = data;
        const room = getRoom(roomId);
        if (!room) return socket.emit('error', { message: 'Room not found' });

        const participant = room.participants.get(userId);
        if (!participant) return socket.emit('error', { message: 'Not in room' });

        const transport = direction === 'send' ? participant.sendTransport : participant.recvTransport;
        if (!transport) return socket.emit('error', { message: 'Transport not found' });

        await transport.connect({ dtlsParameters });
        socket.emit('transport:connected', { direction });
      } catch (error: any) {
        socket.emit('error', { message: error.message });
      }
    }
  );

  // ─── Producers (Publishing Media) ────────────────────────────────────────

  socket.on('producer:create', async (data: { roomId: string; kind: 'audio' | 'video'; rtpParameters: any; appData?: any }) => {
    try {
      const { roomId, kind, rtpParameters, appData } = data;
      const room = getRoom(roomId);
      if (!room) return socket.emit('error', { message: 'Room not found' });

      const participant = room.participants.get(userId);
      if (!participant || !participant.sendTransport) {
        return socket.emit('error', { message: 'Send transport not ready' });
      }

      const producer = await participant.sendTransport.produce({ kind, rtpParameters, appData });
      participant.producers.set(producer.id, producer);

      producer.on('transportclose', () => {
        producer.close();
        participant.producers.delete(producer.id);
      });

      socket.emit('producer:created', { producerId: producer.id, kind });

      // Notify other participants about the new producer so they can consume it
      socket.to(roomId).emit('room:new_producer', {
        userId,
        producerId: producer.id,
        kind,
      });
    } catch (error: any) {
      socket.emit('error', { message: error.message });
    }
  });

  socket.on('producer:pause', async (data: { roomId: string; producerId: string }) => {
    const { roomId, producerId } = data;
    const room = getRoom(roomId);
    const participant = room?.participants.get(userId);
    const producer = participant?.producers.get(producerId);
    if (producer) {
      await producer.pause();
      socket.to(roomId).emit('producer:paused', { userId, producerId });
    }
  });

  socket.on('producer:resume', async (data: { roomId: string; producerId: string }) => {
    const { roomId, producerId } = data;
    const room = getRoom(roomId);
    const participant = room?.participants.get(userId);
    const producer = participant?.producers.get(producerId);
    if (producer) {
      await producer.resume();
      socket.to(roomId).emit('producer:resumed', { userId, producerId });
    }
  });

  // ─── Consumers (Subscribing to Media) ────────────────────────────────────

  socket.on(
    'consumer:create',
    async (data: { roomId: string; producerId: string; producerUserId: string; rtpCapabilities: any }) => {
      try {
        const { roomId, producerId, producerUserId, rtpCapabilities } = data;
        const room = getRoom(roomId);
        if (!room) return socket.emit('error', { message: 'Room not found' });

        // Verify router can route this consumer's capabilities
        if (!room.router.canConsume({ producerId, rtpCapabilities })) {
          return socket.emit('error', { message: 'Cannot consume producer (codec mismatch)' });
        }

        const consumer = await room.participants.get(userId)?.recvTransport?.consume({
          producerId,
          rtpCapabilities,
          paused: true, // Start paused, client resumes when ready
        });

        if (!consumer) return socket.emit('error', { message: 'Recv transport not ready' });

        room.participants.get(userId)!.consumers.set(consumer.id, consumer);

        consumer.on('transportclose', () => consumer.close());
        consumer.on('producerclose', () => {
          consumer.close();
          room.participants.get(userId)?.consumers.delete(consumer.id);
          socket.emit('consumer:closed', { consumerId: consumer.id });
        });

        socket.emit('consumer:created', {
          consumerId: consumer.id,
          producerId: consumer.producerId,
          kind: consumer.kind,
          rtpParameters: consumer.rtpParameters,
          producerUserId,
        });
      } catch (error: any) {
        socket.emit('error', { message: error.message });
      }
    }
  );

  socket.on('consumer:resume', async (data: { roomId: string; consumerId: string }) => {
    const { roomId, consumerId } = data;
    const room = getRoom(roomId);
    const consumer = room?.participants.get(userId)?.consumers.get(consumerId);
    if (consumer) await consumer.resume();
  });

  socket.on('consumer:pause', async (data: { roomId: string; consumerId: string }) => {
    const { roomId, consumerId } = data;
    const room = getRoom(roomId);
    const consumer = room?.participants.get(userId)?.consumers.get(consumerId);
    if (consumer) await consumer.pause();
  });

  // ─── Room Participants ────────────────────────────────────────────────────

  socket.on('room:participants', (data: { roomId: string }) => {
    const participants = getRoomParticipants(data.roomId).map((p) => ({
      userId: p.userId,
      producerIds: Array.from(p.producers.keys()),
    }));
    socket.emit('room:participants', participants);
  });

  // ─── Call End ─────────────────────────────────────────────────────────────

  socket.on('call:end', async (data: { roomId: string; durationSeconds: number }) => {
    await leaveRoom(socket, io, userId, data.roomId, data.durationSeconds, 'COMPLETED');
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
  removeParticipant(roomId, userId);
  socket.leave(roomId);

  // Notify remaining participants
  io.to(roomId).emit('room:participant_left', { userId });

  // Publish to RabbitMQ for background processing
  await publishCallEvent('call.completed', {
    roomId,
    userId,
    durationSeconds: durationSeconds ?? 0,
    status,
  });
}
