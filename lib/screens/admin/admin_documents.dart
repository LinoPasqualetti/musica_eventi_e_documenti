// lib/screens/admin/admin_documents.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/document.dart';
import '../../services/database_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDocuments();
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

  void _addDocument() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentFormScreen(
          document: null,
        ),
      ),
    );
    if (result == true) {
      _loadDocuments();
    }
  }

  void _viewDocument(Document document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          document: document,
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'pdf':
        return '📄 PDF';
      case 'mxl':
        return '🎼 MXL';
      case 'abc':
        return '🎵 ABC';
      case 'audio_mp3':
        return '🎵 MP3';
      case 'audio_wav':
        return '🎵 WAV';
      case 'mid':
        return '🎹 MIDI';
      case 'kar':
        return '🎤 KAR';
      case 'image':
        return '🖼️ Immagine';
      case 'txt':
        return '📝 Testo';
      default:
        return type;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
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

  Color _getTypeColor(String type) {
    switch (type) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Documenti'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
            tooltip: 'Ricarica',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra di ricerca e filtri
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getTypeColor(doc.docType)
                          .withOpacity(0.2),
                      child: Icon(
                        _getTypeIcon(doc.docType),
                        color: _getTypeColor(doc.docType),
                      ),
                    ),
                    title: Text(
                      doc.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
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
                        Text(
                          '${_formatFileSize(doc.fileSize ?? 0)} • ${doc.isPublic ? "Pubblico" : "Privato"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility,
                              color: Colors.blue),
                          onPressed: () => _viewDocument(doc),
                          tooltip: 'Visualizza',
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.orange),
                          onPressed: () => _editDocument(doc),
                          tooltip: 'Modifica',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          onPressed: () => _deleteDocument(doc),
                          tooltip: 'Elimina',
                        ),
                      ],
                    ),
                    onTap: () => _viewDocument(doc),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDocument,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Aggiungi documento',
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        label: Text(label),
        selected: _filterType == value,
        onSelected: (selected) {
          setState(() {
            _filterType = selected ? value : 'tutti';
          });
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.deepPurple.shade100,
        checkmarkColor: Colors.deepPurple,
        labelStyle: TextStyle(
          color: _filterType == value ? Colors.deepPurple : Colors.grey.shade700,
          fontWeight: _filterType == value ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}