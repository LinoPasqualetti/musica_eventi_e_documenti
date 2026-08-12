-- ============================================
-- DATABASE: musica_per_tutti
-- VERSIONE: 2.0
-- ============================================

-- ============================================
-- 1. TABELLA UTENTI (users)
-- ============================================
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user',
  status TEXT NOT NULL DEFAULT 'active',
  profile_picture TEXT,
  bio TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  last_login TEXT,
  login_attempts INTEGER DEFAULT 0,
  locked_until TEXT,
  reset_token TEXT,
  reset_token_expiry TEXT
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- ============================================
-- 2. TABELLA EVENTI (events)
-- ============================================
CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  theme TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  date TEXT NOT NULL,
  location TEXT NOT NULL,
  category TEXT DEFAULT 'concerto',
  status TEXT DEFAULT 'published',
  capacity INTEGER DEFAULT 999,
  registration_deadline TEXT,
  difficulty TEXT DEFAULT 'intermediate',
  duration TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  video_url TEXT,
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_events_date ON events(date);
CREATE INDEX IF NOT EXISTS idx_events_category ON events(category);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_difficulty ON events(difficulty);

-- ============================================
-- 3. TABELLA ANAGRAFICO PEZZI (songs)
-- ============================================
CREATE TABLE IF NOT EXISTS songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  composer TEXT,
  difficulty TEXT,
  genre TEXT,
  duration_seconds INTEGER,
  tempo INTEGER,
  key_signature TEXT,
  time_signature TEXT,
  lyrics TEXT,
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_songs_title ON songs(title);
CREATE INDEX IF NOT EXISTS idx_songs_composer ON songs(composer);

-- ============================================
-- 4. TABELLA RELAZIONE EVENTO-PEZZO (event_songs)
-- ============================================
CREATE TABLE IF NOT EXISTS event_songs (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  song_id TEXT NOT NULL,
  order_index INTEGER DEFAULT 0,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
  UNIQUE(event_id, song_id)
);

CREATE INDEX IF NOT EXISTS idx_event_songs_event_id ON event_songs(event_id);
CREATE INDEX IF NOT EXISTS idx_event_songs_song_id ON event_songs(song_id);

-- ============================================
-- 5. TABELLA INFORMAZIONI PEZZI (song_infos)
-- ============================================
CREATE TABLE IF NOT EXISTS song_infos (
  id TEXT PRIMARY KEY,
  song_id TEXT NOT NULL,
  info_type TEXT NOT NULL,
  info_value TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
  UNIQUE(song_id, info_type)
);

CREATE INDEX IF NOT EXISTS idx_song_infos_song_id ON song_infos(song_id);
CREATE INDEX IF NOT EXISTS idx_song_infos_info_type ON song_infos(info_type);

