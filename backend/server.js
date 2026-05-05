const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
});

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).send('ok');
});

app.get('/messages', async (_req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, username, content, created_at FROM messages ORDER BY created_at ASC LIMIT 50'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching messages:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/messages', async (req, res) => {
  const { username, content } = req.body;

  if (!username || !username.trim() || !content || !content.trim()) {
    return res.status(400).json({ error: 'username and content are required' });
  }

  try {
    const result = await pool.query(
      'INSERT INTO messages (username, content) VALUES ($1, $2) RETURNING id, username, content, created_at',
      [username.trim(), content.trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error inserting message:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

async function init() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('Database initialized');
  } catch (err) {
    console.error('Database initialization error:', err);
    process.exit(1);
  }

  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

init();
