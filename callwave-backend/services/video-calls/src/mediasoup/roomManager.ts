import { randomUUID } from 'node:crypto';
import type { Router, WebRtcTransport, Producer, Consumer } from 'mediasoup/types';
import { createRouter } from './workerPool.js';

// WebRTC transport options
const WEBRTC_TRANSPORT_OPTIONS = {
  listenInfos: [
    { protocol: 'udp' as const, ip: '0.0.0.0', announcedAddress: process.env.ANNOUNCED_IP || '127.0.0.1' },
    { protocol: 'tcp' as const, ip: '0.0.0.0', announcedAddress: process.env.ANNOUNCED_IP || '127.0.0.1' },
  ],
  enableUdp: true,
  enableTcp: true,
  preferUdp: true,
  enableSctp: false,
  // Simulcast / adaptive bitrate settings
  initialAvailableOutgoingBitrate: 800_000, // 800 kbps
  minimumAvailableOutgoingBitrate: 100_000, // 100 kbps
};

export interface Participant {
  userId: string;
  socketId: string;
  sendTransport?: WebRtcTransport;
  recvTransport?: WebRtcTransport;
  producers: Map<string, Producer>; // producerId -> Producer
  consumers: Map<string, Consumer>; // consumerId -> Consumer
}

export interface Room {
  roomId: string;
  instanceId: string;
  router: Router;
  participants: Map<string, Participant>; // userId -> Participant
  createdAt: Date;
}

// In-memory room registry — in a production multi-node setup these would be in Redis,
// but since Mediasoup is process-bound, rooms live on the node that created them.
const rooms = new Map<string, Room>();
const pendingRooms = new Map<string, Promise<Room>>();

export function getRoom(roomId: string): Room | undefined {
  return rooms.get(roomId);
}

export async function getOrCreateRoom(roomId: string): Promise<Room> {
  const existing = rooms.get(roomId);
  if (existing) return existing;

  let pending = pendingRooms.get(roomId);
  if (!pending) {
    pending = (async () => {
      const router = await createRouter();
      const room: Room = {
        roomId,
        instanceId: randomUUID(),
        router,
        participants: new Map(),
        createdAt: new Date(),
      };
      rooms.set(roomId, room);
      console.log('Room created');
      return room;
    })();
    pendingRooms.set(roomId, pending);
  }
  try {
    return await pending;
  } finally {
    if (pendingRooms.get(roomId) === pending) pendingRooms.delete(roomId);
  }
}

export function addParticipant(roomId: string, userId: string, socketId: string): Participant {
  const room = rooms.get(roomId);
  if (!room) throw new Error('Room not found');

  const previous = room.participants.get(userId);
  if (previous?.socketId === socketId) return previous;
  if (previous) {
    previous.sendTransport?.close();
    previous.recvTransport?.close();
    previous.producers.forEach((producer) => producer.close());
    previous.consumers.forEach((consumer) => consumer.close());
  }

  const participant: Participant = {
    userId,
    socketId,
    producers: new Map(),
    consumers: new Map(),
  };

  room.participants.set(userId, participant);
  return participant;
}

export function removeParticipant(roomId: string, userId: string): void {
  const room = rooms.get(roomId);
  if (!room) return;

  const participant = room.participants.get(userId);
  if (participant) {
    // Cleanup transports
    participant.sendTransport?.close();
    participant.recvTransport?.close();
    // Cleanup producers
    participant.producers.forEach((p) => p.close());
    // Cleanup consumers
    participant.consumers.forEach((c) => c.close());
    room.participants.delete(userId);
  }

  // Close room if empty
  if (room.participants.size === 0) {
    room.router.close();
    rooms.delete(roomId);
    console.log('Room closed (empty)');
  }
}

export async function createWebRtcTransport(roomId: string, userId: string, direction: 'send' | 'recv'): Promise<WebRtcTransport> {
  const room = rooms.get(roomId);
  if (!room) throw new Error('Room not found');

  const participant = room.participants.get(userId);
  if (!participant) throw new Error('Participant not in room');

  const transport = await room.router.createWebRtcTransport(WEBRTC_TRANSPORT_OPTIONS);

  if (direction === 'send') {
    participant.sendTransport = transport;
  } else {
    participant.recvTransport = transport;
  }

  return transport;
}

export function getRoomParticipants(roomId: string): Participant[] {
  const room = rooms.get(roomId);
  if (!room) return [];
  return Array.from(room.participants.values());
}

export function getAllRoomsInfo() {
  return Array.from(rooms.values()).map((r) => ({
    roomId: r.roomId,
    participantCount: r.participants.size,
    createdAt: r.createdAt,
  }));
}
