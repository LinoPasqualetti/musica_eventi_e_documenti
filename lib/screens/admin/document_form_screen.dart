// lib/screens/admin/document_form_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/document.dart';
import '../../services/database_service.dart';
import '../../services/document_storage_policy.dart';
import '../../utils/performance_logger.dart';

class DocumentFormScreen extends StatefulWidget {
  final Document? document;
  //final String? songId;

  const DocumentFormScreen({
    Key? key,
    this.document,
    //this.songId,
  }) : super(key: key);

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  String? _selectedType;
  String? _selectedFilePath;
  String? _fileName;
  int _fileSize = 0;
  bool _isPublic = true;
  bool _isLoading = false;
  Uint8List? _fileBytes;

  final List<String> _documentTypes = [
    'pdf',
    'mxl',
    'abc',
    'audio_mp3',
    'audio_wav',
    'mid',
    'kar',
    'image',
    'txt',
  ];

  @override
  void initState() {
    super.initState();
    PerformanceLogger.info('DocumentFormScreen inizializzato');

    if (widget.document != null) {
      _titleController.text = widget.document!.fileName;
      _descriptionController.text = widget.document!.description;
      _selectedType = widget.document!.docType;
      _selectedFilePath = widget.document!.filePath;
      _fileName = widget.document!.fileName;
      _fileSize = widget.document!.fileSize ?? 0;
      _isPublic = widget.document!.isPublic;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    PerformanceLogger.start('_pickFile');

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: _selectedType != null && _selectedType!.isNotEmpty
            ? FileType.custom
            : FileType.any,
        allowedExtensions: _selectedType != null
            ? _getAllowedExtensions()
            : null,
        withData: false,   // 🔥 non caricare in memoria subito
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final path = file.path;
        final name = file.name;
        final size = file.size;

        setState(() {
          _selectedFilePath = path;
          _fileName = name;
          _fileSize = size;
          if (bytes != null) {
            _fileBytes = bytes;
          }
          if (_titleController.text.isEmpty) {
            _titleController.text = name;
          }
          if (_selectedType == null || _selectedType!.isEmpty) {
            final extension = name.split('.').last.toLowerCase();
            _selectedType = _getTypeFromExtension(extension) ?? 'unknown';
          }
        });

        PerformanceLogger.info('File selezionato',
            details: '$name (${_formatFileSize(size)})');
      }
    } catch (e) {
      PerformanceLogger.error('_pickFile fallito', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nella selezione del file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    PerformanceLogger.stop('_pickFile');
  }

  List<String> _getAllowedExtensions() {
    switch (_selectedType) {
      case 'pdf':
        return ['pdf'];
      case 'mxl':
        return ['mxl', 'xml'];
      case 'abc':
        return ['abc'];
      case 'audio_mp3':
        return ['mp3'];
      case 'audio_wav':
        return ['wav'];
      case 'mid':
        return ['mid'];
      case 'kar':
        return ['kar'];
      case 'image':
        return ['jpg', 'jpeg', 'png', 'gif', 'svg'];
      case 'txt':
        return ['txt'];
      default:
        return [];
    }
  }

  String _getTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'mxl':
      case 'xml':
        return 'mxl';
      case 'abc':
        return 'abc';
      case 'mp3':
        return 'audio_mp3';
      case 'wav':
        return 'audio_wav';
      case 'mid':
        return 'mid';
      case 'kar':
        return 'kar';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'svg':
        return 'image';
      case 'txt':
        return 'txt';
      default:
        return 'unknown';
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'pdf':
        return '📄 PDF';
      case 'mxl':
        return '🎼 MusicXML';
      case 'abc':
        return '🎵 ABC Notation';
      case 'audio_mp3':
        return '🎵 Audio MP3';
      case 'audio_wav':
        return '🎵 Audio WAV';
      case 'mid':
        return '🎹 MIDI';
      case 'kar':
        return '🎤 Karaoke';
      case 'image':
        return '🖼️ Immagine';
      case 'txt':
        return '📝 Testo';
      default:
        return type;
    }
  }

  void _saveDocument() async {
    PerformanceLogger.start('_saveDocument');

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFilePath == null || _selectedFilePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona un file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final docType = _selectedType ?? 'unknown';
      final fileName = _fileName ?? _titleController.text;
      final filePath = _selectedFilePath!;

      // 🔥 DECISIONE CENTRALIZZATA blob vs filesystem
      String storageMode = DocumentStoragePolicy.decide(
        filePath: filePath,
        fileSize: _fileSize,
      );

      Uint8List? content;
      if (storageMode == 'blob') {
        try {
          if (_fileBytes != null) {
            content = _fileBytes;
          } else {
            final file = File(filePath);
            if (await file.exists()) {
              content = await file.readAsBytes();
            } else {
              // File non trovato: fallback a filesystem, non blob-are
              storageMode = 'filesystem';
            }
          }
        } catch (e) {
          print('❌ Errore lettura BLOB: $e');
          storageMode = 'filesystem';
          content = null;
        }
      }

      final document = Document(
        id: widget.document?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        docType: docType,
        fileName: fileName,
        filePath: filePath,
        fileSize: _fileSize,
        description: _descriptionController.text,
        isPublic: _isPublic,
        uploadedBy: 'admin',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: null,
        content: content,
        storageMode: storageMode,
        //songId: widget.songId,
      );

      if (widget.document == null) {
              // --- CHECK DUPLICATI ---
      final duplicate = await _db.findDuplicateDocument(document);

      if (duplicate != null) {
        final choice = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Possibile duplicato'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Esiste gia un documento con lo stesso nome e tipo:'),
                const SizedBox(height: 8),
                Text('Nome: ${duplicate.fileName}'),
                Text('ID: ${duplicate.id}'),
                Text('Creato: ${duplicate.createdAt}'),
                const SizedBox(height: 12),
                const Text('Cosa vuoi fare?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Annulla'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'new'),
                child: const Text('Salva come nuovo'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'merge'),
                child: const Text('Unisci'),
              ),
            ],
          ),
        );

        if (choice == null || choice == 'cancel') return;

        if (choice == 'merge') {
          final keepExisting = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Unisci documenti'),
              content: const Text(
                'Quale documento vuoi mantenere?\n\n'
                '- Tieni esistente: mantiene l ID corrente, aggiorna il contenuto col nuovo\n'
                '- Tieni nuovo: mantiene il nuovo ID, sposta le relazioni del vecchio',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Tieni esistente'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Tieni nuovo'),
                ),
              ],
            ),
          );

          if (keepExisting == null) return;

          await _db.mergeDocument(
            existingId: duplicate.id,
            newDoc: document,
            keepExisting: keepExisting,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documenti uniti con successo'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
          return;
        }
      }

