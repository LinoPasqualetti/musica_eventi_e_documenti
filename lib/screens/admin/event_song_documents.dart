// lib/screens/admin/event_song_documents.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/database_service.dart';
import '../../models/event_model.dart';
import '../../models/document.dart';
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Carica i documenti già assegnati a questo evento-brano
      final assigned = await _db.getEventSongDocumentsWithDetails(widget.eventSongId);

      // 2. Carica SOLO i documenti globali di questa canzone (non assegnati all'evento)
      final songDocuments = await _db.getDocumentsBySong(widget.songId);

      // 3. Filtra i documenti già assegnati
      final assignedIds = assigned.map((d) => d['document_id'] as String).toSet();
      final available = songDocuments.where((d) => !assignedIds.contains(d.id)).toList();

      setState(() {
        _assignedDocuments = assigned;
        _availableDocuments = available;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ METODO CORRETTO: accetta un parametro Document
  Future<void> _addDocument(Document doc) async {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeDocument(Map<String, dynamic> doc) async {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewDocument(Map<String, dynamic> doc) {
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
  }

  // ✅ METODO CORRETTO per creare un nuovo documento
  Future<void> _createNewDocument() async {
    try {
      final dynamic result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'mxl', 'abc', 'mp3', 'wav', 'mid', 'kar', 'jpg', 'png', 'txt'],
      );

      if (result == null) return;

      // Approccio più semplice
      dynamic file;
      if (result is List && result.isNotEmpty) {
        file = result.first;
      } else if (result.files != null && result.files.isNotEmpty) {
        file = result.files.first;
      } else {
        file = result;
      }

      if (file == null) return;

      final String? filePath = file.path;
      final String? fileName = file.name;
      final int fileSize = file.size ?? 0;

      if (filePath == null || fileName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore: percorso file non valido'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ... continua con il resto del codice
    } catch (e) {
      // ...
    }
  }

  String _getTypeFromExtension(String extension) {
    switch (extension) {
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
                              // Visualizza il documento
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
                            onPressed: () => _addDocument(doc), // ✅ Ora passa il documento
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