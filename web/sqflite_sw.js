// web/sqflite_sw.js
// Service Worker per SQLite su web

self.importScripts('https://cdn.jsdelivr.net/npm/sql.js@1.10.3/dist/sql-wasm.js');

self.addEventListener('message', function(e) {
  const data = e.data;
  switch (data.action) {
    case 'open':
      const db = new SQL.Database();
      self.db = db;
      self.postMessage({ id: data.id, result: 'ok' });
      break;
    case 'exec':
      try {
        const results = self.db.exec(data.sql);
        self.postMessage({ id: data.id, result: results });
      } catch (error) {
        self.postMessage({ id: data.id, error: error.message });
      }
      break;
    default:
      self.postMessage({ id: data.id, error: 'Unknown action' });
  }
});

console.log('✅ SQLite Service Worker caricato');