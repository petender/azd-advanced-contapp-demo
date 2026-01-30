const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Version is set via environment variable during deployment
const VERSION = process.env.APP_VERSION || 'v1';
const COLOR = VERSION === 'v1' ? '#3b82f6' : '#22c55e'; // Blue for v1, Green for v2

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Hello API - ${VERSION}</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          display: flex;
          justify-content: center;
          align-items: center;
          min-height: 100vh;
          margin: 0;
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
          color: white;
        }
        .container {
          text-align: center;
          padding: 40px;
          background: rgba(255,255,255,0.05);
          border-radius: 20px;
          border: 2px solid ${COLOR};
          box-shadow: 0 0 30px ${COLOR}40;
        }
        h1 {
          font-size: 72px;
          margin: 0;
          color: ${COLOR};
        }
        p {
          font-size: 24px;
          color: #9ca3af;
          margin: 20px 0 0;
        }
        .version-badge {
          display: inline-block;
          background: ${COLOR};
          color: white;
          padding: 8px 24px;
          border-radius: 20px;
          font-size: 18px;
          font-weight: bold;
          margin-top: 20px;
        }
        .hostname {
          font-size: 12px;
          color: #6b7280;
          margin-top: 20px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🚀 Hello!</h1>
        <p>Azure Container Apps Traffic Splitting Demo</p>
        <div class="version-badge">${VERSION}</div>
        <p class="hostname">Hostname: ${require('os').hostname()}</p>
      </div>
    </body>
    </html>
  `);
});

app.get('/api/version', (req, res) => {
  res.json({
    version: VERSION,
    hostname: require('os').hostname(),
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', version: VERSION });
});

app.listen(PORT, () => {
  console.log(`Hello API ${VERSION} running on port ${PORT}`);
});
