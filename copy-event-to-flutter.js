const sqlite3 = require('sqlite3').verbose();

const WEB_DB = 'C:/musica_eventi_e_documenti_web/backend/data/musica_eventi_e_documenti_web.db';
const FLUTTER_DB = './assets/db/musica_eventi_e_documenti.db';

const EVENT_ID = '1789709896267';

const webDb = new sqlite3.Database(WEB_DB, sqlite3.OPEN_READONLY);
const flutterDb = new sqlite3.Database(FLUTTER_DB);

console.log('🔄 Copia evento dal DB web al DB Flutter...\n');

webDb.get('SELECT * FROM events WHERE id = ?', [EVENT_ID], (err, event) => {
  if (err) {
    console.error('❌ Errore lettura evento dal DB web:', err.message);
    webDb.close(); flutterDb.close();
    return;
  }
  if (!event) {
    console.error('❌ Evento non trovato nel DB web!');
    webDb.close(); flutterDb.close();
    return;
  }

  console.log('✅ Evento trovato nel DB web:');
  console.log(`   id: ${event.id}`);
  console.log(`   title: ${event.title}`);
  console.log(`   status: ${event.status}`);
  console.log(`   date: ${event.date}\n`);

  // Verifica se già presente in Flutter
  flutterDb.get('SELECT id FROM events WHERE id = ?', [EVENT_ID], (err2, existing) => {
    if (err2) {
      console.error('❌ Errore check DB Flutter:', err2.message);
      webDb.close(); flutterDb.close();
      return;
    }

    if (existing) {
      console.log('ℹ️  Evento già presente nel DB Flutter, skip.');
      webDb.close(); flutterDb.close();
      return;
    }

    // Ottieni le colonne del DB Flutter per filtrare solo quelle esistenti
    flutterDb.all('PRAGMA table_info(events)', (err3, flutterCols) => {
      if (err3) {
        console.error('❌ Errore lettura schema Flutter:', err3.message);
        webDb.close(); flutterDb.close();
        return;
      }

      const flutterColumns = flutterCols.map(c => c.name);
      console.log(`📋 Colonne DB Flutter (events): ${flutterColumns.join(', ')}\n`);

      // Filtra solo le colonne che esistono in entrambi
      const columnsToCopy = Object.keys(event).filter(k => flutterColumns.includes(k));
      const values = columnsToCopy.map(k => event[k]);
      const placeholders = columnsToCopy.map(() => '?').join(',');

      console.log(`📋 Colonne da copiare: ${columnsToCopy.join(', ')}\n`);

      const insertSQL = `INSERT INTO events (${columnsToCopy.join(',')}) VALUES (${placeholders})`;

      flutterDb.run(insertSQL, values, function(err4) {
        if (err4) {
          console.error('❌ Errore INSERT:', err4.message);
        } else {
          console.log(`✅ Evento inserito nel DB Flutter (righe: ${this.changes})`);
          
          // Verifica finale
          flutterDb.get('SELECT id, title, status FROM events WHERE id = ?', [EVENT_ID], (err5, check) => {
            if (err5) console.error(err5);
            else {
              console.log('\n=== VERIFICA FINALE ===');
              console.log(`✅ Evento nel DB Flutter: ${check.title} (${check.status})`);
            }
            webDb.close(); flutterDb.close();
          });
        }
      });
    });
  });
});
