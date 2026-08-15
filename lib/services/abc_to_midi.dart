// lib/services/abc_to_midi.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class AbcToMidiConverter {
  // Converte un file ABC in MIDI (generazione manuale)
  static Future<File?> convertToMidi(String abcContent, String fileName) async {
    try {
      // Estrai le note dall'ABC
      final notes = _extractNotesFromAbc(abcContent);

      if (notes.isEmpty) {
        print('⚠️ Nessuna nota trovata nell\'ABC');
        return null;
      }

      // Genera i byte MIDI
      final midiData = _generateMidi(notes);

      if (midiData == null) {
        print('❌ Impossibile generare MIDI');
        return null;
      }

      // Salva il file MIDI
      final tempDir = await getTemporaryDirectory();
      final midiFile = File('${tempDir.path}/${fileName.replaceAll('.abc', '.mid')}');
      await midiFile.writeAsBytes(midiData);

      print('✅ MIDI creato: ${midiFile.path}');
      return midiFile;
    } catch (e) {
      print('❌ Errore conversione ABC→MIDI: $e');
      return null;
    }
  }

  // Estrae le note dal contenuto ABC
  static List<MidiNote> _extractNotesFromAbc(String abcContent) {
    final List<MidiNote> notes = [];
    final lines = abcContent.split('\n');

    // Mappa note ABC → MIDI pitch
    final Map<String, int> noteMap = {
      'C': 60, 'D': 62, 'E': 64, 'F': 65, 'G': 67, 'A': 69, 'B': 71,
      'c': 72, 'd': 74, 'e': 76, 'f': 77, 'g': 79, 'a': 81, 'b': 83,
      '^C': 61, '^D': 63, '^F': 66, '^G': 68, '^A': 70, '^c': 73, '^d': 75,
      '^f': 78, '^g': 80, '^a': 82,
      '_B': 70, '_E': 63, '_A': 68, '_D': 61, '_G': 66, '_b': 82,
    };

    int defaultDuration = 240; // Durata base

    for (var line in lines) {
      // Salta le righe di metadati
      if (line.startsWith('X:') || line.startsWith('T:') ||
          line.startsWith('C:') || line.startsWith('M:') ||
          line.startsWith('K:') || line.startsWith('Q:') ||
          line.startsWith('L:') || line.startsWith('%%') ||
          line.startsWith('|') && line.length < 3) {
        continue;
      }

      // Cerca le note nella riga (formato ABC base)
      final notePattern = RegExp(r'[A-Ga-g][,]?');
      final matches = notePattern.allMatches(line);

      for (var match in matches) {
        final noteStr = match.group(0)!;
        final pitch = noteMap[noteStr];
        if (pitch != null) {
          notes.add(MidiNote(pitch: pitch, duration: defaultDuration));
        }
      }
    }

    return notes;
  }

  // Genera il file MIDI manualmente
  static Uint8List? _generateMidi(List<MidiNote> notes) {
    try {
      // Header MIDI
      final header = _createMidiHeader();

      // Track MIDI
      final track = _createMidiTrack(notes);

      // Combina header + track
      final midiData = Uint8List.fromList([...header, ...track]);

      return midiData;
    } catch (e) {
      print('❌ Errore generazione MIDI: $e');
      return null;
    }
  }

  // Crea l'header MIDI (MThd)
  static List<int> _createMidiHeader() {
    // MThd + length (6) + format (0) + tracks (1) + division (96)
    return [
      0x4D, 0x54, 0x68, 0x64, // MThd
      0x00, 0x00, 0x00, 0x06, // length
      0x00, 0x00, // format 0
      0x00, 0x01, // one track
      0x00, 0x60, // division (96)
    ];
  }

  // Crea la traccia MIDI (MTrk)
  static List<int> _createMidiTrack(List<MidiNote> notes) {
    final List<int> track = [];

    // MTrk header
    track.addAll([0x4D, 0x54, 0x72, 0x6B]); // MTrk

    // Calcola la lunghezza della traccia (sarà aggiornata dopo)
    final lengthPosition = track.length;
    track.addAll([0x00, 0x00, 0x00, 0x00]); // placeholder per la lunghezza

    int time = 0;
    int tempo = 0x07A120; // 120 BPM

    // Set tempo (Meta Event)
    track.addAll(_createMetaEvent(time, 0x51, _intToBytes(tempo, 3)));
    time += 0;

    // Set channel (Program Change - Piano)
    track.addAll(_createChannelEvent(time, 0xC0, 0));
    time += 0;

    // Aggiungi le note
    for (var note in notes) {
      // Note On
      track.addAll(_createChannelEvent(time, 0x90, note.pitch, 64));
      // Note Off dopo la durata
      track.addAll(_createChannelEvent(time + note.duration, 0x80, note.pitch, 0));
      time += note.duration;
    }

    // End of Track (Meta Event)
    track.addAll(_createMetaEvent(time, 0x2F, []));

    // Aggiorna la lunghezza
    final trackLength = track.length - 8;
    final lengthBytes = _intToBytes(trackLength, 4);
    for (int i = 0; i < 4; i++) {
      track[lengthPosition + i] = lengthBytes[i];
    }

    return track;
  }

  // Crea un Meta Event
  static List<int> _createMetaEvent(int time, int type, List<int> data) {
    final List<int> event = [];

    // Delta time (semplificato)
    event.addAll(_writeVarLen(time));

    // Meta event
    event.add(0xFF);
    event.add(type);
    event.add(data.length);
    event.addAll(data);

    return event;
  }

  // Crea un Channel Event
  static List<int> _createChannelEvent(int time, int status, int data1, [int data2 = 0]) {
    final List<int> event = [];

    // Delta time
    event.addAll(_writeVarLen(time));

    // Channel event
    event.add(status);
    event.add(data1);
    if (status >= 0x80 && status < 0xF0 && status != 0xC0 && status != 0xD0) {
      event.add(data2);
    }

    return event;
  }

  // Scrive un valore in formato Variable Length (MIDI)
  static List<int> _writeVarLen(int value) {
    final List<int> bytes = [];
    if (value == 0) {
      bytes.add(0);
      return bytes;
    }

    // Converti in formato a lunghezza variabile
    int v = value;
    while (v > 0) {
      int b = v & 0x7F;
      v >>= 7;
      if (v > 0) {
        b |= 0x80;
      }
      bytes.insert(0, b);
    }
    return bytes;
  }

  // Converte un intero in lista di byte (big-endian)
  static List<int> _intToBytes(int value, int length) {
    final List<int> bytes = [];
    for (int i = length - 1; i >= 0; i--) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }
}

class MidiNote {
  final int pitch;
  final int duration;

  MidiNote({required this.pitch, required this.duration});
}