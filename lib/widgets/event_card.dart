// lib/widgets/event_card.dart
import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../services/database_service.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCard({
    Key? key,
    required this.event,
    required this.onTap,
  }) : super(key: key);

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  final DatabaseService _db = DatabaseService();
  int _registrationsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistrationsCount();
  }

  Future<void> _loadRegistrationsCount() async {
    try {
      final count = await _db.countRegistrationsByEvent(widget.event.id);
      setState(() {
        _registrationsCount = count;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Errore count: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.event.imageUrl != null && widget.event.imageUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ IMMAGINE A SINISTRA
            SizedBox(
              width: 120,
              height: 120,
              child: hasImage
                  ? Image.network(
                widget.event.imageUrl!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    color: Colors.deepPurple.shade100,
                    child: const Icon(
                      Icons.music_note,
                      size: 40,
                      color: Colors.deepPurple,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 120,
                    height: 120,
                    color: Colors.deepPurple.shade50,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              )
                  : Container(
                width: 120,
                height: 120,
                color: Colors.deepPurple.shade100,
                child: const Icon(
                  Icons.music_note,
                  size: 40,
                  color: Colors.deepPurple,
                ),
              ),
            ),

            // ✅ DESCRIZIONE A DESTRA
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Titolo e tema
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.event.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Tema
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple.shade200),
                      ),
                      child: Text(
                        widget.event.theme,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Data e luogo (riga compatta)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          widget.event.date.toString(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.event.location,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Descrizione sintetica (una riga)
                    if (widget.event.description != null)
                      Text(
                        widget.event.description!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 8),

                    // Partecipanti
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 14,
                          color: Colors.deepPurple.shade300,
                        ),
                        const SizedBox(width: 4),
                        if (_isLoading)
                          const SizedBox(
                            height: 12,
                            width: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            '$_registrationsCount partecipanti',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.deepPurple.shade300,
                            ),
                          ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}