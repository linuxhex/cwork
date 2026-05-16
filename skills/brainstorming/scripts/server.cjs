#!/usr/bin/env node
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = __dirname;
const port = Number(process.env.CWORK_VISUAL_PORT || 3901);
const host = process.env.CWORK_VISUAL_HOST || '127.0.0.1';

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8'
};

const server = http.createServer((req, res) => {
  const urlPath = req.url.split('?')[0] || '/';
  const file = urlPath === '/' ? '/frame-template.html' : urlPath;
  const full = path.join(root, path.normalize(file));

  if (!full.startsWith(root)) {
    res.writeHead(403);
    res.end('forbidden');
    return;
  }

  fs.readFile(full, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('not found');
      return;
    }
    const ext = path.extname(full).toLowerCase();
    res.writeHead(200, { 'Content-Type': mime[ext] || 'application/octet-stream' });
    res.end(data);
  });
});

server.listen(port, host, () => {
  console.log(`CWORK_VISUAL_SERVER http://${host}:${port}`);
});
