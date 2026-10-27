import http from 'node:http';

const server = http.createServer((request, response) => {
  const url = new URL(request.url, 'http://127.0.0.1');
  if (url.pathname === '/hang') {
    const timer = setTimeout(() => response.destroy(), 30_000);
    response.on('close', () => clearTimeout(timer));
    return;
  }
  const used = url.searchParams.get('used') === '100' ? '100' : '0';
  const image = url.searchParams.has('blocked-image') ? '<img src="/hang" alt="">' : '';
  response.setHeader('Content-Type', 'text/html; charset=utf-8');
  if (url.pathname === '/login') {
    response.end('<!doctype html><title>Synthetic login</title><h1>Log in to Claude</h1><p>Continue with email</p>');
    return;
  }
  response.end(`<!doctype html><title>Synthetic Claude usage</title><main>
    <h1>Plan usage limits</h1><h2>Current session</h2><p>Resets at 12:00 PM</p><p>0% used</p>
    <h2>All models</h2><p>Resets Friday at 5:00 AM</p><p>${used}% used</p>
    ${image}</main>`);
});

server.listen(0, '127.0.0.1', () => console.log(server.address().port));
process.on('SIGTERM', () => {
  server.closeAllConnections();
  server.close();
});
