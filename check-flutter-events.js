const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./assets/db/musica_eventi_e_documenti.db');

console.log('=== TUTTI GLI EVENTI NEL DB FLUTTER ===\n');
db.all('SELECT id, title, status, date, created_at FROM events ORDER BY date DESC', (e, rows) => {
  if (e) { console.error('❌ Errore:', e.message); db.close(); return; }
  
  console.log(`Totale eventi: ${rows.length}\n`);
  console.table(rows);
  
  console.log('\n=== VERIFICA EVENTO "Las Vegas" ===');
  db.get("SELECT * FROM events WHERE id = '1789709896267'", (e2, ev) => {
    if (e2) console.error(e2);
    if (!ev) {
      console.log('❌ Evento 1789709896267 NON presente nel DB Flutter!');
      console.log('   → Questo è il problema: l\'evento esiste nel DB web ma non in quello locale.');
    } else {
      console.log('✅ Evento 1789709896267 TROVATO nel DB Flutter:');
      console.table([ev]);
    }
    db.close();
  });
});
