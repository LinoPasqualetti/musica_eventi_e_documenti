// lib/screens/midi_player_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import '../models/document.dart';

class MidiPlayerScreen extends StatefulWidget {
  final Document document;

  const MidiPlayerScreen({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  State<MidiPlayerScreen> createState() => _MidiPlayerScreenState();
}

class _MidiPlayerScreenState extends State<MidiPlayerScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('🎹🎹🎹 MIDI PLAYER INIT STATE 🎹🎹🎹');
    print('📁 File: ${widget.document.fileName}');
    print('📁 Tipo: ${widget.document.docType}');
    print('📁 Percorso: ${widget.document.filePath}');
    print('🌐 Web: $kIsWeb');
    _checkFile();
  }

  void _checkFile() {
    if (kIsWeb) {
      print('🌐 Modalità web - il file verrà gestito via URL');
      return;
    }

    final filePath = widget.document.filePath;
    final exists = File(filePath).existsSync();
    print('🔍 File esiste? $exists');
    if (!exists) {
      setState(() {
        _error = 'File non trovato: $filePath';
      });
    }
  }

  // ✅ APERTURA SU DESKTOP
  void _openMidiDesktop() async {
    print('🎹🎹🎹 OPEN MIDI (DESKTOP) 🎹🎹🎹');
    final filePath = widget.document.filePath;
    print('📁 Apertura: $filePath');

    setState(() => _isLoading = true);

    try {
      if (Platform.isWindows) {
        print('🪟 Windows: apertura con explorer...');
        await Process.run('explorer', [filePath]);
        print('✅ Explorer lanciato');
      } else if (Platform.isMacOS) {
        print('🍎 macOS: apertura con open...');
        await Process.run('open', [filePath]);
        print('✅ open lanciato');
      } else if (Platform.isLinux) {
        print('🐧 Linux: apertura con xdg-open...');
        await Process.run('xdg-open', [filePath]);
        print('✅ xdg-open lanciato');
      } else {
        print('📱 Altro: tentativo con OpenFile...');
        await OpenFile.open(filePath);
        print('✅ OpenFile lanciato');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎹 Apertura MIDI/KAR...'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('❌ Errore apertura: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ APERTURA SU WEB (senza AnchorElement)
  void _openMidiWeb() async {
    print('🎹🎹🎹 OPEN MIDI (WEB) 🎹🎹🎹');
    final fileName = widget.document.fileName;
    print('📁 File: $fileName');

    setState(() => _isLoading = true);

    try {
      // Usa url_launcher per aprire il file
      final url = '/assets/documents/$fileName';
      print('🌐 URL: $url');

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Apertura web riuscita');
      } else {
        print('⚠️ Impossibile aprire, mostro dialog download');
        _showWebDownloadDialog();
      }
    } catch (e) {
      print('❌ Errore apertura web: $e');
      _showWebDownloadDialog();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ DOWNLOAD SU WEB - versione sicura
  void _downloadFileWeb() {
    print('⬇️ DOWNLOAD WEB');
    final fileName = widget.document.fileName;
    final url = '/assets/documents/$fileName';
    print('📁 Download: $url');

    try {
      // Usa url_launcher per il download
      _launchUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⬇️ Download iniziato...'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Errore download: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore download: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ✅ DIALOG DOWNLOAD PER WEB
  void _showWebDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📥 Download File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📄 ${widget.document.fileName}'),
            const SizedBox(height: 8),
            const Text(
              '💡 Su web, i file MIDI/KAR non possono essere riprodotti direttamente.\n'
                  'Scarica il file e aprilo con un player MIDI locale.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Player MIDI consigliati:\n'
                  '• VanBasco Karaoke Player\n'
                  '• Windows Media Player\n'
                  '• MuseScore\n'
                  '• VLC Media Player',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadFileWeb();
            },
            icon: const Icon(Icons.download),
            label: const Text('Scarica'),
          ),
        ],
      ),
    );
  }

  // ✅ INFORMAZIONI
  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.document.docType == 'kar' ? '🎤 Karaoke MIDI' : '🎹 MIDI',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📄 File: ${widget.document.fileName}'),
            const SizedBox(height: 4),
            Text('📁 Tipo: ${widget.document.docType.toUpperCase()}'),
            const SizedBox(height: 4),
            Text('🌐 Piattaforma: ${kIsWeb ? "Web" : "Desktop"}'),
            const SizedBox(height: 8),
            if (kIsWeb)
              const Text(
                '💡 Su web, i file MIDI/KAR devono essere scaricati '
                    'e aperti con un player MIDI locale.',
                style: TextStyle(color: Colors.grey),
              )
            else
              const Text(
                '💡 Apri il file con il player MIDI predefinito del sistema.',
                style: TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 8),
            Text(
              '📂 Percorso: ${widget.document.filePath}',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKaraoke = widget.document.docType == 'kar';
    final iconColor = isKaraoke ? Colors.purple : Colors.deepPurple;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.document.fileName),
          backgroundColor: iconColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _checkFile();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              isKaraoke ? Icons.mic : Icons.piano,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(widget.document.fileName),
          ],
        ),
        backgroundColor: iconColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
            tooltip: 'Info',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isKaraoke ? Icons.mic : Icons.piano,
                size: 80,
                color: iconColor.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                isKaraoke ? '🎤 Karaoke MIDI' : '🎹 MIDI Player',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.document.fileName,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  kIsWeb ? '🌐 Web' : '🖥️ Desktop',
                  style: TextStyle(
                    fontSize: 12,
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Pulsanti
              if (kIsWeb) ...[
                // WEB
                const Text(
                  '🌐 Modalità Web',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'I file MIDI/KAR devono essere scaricati e aperti localmente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _openMidiWeb,
                      icon: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.open_in_browser),
                      label: const Text('Apri nel browser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _downloadFileWeb,
                      icon: const Icon(Icons.download),
                      label: const Text('Scarica'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // DESKTOP
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _openMidiDesktop,
                  icon: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.play_arrow, size: 32),
                  label: const Text('🎵 Apri e suona'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _downloadFileWeb,
                  icon: const Icon(Icons.download),
                  label: const Text('Scarica'),
                ),
              ],

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      '💡 Suggerimento',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kIsWeb
                          ? '🌐 Su web, scarica il file e aprilo con un player MIDI locale\n'
                          '(es. VanBasco, Windows Media Player, MuseScore, VLC)'
                          : '🖥️ Il file verrà aperto con il player MIDI predefinito del sistema',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}