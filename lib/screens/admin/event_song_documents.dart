// lib/screens/admin/event_song_documents.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/database_service.dart';
import '../../models/event_model.dart';
import '../../models/document.dart';
import '../../utils/performance_logger.dart';
import '../document_viewer_screen.dart';
import 'document_form_screen.dart';

class EventSongDocumentsScreen extends StatefulWidget {
  final String eventId;
  final String songId;
  final String eventSongId;
  final String songTitle;

  const EventSongDocumentsScreen({
    Key? key,
    required this.eventId,
    required this.songId,
    required this.eventSongId,
    required this.songTitle,
  }) : super(key: key);

  @override
  State<EventSongDocumentsScreen> createState() => _EventSongDocumentsScreenState();
}

class _EventSongDocumentsScreenState extends State<EventSongDocumentsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _assignedDocuments = [];
  List<Document> _availableDocuments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    PerformanceLogger.info('EventSongDocumentsScreen inizializzato');
    _loadData();
  }

  Future<void> _loadData() async {
    PerformanceLogger.start('_loadData');

    setState(() => _isLoading = true);
    try {
      final assigned = await _db.getEventSongDocumentsWithDetails(widget.eventSongId);
      final songDocuments = await _db.getDocumentsBySong(widget.songId);

      final assignedIds = <String>{};
      for (var doc in assigned) {
        final id = doc['document_id'];
        if (id != null && id is String) {
          assignedIds.add(id);
        }
      }

      final available = songDocuments.where((d) => !assignedIds.contains(d.id)).toList();

      setState(() {
        _assignedDocuments = assigned;
        _availableDocuments = available;
        _isLoading = false;
      });

      PerformanceLogger.info('Documenti caricati',
          details: 'Assegnati: ${assigned.length}, Disponibili: ${available.length}');

    } catch (e) {
      setState(() => _isLoading = false);
      PerformanceLogger.error('_loadData fallito', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    PerformanceLogger.stop('_loadData');
  }

  Future<void> _addDocument(Document doc) async {
    PerformanceLogger.start('_addDocument');

    try {
      await _db.addDocumentToEventSong(widget.eventSongId, doc.id);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Documento aggiunto con successo'),
            backgroundColor: Colors.green,
          ),
        );
      }

      PerformanceLogger.info('Documento aggiunto', details: doc.fileName);

    } catch (e) {
      PerformanceLogger.error('_addDocument fallito', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    PerformanceLogger.stop('_addDocument');
  }

  Future<void> _removeDocument(Map<String, dynamic> doc) async {
    PerformanceLogger.start('_removeDocument');

    try {
      await _db.removeDocumentFromEventSong(
        widget.eventSongId,
        doc['document_id'] as String,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Documento rimosso da questo evento'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      PerformanceLogger.info('Documento rimosso', details: doc['file_name']);

    } catch (e) {
      PerformanceLogger.error('_removeDocument fallito', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    PerformanceLogger.stop('_removeDocument');
  }

  void _viewDocument(Map<String, dynamic> doc) {
    PerformanceLogger.start('_viewDocument');

    final document = Document(
      id: doc['document_id'] as String,
      docType: doc['doc_type'] ?? '',
      fileName: doc['file_name'] ?? '',
      filePath: doc['file_path'] ?? '',
      fileSize: doc['file_size'] ?? 0,
      description: doc['description'] ?? '',
      isPublic: (doc['is_public'] ?? 0) == 1,
      uploadedBy: '',
      createdAt: DateTime.now().toIso8601String(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(document: document),
      ),
    );

    PerformanceLogger.info('Documento visualizzato', details: document.fileName);
    PerformanceLogger.stop('_viewDocument');
  }

  Future<void> _createNewDocument() async {
    PerformanceLogger.start('_createNewDocument');

    try {
      // 🔥 USA FileType.any PER SELEZIONARE QUALSIASI FILE (inclusi MID, KAR, MXL, ABC)
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true, // 🔥 NECESSARIO PER LEGGERE I BYTE SU ANDROID!
        type: FileType.any, // 🔥 NON USARE FileType.custom! Permette TUTTO!
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileName = file.name;
      final fileSize = file.size;
      final filePath = file.path; // Percorso (per Windows) - potrebbe essere null su Android

      // 🔥 DICHIARA LE VARIABILI PRIMA DI USARLE!
      String docType = _getTypeFromExtension(fileName.split('.').last.toLowerCase());

      Uint8List? content;
      String storageMode = 'filesystem';

      // 🔥 SE IL PERCORSO ESISTE (Windows): prova a leggere dal file fisico
      if (filePath != null && await File(filePath).exists()) {
        if (['mid', 'kar', 'abc', 'mxl'].contains(docType)) {
          content = await File(filePath).readAsBytes();
          storageMode = 'blob';
          print('📦 BLOB da file fisico: ${content!.length} bytes');
        }
      } else {
        // 🔥 PER ANDROID (Google Drive, ecc.): usa file.bytes!
        if (file.bytes != null) {
          content = file.bytes;
          storageMode = 'blob';
          print('📦 BLOB da file.bytes: ${content!.length} bytes');
        }
      }

      // 🔥 FALLBACK: se non abbiamo ancora il BLOB, prova a leggere dal percorso
      if (content == null && filePath != null) {
        try {
          content = await File(filePath).readAsBytes();
          storageMode = 'blob';
        } catch (e) {
          print('❌ Errore lettura file: $e');
        }
      }

      // 🔥 DICHIARA IL CONTROLLER PER LA DESCRIZIONE
      final descriptionController = TextEditingController();
      final titleController = TextEditingController(text: fileName);

      final resultDialog = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('📄 Nuovo Documento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Nome file',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'Tipo: $docType',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dimensione: ${_formatFileSize(fileSize)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Crea e Aggiungi'),
            ),
          ],
        ),
      );

      if (resultDialog != true) return;

      // 🔥 COSTRUISCI IL DOCUMENTO
      final document = Document(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        docType: docType,
        fileName: titleController.text.trim(),
        filePath: filePath, // Può essere null su Android
        fileSize: fileSize,
        description: descriptionController.text.trim(),
        isPublic: true,
        uploadedBy: 'admin',
        createdAt: DateTime.now().toIso8601String(),
        content: content, // 🔥 BLOB per Android!
        storageMode: storageMode,
        songId: widget.songId,
      );

      await _db.insertDocument(document);
      await _db.addDocumentToEventSong(
        widget.eventSongId,
        document.id,
        orderIndex: _assignedDocuments.length,
      );
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Documento creato e aggiunto all\'evento!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      PerformanceLogger.info('Documento creato', details: document.fileName);

    } catch (e) {
      PerformanceLogger.error('_createNewDocument fallito', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    PerformanceLogger.stop('_createNewDocument');
  }

  String _getTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return 'pdf';
      case 'mxl': return 'mxl';
      case 'xml': return 'mxl';
      case 'abc': return 'abc';
      case 'mp3': return 'audio_mp3';
      case 'wav': return 'audio_wav';
      case 'mid': return 'mid';
      case 'kar': return 'kar';
      case 'jpg': return 'image';
      case 'jpeg': return 'image';
      case 'png': return 'image';
      case 'gif': return 'image';
      case 'svg': return 'image';
      case 'txt': return 'txt';
      default: return 'unknown';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📄 Documenti per: ${widget.songTitle}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _createNewDocument,
            tooltip: 'Nuovo documento per questo brano',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Documenti assegnati a questo evento
            Row(
              children: [
                const Text(
                  '📄 Documenti per questo evento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_assignedDocuments.length} documenti',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_assignedDocuments.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Nessun documento assegnato a questo evento per questo brano'),
                ),
              )
            else
              Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: _assignedDocuments.length,
                  itemBuilder: (context, index) {
                    final doc = _assignedDocuments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(doc['file_name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc['doc_type'] ?? ''),
                            if (doc['description'] != null && doc['description'].toString().isNotEmpty)
                              Text(
                                doc['description'],
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, color: Colors.blue),
                              onPressed: () => _viewDocument(doc),
                              tooltip: 'Visualizza',
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeDocument(doc),
                              tooltip: 'Rimuovi da questo evento',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const Divider(height: 32),

            // Documenti globali del brano disponibili
            Row(
              children: [
                const Text(
                  '📚 Documenti del brano (globali)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_availableDocuments.length} documenti',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: _availableDocuments.isEmpty
                  ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nessun documento globale disponibile per questo brano',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea un nuovo documento usando il pulsante +',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _availableDocuments.length,
                itemBuilder: (context, index) {
                  final doc = _availableDocuments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: const Icon(
                        Icons.insert_drive_file,
                        color: Colors.deepPurple,
                      ),
                      title: Text(doc.fileName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.docType),
                          if (doc.description.isNotEmpty)
                            Text(
                              doc.description,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, color: Colors.blue),
                            onPressed: () {
                              final docMap = {
                                'document_id': doc.id,
                                'file_name': doc.fileName,
                                'doc_type': doc.docType,
                                'file_path': doc.filePath,
                                'file_size': doc.fileSize,
                                'description': doc.description,
                                'is_public': doc.isPublic ? 1 : 0,
                              };
                              _viewDocument(docMap);
                            },
                            tooltip: 'Visualizza',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                            ),
                            onPressed: () => _addDocument(doc),
                            tooltip: 'Aggiungi a questo evento',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}