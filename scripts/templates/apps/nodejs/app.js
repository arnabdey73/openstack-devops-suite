// Basic Node.js Express Application Template

const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to your Node.js application',
    version: '1.0.0',
    status: 'running'
  });
});

// Health endpoint for Kubernetes probes
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// API routes
app.get('/api/data', (req, res) => {
  res.json([
    { id: 1, name: 'Item 1' },
    { id: 2, name: 'Item 2' },
    { id: 3, name: 'Item 3' }
  ]);
});

// Start the server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
