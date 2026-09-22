import * as mediasoup from 'mediasoup';
import type { Worker, Router, RtpCodecCapability } from 'mediasoup/types';
import { cpus } from 'os';

// Media codecs supported (video + audio)
const MEDIA_CODECS: RtpCodecCapability[] = [
  {
    kind: 'audio',
    mimeType: 'audio/opus',
    clockRate: 48000,
    channels: 2,
    preferredPayloadType: 111,
  },
  {
    kind: 'video',
    mimeType: 'video/H264',
    clockRate: 90000,
    preferredPayloadType: 125,
    parameters: {
      'packetization-mode': 1,
      'profile-level-id': '42e01f',
      'level-asymmetry-allowed': 1,
    },
  },
  {
    kind: 'video',
    mimeType: 'video/VP8',
    clockRate: 90000,
    preferredPayloadType: 96,
  },
];

// Worker pool for distributing load across CPU cores
let workers: Worker[] = [];
let workerIndex = 0;

const NUM_WORKERS = Math.min(4, Math.max(1, cpus().length));

export async function initWorkerPool() {
  console.log(`Creating ${NUM_WORKERS} Mediasoup workers...`);
  for (let i = 0; i < NUM_WORKERS; i++) {
    const worker = await mediasoup.createWorker({
      logLevel: 'warn',
      rtcMinPort: 40000,
      rtcMaxPort: 49999,
    });

    worker.on('died', () => {
      console.error(`Mediasoup worker #${i} died, restarting...`);
      // Remove the dead worker and replace
      workers = workers.filter((w) => w !== worker);
      createWorker(i);
    });

    workers.push(worker);
    console.log(`Mediasoup worker #${i} created (pid: ${worker.pid})`);
  }
}

async function createWorker(index: number) {
  const worker = await mediasoup.createWorker({
    logLevel: 'warn',
    rtcMinPort: 40000,
    rtcMaxPort: 49999,
  });
  workers[index] = worker;
  return worker;
}

/**
 * Get next available worker using round-robin
 */
function getNextWorker(): Worker {
  const worker = workers[workerIndex % workers.length];
  workerIndex++;
  return worker;
}

/**
 * Create a new Mediasoup Router (one per room)
 */
export async function createRouter(): Promise<Router> {
  const worker = getNextWorker();
  const router = await worker.createRouter({ mediaCodecs: MEDIA_CODECS });
  return router;
}