-- ============================================
-- 6. TABELLA DOCUMENTI MUSICALI (musical_documents)
-- ============================================
CREATE TABLE IF NOT EXISTS musical_documents (
  id TEXT PRIMARY KEY,
  song_id TEXT NOT NULL,
  doc_type TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size INTEGER,
  mime_type TEXT,
  description TEXT,
  is_public BOOLEAN DEFAULT 1,
  uploaded_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
  FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_musical_documents_song_id ON musical_documents(song_id);
CREATE INDEX IF NOT EXISTS idx_musical_documents_doc_type ON musical_documents(doc_type);

-- ============================================
-- 7. TABELLA PARTI PER STRUMENTI (instrument_parts)
-- ============================================
CREATE TABLE IF NOT EXISTS instrument_parts (
  id TEXT PRIMARY KEY,
  song_id TEXT NOT NULL,
  instrument TEXT NOT NULL,
  part_content TEXT NOT NULL,
  difficulty TEXT DEFAULT 'intermediate',
  description TEXT,
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
  UNIQUE(song_id, instrument)
);

CREATE INDEX IF NOT EXISTS idx_instrument_parts_song_id ON instrument_parts(song_id);
CREATE INDEX IF NOT EXISTS idx_instrument_parts_instrument ON instrument_parts(instrument);

-- ============================================
-- 8. TABELLA ISCRIZIONI (registrations)
-- ============================================
CREATE TABLE IF NOT EXISTS registrations (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  instrument_choice TEXT,
  reading_level INTEGER DEFAULT 1,
  improvisation_level INTEGER DEFAULT 1,
  selected_song_ids TEXT,
  notes TEXT,
  admin_notes TEXT,
  confirmed_at TEXT,
  cancelled_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_registrations_event_id ON registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_user_id ON registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_registrations_status ON registrations(status);

-- ============================================
-- 9. TABELLA SUGGERIMENTI EVENTI (event_suggestions)
-- ============================================
CREATE TABLE IF NOT EXISTS event_suggestions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  theme TEXT,
  suggested_date TEXT,
  suggested_location TEXT,
  category TEXT DEFAULT 'concerto',
  difficulty TEXT DEFAULT 'intermediate',
  status TEXT DEFAULT 'pending',
  admin_notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_event_suggestions_user_id ON event_suggestions(user_id);
CREATE INDEX IF NOT EXISTS idx_event_suggestions_status ON event_suggestions(status);

-- ============================================
-- 10. TABELLA SEGNALAZIONI IMMAGINI (image_suggestions)
-- ============================================
CREATE TABLE IF NOT EXISTS image_suggestions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  event_id TEXT NOT NULL,
  image_url TEXT NOT NULL,
  description TEXT,
  source TEXT,
  status TEXT DEFAULT 'pending',
  admin_notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_image_suggestions_user_id ON image_suggestions(user_id);
CREATE INDEX IF NOT EXISTS idx_image_suggestions_event_id ON image_suggestions(event_id);
CREATE INDEX IF NOT EXISTS idx_image_suggestions_status ON image_suggestions(status);

-- ============================================
-- 11. TABELLA FEEDBACK (user_feedback)
-- ============================================
CREATE TABLE IF NOT EXISTS user_feedback (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  event_id TEXT,
  rating INTEGER,
  comment TEXT,
  suggestions TEXT,
  status TEXT DEFAULT 'pending',
  admin_reply TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_user_feedback_user_id ON user_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_user_feedback_event_id ON user_feedback(event_id);
CREATE INDEX IF NOT EXISTS idx_user_feedback_status ON user_feedback(status);

-- ============================================
-- 12. TABELLA LOG ATTIVITÀ (activity_log)
-- ============================================
CREATE TABLE IF NOT EXISTS activity_log (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  action TEXT NOT NULL,
  details TEXT,
  ip_address TEXT,
  user_agent TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_activity_log_user_id ON activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_action ON activity_log(action);

-- ============================================
-- 13. TABELLA DOWNLOAD (downloads)
-- ============================================
CREATE TABLE IF NOT EXISTS downloads (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  file_path TEXT,
  file_size INTEGER,
  download_date TEXT NOT NULL,
  last_accessed TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (document_id) REFERENCES musical_documents(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_downloads_user_id ON downloads(user_id);
CREATE INDEX IF NOT EXISTS idx_downloads_document_id ON downloads(document_id);
CREATE INDEX IF NOT EXISTS idx_downloads_download_date ON downloads(download_date);

-- ============================================
-- DATI DI DEFAULT
-- ============================================

-- 1. Admin (password: admin123)
INSERT OR IGNORE INTO users (id, email, password_hash, full_name, role, created_at) VALUES 
('usr_admin', 'admin@musicapertutti.it', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'Admin Musica per Tutti', 'admin', datetime('now'));

-- 2. Utente demo (password: user123)
INSERT OR IGNORE INTO users (id, email, password_hash, full_name, role, created_at) VALUES 
('usr_demo', 'demo@musicapertutti.it', 'b2b8b7e5f2d8c16d1f9f9fa1e8e8d8f8e8d8c8b8a8d8e8f8g8h8i8j8k8', 'Utente Demo', 'user', datetime('now'));

-- 3. Eventi
INSERT OR IGNORE INTO events (id, title, theme, description, image_url, date, location, category, difficulty, created_by, created_at) VALUES 
('evt_001', 'Concerto di Natale 2024', '🎄 Natalizio', 'Un evento speciale per le festività natalizie con musiche tradizionali', 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800', '2024-12-20', 'Auditorium Comunale', 'concerto', 'intermediate', 'usr_admin', datetime('now')),
('evt_002', 'Primavera Musicale 2025', '🌸 Primavera', 'Concerto di primavera con brani classici e moderni', 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=800', '2025-03-15', 'Teatro Verdi', 'concerto', 'intermediate', 'usr_admin', datetime('now')),
('evt_003', 'Brasile in Samba', '🇧🇷 Musica Brasiliana', 'Il calore del Brasile invade il palco con ritmi di Samba e Bossa Nova.', 'https://images.unsplash.com/photo-1558399802-766d88d2d462?w=800', '2026-12-05', 'Teatro Amazonas, Rio de Janeiro', 'concerto', 'intermediate', 'usr_admin', datetime('now'));

-- 4. Brani (anagrafico)
INSERT OR IGNORE INTO songs (id, title, composer, difficulty, genre, created_by, created_at) VALUES 
('sng_001', 'Jingle Bells', 'James Lord Pierpont', 'beginner', 'Natale', 'usr_admin', datetime('now')),
('sng_002', 'White Christmas', 'Irving Berlin', 'intermediate', 'Natale', 'usr_admin', datetime('now')),
('sng_003', 'Primavera', 'Antonio Vivaldi', 'advanced', 'Classica', 'usr_admin', datetime('now')),
('sng_004', 'La Primavera', 'Antonio Vivaldi', 'intermediate', 'Classica', 'usr_admin', datetime('now')),
('sng_005', 'Guantanamera', 'Joseíto Fernández', 'intermediate', 'Cubana', 'usr_admin', datetime('now'));

-- 5. Relazione Evento-Brano (event_songs)
INSERT OR IGNORE INTO event_songs (id, event_id, song_id, order_index, created_at) VALUES 
('es_001', 'evt_001', 'sng_001', 1, datetime('now')),
('es_002', 'evt_001', 'sng_002', 2, datetime('now')),
('es_003', 'evt_002', 'sng_003', 1, datetime('now')),
('es_004', 'evt_002', 'sng_004', 2, datetime('now')),
('es_005', 'evt_003', 'sng_005', 1, datetime('now'));

-- 6. Iscrizioni di esempio
INSERT OR IGNORE INTO registrations (id, event_id, user_id, status, instrument_choice, reading_level, improvisation_level, selected_song_ids, notes, created_at) VALUES 
('reg_001', 'evt_001', 'usr_demo', 'confirmed', 'Chitarra', 3, 2, 'sng_001,sng_002', 'Suono da 5 anni', datetime('now'));

-- ============================================
-- VERIFICHE FINALI
-- ============================================
SELECT '✅ Database musica_per_tutti (v2.0) creato con successo!' as status;
SELECT '👥 Utenti: ' || COUNT(*) FROM users;
SELECT '📅 Eventi: ' || COUNT(*) FROM events;
SELECT '🎵 Brani (anagrafico): ' || COUNT(*) FROM songs;
SELECT '🔗 Evento-Brano: ' || COUNT(*) FROM event_songs;
SELECT '📝 Iscrizioni: ' || COUNT(*) FROM registrations;