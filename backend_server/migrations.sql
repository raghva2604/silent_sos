CREATE TABLE IF NOT EXISTS sos_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  event_type TEXT,
  status TEXT DEFAULT 'open',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  message_sid TEXT,
  recipients TEXT,
  recording_path TEXT,
  extra TEXT
);

CREATE TABLE IF NOT EXISTS recordings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  short TEXT UNIQUE,
  path TEXT,
  filename TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
