require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const { initDb } = require('./db');
const routes = require('./routes');
const { initWebSocket } = require('./services/wsServer');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json({ limit: '1mb' }));

// Routes
app.use('/api', routes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('[SERVER] Unhandled error:', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
async function start() {
  try {
    await initDb();
    console.log('[DB] Connected to PostgreSQL');

    const { initFirebaseAdmin } = require('./services/firebaseAdmin');
    initFirebaseAdmin();

    // Load background jobs
    require('./jobs/autoResolve');
    require('./jobs/staleAssignmentChecker');
    console.log('[JOBS] Background jobs loaded');

    // Initialize WebSocket GPS server
    initWebSocket(server);
    console.log('[WS] WebSocket server initialized');

    server.listen(PORT, () => {
      console.log(`[SERVER] FloodAid backend running on port ${PORT}`);
      console.log(`[SERVER] Environment: ${process.env.NODE_ENV}`);
    });
  } catch (err) {
    console.error('[SERVER] Failed to start:', err.message);
    process.exit(1);
  }
}

start();

module.exports = app;

