// [MODIFICA] C:\musica_eventi_e_documenti\lib\screens\admin\admin_documents.dart

// lib/screens/admin/admin_documents.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/document.dart';
import '../../services/database_service.dart';
import '../../services/document_push_service.dart';
import '../../services/pending_uploads_service.dart';
import '../document_viewer_screen.dart';
import 'document_form_screen.dart';

class AdminDocuments extends StatefulWidget {
  const AdminDocuments({super.key});

  @override
  State<AdminDocuments> createState() => _AdminDocumentsState();
}

class _AdminDocumentsState extends State<AdminDocuments> {
  // ✅ RIUTILIZZA LA STESSA ISTANZA
  final DatabaseService _db = DatabaseService();

  List<Document> _documents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterType = 'tutti';

  /// Id dei documenti che non sono ancora stati sincronizzati al web.
  Set<String> _pendingIds = {};

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _loadPendingIds();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final docs = await _db.getAllDocuments();
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nel caricamento dei documenti: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadPendingIds() async {
    final pending = await PendingUploadsService.readAll();
    if (!mounted) return;
    setState(() {
      _pendingIds = pending
          .map((e) => e['documentId'] as String?)
          .whereType<String>()
          .toSet();
    });
  }

  List<Document> get _filteredDocuments {
    return _documents.where((doc) {
      if (_filterType != 'tutti' && doc.docType != _filterType) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return doc.fileName.toLowerCase().contains(query) ||
            doc.description.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  /// Riprova il push al web per tutti i documenti in pending.
  Future<void> _retryPendingUploads() async {
    final pending = await PendingUploadsService.readAll();
    if (pending.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessun documento in attesa')),
        );
      }
      return;
    }

    int ok = 0;
    for (final entry in pending) {
      final docId = entry['documentId'] as String?;
      if (docId == null) continue;

      // Trova il Document nel DB locale CON il content (BLOB).
      // _documents NON ha content (query senza BLOB per performance).
      // Serve una query dedicata che includa la colonna `content`.
      final doc = await _db.getDocumentByIdWithContent(docId);
      if (doc == null) {
        print('⚠️ Documento $docId non trovato nel DB locale, skip');
        continue;
      }
      if (doc.content == null || doc.content!.isEmpty) {
        print('⚠️ Documento $docId senza content, skip');
        continue;
      }

      final success = await DocumentPushService.pushDocument(doc);
      if (success) {
        await PendingUploadsService.remove(docId);
        ok++;
      }
    }

    await _loadPendingIds();
    await _loadDocuments();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Caricati $ok/${pending.length} documenti'),
          backgroundColor:
          ok == pending.length ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  void _deleteDocument(Document document) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Eliminare il documento "${document.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.deleteDocument(document.id);
        setState(() {
          _documents.removeWhere((d) => d.id == document.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento eliminato con successo'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editDocument(Document document) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentFormScreen(
          document: document,
        ),
      ),
    );
    if (result == true) {
      _loadDocuments();
    }
  }

  void _openDocument(Document document) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          document: document,
        ),
      ),
    );
    if (result == true) {
      _loadDocuments();
    }
  }

  void _addDocument() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentFormScreen(),
      ),
    );
    if (result == true) {
      _loadDocuments();
      _loadPendingIds();
    }
  }

  IconData _getTypeIcon(String docType) {
    switch (docType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'mxl':
      case 'abc':
        return Icons.music_note;
      case 'audio_mp3':
      case 'audio_wav':
        return Icons.audiotrack;
      case 'mid':
      case 'kar':
        return Icons.piano;
      case 'image':
        return Icons.image;
      case 'txt':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getTypeLabel(String docType) {
    switch (docType) {
      case 'pdf':
        return 'PDF';
      case 'mxl':
        return 'MusicXML';
      case 'abc':
        return 'ABC';
      case 'audio_mp3':
        return 'MP3';
      case 'audio_wav':
        return 'WAV';
      case 'mid':
        return 'MIDI';
      case 'kar':
        return 'Karaoke';
      case 'image':
        return 'Immagine';
      case 'txt':
        return 'Testo';
      default:
        return docType;
    }
  }

  Color _getTypeColor(String docType) {
    switch (docType) {
      case 'pdf':
        return Colors.red.shade700;
      case 'mxl':
      case 'abc':
        return Colors.deepPurple;
      case 'audio_mp3':
      case 'audio_wav':
        return Colors.green.shade700;
      case 'mid':
      case 'kar':
        return Colors.blue.shade700;
      case 'image':
        return Colors.orange.shade700;
      case 'txt':
        return Colors.grey.shade700;
      default:
        return Colors.grey;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _filterType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          setState(() {
            _filterType = value;
          });
        },
        selectedColor: Colors.deepPurple.shade100,
        checkmarkColor: Colors.deepPurple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Documenti'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // ─── Bottone "Ricarica mancanti" (visibile solo se ci sono pending) ───
          if (_pendingIds.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${_pendingIds.length}'),
                backgroundColor: Colors.orange,
                child: const Icon(Icons.cloud_upload),
              ),
              onPressed: _retryPendingUploads,
              tooltip:
              'Ricarica ${_pendingIds.length} documento/i non sincronizzato/i',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadDocuments();
              _loadPendingIds();
            },
            tooltip: 'Ricarica',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDocument,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        tooltip: 'Aggiungi documento',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Barra di ricerca e filtri
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Banner "documenti in attesa" (visibile solo se ci sono pending)
                if (_pendingIds.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade800),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_pendingIds.length} documento/i non ancora caricati sul web. '
                                'Premi l\'icona ☁️ in alto per riprovare.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cerca documenti...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('tutti', 'Tutti'),
                      _buildFilterChip('pdf', '📄 PDF'),
                      _buildFilterChip('mxl', '🎼 MXL'),
                      _buildFilterChip('abc', '🎵 ABC'),
                      _buildFilterChip('audio_mp3', '🎵 MP3'),
                      _buildFilterChip('audio_wav', '🎵 WAV'),
                      _buildFilterChip('mid', '🎹 MIDI'),
                      _buildFilterChip('kar', '🎤 KAR'),
                      _buildFilterChip('image', '🖼️ Immagine'),
                      _buildFilterChip('txt', '📝 Testo'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista documenti
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDocuments.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _documents.isEmpty
                        ? 'Nessun documento caricato'
                        : 'Nessun documento corrisponde ai filtri',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Premi + per aggiungere un documento',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _filteredDocuments.length,
              itemBuilder: (context, index) {
                final doc = _filteredDocuments[index];
                final isPending = _pendingIds.contains(doc.id);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    onTap: () => _openDocument(doc),
                    leading: CircleAvatar(
                      backgroundColor: _getTypeColor(doc.docType)
                          .withOpacity(0.2),
                      child: Icon(
                        _getTypeIcon(doc.docType),
                        color: _getTypeColor(doc.docType),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc.fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPending)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  size: 12,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'In attesa',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTypeLabel(doc.docType),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (doc.description.isNotEmpty)
                          Text(
                            doc.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editDocument(doc);
                        } else if (value == 'delete') {
                          _deleteDocument(doc);
                        } else if (value == 'retry') {
                          _retryPendingUploads();
                        }
                      },
                      itemBuilder: (context) => [
                        if (isPending)
                          const PopupMenuItem(
                            value: 'retry',
                            child: Row(
                              children: [
                                Icon(Icons.cloud_upload,
                                    size: 18,
                                    color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Riprova upload'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Modifica'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Elimina'),
                            ],
                          ),
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
    );
  }
}