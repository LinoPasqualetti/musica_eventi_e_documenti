// lib/data/instrument_catalog.dart
import '../models/organ_slot.dart';

/// Catalogo degli strumenti e delle voci disponibili, raggruppati per le 4 sezioni.
/// Usato dal wizard di composizione organico per popolare la colonna
/// "Strumenti disponibili".
///
/// Ordine alfabetico all'interno di ciascuna sezione.
class InstrumentCatalog {
  /// Mappa sezione → lista di strumenti/voci disponibili.
  static const Map<OrganSection, List<String>> bySection = {
    OrganSection.ritmica: [
      'Basso acustico',
      'Basso elettrico',
      'Batteria',
      'Cajon',
      'Congas',
      'Contrabbasso (jazz)',
      'Djembe',
      'Percussioni',
      'Pianoforte (ritmica)',
      'Timpani',
      'Xilofono',
    ],
    OrganSection.armonica: [
      'Chitarra acustica',
      'Chitarra elettrica',
      'Chitarra classica',
      'Clavicembalo',
      'Fisarmonica',
      'Organo Hammond',
      'Pianoforte',
      'Tastiera elettrica',
      'Ukulele',
    ],
    OrganSection.solistica: [
      // 🎤 VOCI SOLISTE
      'Voce bianca (bambino)',
      'Voce femminile (soprano)',
      'Voce femminile (mezzo-soprano)',
      'Voce femminile (contralto)',
      'Voce maschile (tenore)',
      'Voce maschile (baritono)',
      'Voce maschile (basso)',
      // 🎺 STRUMENTI SOLISTI
      'Armonica a bocca',
      'Clarinetto',
      'Fagotto',
      'Flauto dolce',
      'Flauto traverso',
      'Oboe',
      'Ottavino',
      'Sassofono baritono',
      'Sassofono contralto',
      'Sassofono soprano',
      'Sassofono tenore',
      'Tromba in Bb',
      'Trombone',
      'Violino solista',
    ],
    OrganSection.orchestrale: [
      // 🎤 SEZIONI CORALI (voci in gruppo)
      'Coro - Contralti',
      'Coro - Bassi',
      'Coro - Soprani',
      'Coro - Tenori',
      'Coro unisono (tutti)',
      // 🎻 STRUMENTI ORCHESTRALI
      'Arpa',
      'Contrabbasso',
      'Corno francese',
      'Flicorno',
      'Tuba',
      'Viola',
      'Violino I',
      'Violino II',
      'Violoncello',
    ],
  };

  /// Ritorna tutti gli strumenti/voci di una sezione.
  static List<String> forSection(OrganSection section) {
    return bySection[section] ?? const [];
  }

  /// Ritorna tutte le sezioni con almeno uno strumento.
  static List<OrganSection> get allSections {
    return OrganSection.values.where((s) => bySection.containsKey(s)).toList();
  }

  /// Ritorna il numero totale di strumenti/voci disponibili.
  static int get totalInstruments {
    return bySection.values.fold(0, (sum, list) => sum + list.length);
  }

  /// Cerca la sezione di uno strumento/voce (case-insensitive).
  /// Ritorna null se non trovato.
  static OrganSection? findSection(String instrument) {
    final lower = instrument.toLowerCase().trim();
    for (final entry in bySection.entries) {
      if (entry.value.any((s) => s.toLowerCase().trim() == lower)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Verifica se una stringa è una voce umana (per UI differenziata).
  static bool isVoice(String instrument) {
    final lower = instrument.toLowerCase();
    return lower.contains('voce') || lower.contains('coro');
  }
}