import { createServer } from 'node:http';
import { config } from '@callwave/config';

const service = 'background-processes';
const port = config.app.port + 3;

const server = createServer((request, response) => {
  if (request.url === '/health') {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ service, status: 'ok', timestamp: new Date().toISOString() }));
    return;
  }
  response.writeHead(404);
  response.end();
});

server.listen(port, config.app.host, () => {
  console.log(`${service} listening on ${config.app.host}:${port}`);
});

process.on('SIGTERM', () => server.close());
process.on('SIGINT', () => server.close());