await _db.insertDocument(document);
        PerformanceLogger.info('Documento creato',
            details: '${document.fileName} ($storageMode)');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento aggiunto con successo'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _db.updateDocument(document);
        PerformanceLogger.info('Documento aggiornato',
            details: '${document.fileName} ($storageMode)');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento aggiornato con successo'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      PerformanceLogger.error('_saveDocument fallito', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    PerformanceLogger.stop('_saveDocument');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document == null
            ? 'Nuovo Documento'
            : 'Modifica Documento'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo documento',
                    border: OutlineInputBorder(),
                  ),
                  items: _documentTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                      _selectedFilePath = null;
                      _fileName = null;
                      _fileSize = 0;
                      _fileBytes = null;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Seleziona un tipo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Nome file',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci un nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _fileName != null
                                  ? '📎 $_fileName (${_formatFileSize(_fileSize)})'
                                  : 'Nessun file selezionato',
                              style: TextStyle(
                                color: _fileName != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_open),
                            onPressed: _pickFile,
                            tooltip: 'Seleziona file',
                            color: Colors.deepPurple,
                          ),
                        ],
                      ),
                      if (_selectedFilePath != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '📂 ${_selectedFilePath!.replaceAll('\\', '/')}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedType != null &&
                    ['mxl', 'abc', 'mid', 'kar'].contains(_selectedType))
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '💾 I file piccoli (< 1 MB) verranno salvati come BLOB nel DB; '
                                'i file grandi resteranno sul filesystem.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Documento pubblico'),
                  subtitle: Text(
                    _isPublic
                        ? 'Visibile a tutti gli utenti'
                        : 'Visibile solo agli amministratori',
                  ),
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                  activeColor: Colors.deepPurple,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveDocument,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          widget.document == null ? 'Aggiungi' : 'Aggiorna',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}