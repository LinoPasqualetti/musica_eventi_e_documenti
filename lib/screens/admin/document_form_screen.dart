// lib/screens/admin/document_form_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/document.dart';
import '../../services/database_service.dart';

class DocumentFormScreen extends StatefulWidget {
  final Document? document;
  final String? songId;

  const DocumentFormScreen({
    super.key,
    this.document,
    this.songId,
  });

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedType;
  String? _selectedFilePath;
  String? _fileName;
  int _fileSize = 0;
  bool _isPublic = true;
  bool _isLoading = false;

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
    if (widget.document != null) {
      _titleController.text = widget.document!.fileName;
      _descriptionController.text = widget.document!.description;
      _selectedType = widget.document!.docType;
      _selectedFilePath = widget.document!.filePath;
      _fileName = widget.document!.fileName;
      _fileSize = widget.document!.fileSize;
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
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: _getAllowedExtensions(),
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFilePath = file.path;
          _fileName = file.name;
          _fileSize = file.size;
          if (_titleController.text.isEmpty) {
            _titleController.text = file.name;
          }
          // Auto-detect type from extension
          if (_selectedType == null || _selectedType!.isEmpty) {
            final extension = file.name.split('.').last.toLowerCase();
            _selectedType = _getTypeFromExtension(extension);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nella selezione del file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  String? _getTypeFromExtension(String extension) {
    switch (extension) {
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
        return null;
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
      final document = Document(
        id: widget.document?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        docType: _selectedType ?? 'unknown',
        fileName: _fileName ?? _titleController.text,
        filePath: _selectedFilePath!,
        fileSize: _fileSize,
        description: _descriptionController.text,
        isPublic: _isPublic,
        uploadedBy: 'admin',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: null,
      );

      // Usa l'istanza di DatabaseService
      final db = DatabaseService();

      if (widget.document == null) {
        await db.insertDocument(document);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento aggiunto con successo'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await db.updateDocument(document);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento aggiornato con successo'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document == null ? 'Nuovo Documento' : 'Modifica Documento'),
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
                // Tipo documento
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

                // Nome file
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

                // Descrizione
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Selezione file
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
                                color: _fileName != null ? Colors.black : Colors.grey,
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
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pubblico
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

                // Pulsanti
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                        child: Text(widget.document == null ? 'Aggiungi' : 'Aggiorna'),
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
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}