// lib/data/default_organ_templates.dart
import '../models/organ_slot.dart';

/// Template di organico predefiniti (ispirati a Finale).
/// Ogni entry contiene:
///   - name: nome del template
///   - category: categoria per raggruppamento
///   - description: descrizione breve
///   - slots: lista di slot (sezione + strumento + quantità)
class DefaultOrganTemplate {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<DefaultOrganTemplateSlot> slots;

  const DefaultOrganTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.slots,
  });
}

class DefaultOrganTemplateSlot {
  final OrganSection section;
  final String instrument;
  final int quantity;

  const DefaultOrganTemplateSlot({
    required this.section,
    required this.instrument,
    this.quantity = 1,
  });
}

/// 8 template predefiniti, adattati alla struttura a 4 sezioni.
const List<DefaultOrganTemplate> kDefaultOrganTemplates = [
  // ─────────────────────────────────────────────────────────────
  // JAZZ
  // ─────────────────────────────────────────────────────────────
  DefaultOrganTemplate(
    id: 'tpl_jazz_trio',
    name: 'Jazz Trio',
    category: 'Jazz',
    description: 'Pianoforte, basso, batteria',
    slots: [
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Pianoforte',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Basso',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Batteria',
          quantity: 1),
    ],
  ),

  DefaultOrganTemplate(
    id: 'tpl_jazz_quartet',
    name: 'Jazz Quartet',
    category: 'Jazz',
    description: 'Trio + sax tenore solista',
    slots: [
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Pianoforte',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Basso',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Batteria',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.solistica,
          instrument: 'Sax tenore',
          quantity: 1),
    ],
  ),

  DefaultOrganTemplate(
    id: 'tpl_big_band',
    name: 'Big Band Standard',
    category: 'Jazz',
    description: '5 sax, 8 ottoni, sezione ritmica',
    slots: [
      // Ritmica
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Pianoforte',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Chitarra',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Basso',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Batteria',
          quantity: 1),
      // Solistica (sax)
      DefaultOrganTemplateSlot(
          section: OrganSection.solistica,
          instrument: 'Sax contralto',
          quantity: 2),
      DefaultOrganTemplateSlot(
          section: OrganSection.solistica,
          instrument: 'Sax tenore',
          quantity: 2),
      DefaultOrganTemplateSlot(
          section: OrganSection.solistica,
          instrument: 'Sax baritono',
          quantity: 1),
      // Armonica (ottoni)
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Tromba in Bb',
          quantity: 4),
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Trombone',
          quantity: 4),
    ],
  ),

  // ─────────────────────────────────────────────────────────────
  // MUSICA DA CAMERA
  // ─────────────────────────────────────────────────────────────
  DefaultOrganTemplate(
    id: 'tpl_string_quartet',
    name: 'Quartetto d\'Archi',
    category: 'Musica da Camera',
    description: 'Due violini, viola, violoncello',
    slots: [
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Violino I',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Violino II',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Viola',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Violoncello',
          quantity: 1),
    ],
  ),

  DefaultOrganTemplate(
    id: 'tpl_wind_quintet',
    name: 'Quintetto di Fiati',
    category: 'Musica da Camera',
    description: 'Flauto, oboe, clarinetto, fagotto, corno',
    slots: [
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Flauto',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Oboe',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Clarinetto',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Fagotto',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Corno',
          quantity: 1),
    ],
  ),

  // ─────────────────────────────────────────────────────────────
  // ORCHESTRA
  // ─────────────────────────────────────────────────────────────
  DefaultOrganTemplate(
    id: 'tpl_string_orchestra',
    name: 'Orchestra d\'Archi',
    category: 'Orchestra',
    description: 'Soli archi: 5 Vn I, 4 Vn II, 3 Va, 3 Vc, 2 Cb',
    slots: [
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Violino I',
          quantity: 5),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Violino II',
          quantity: 4),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Viola',
          quantity: 3),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Violoncello',
          quantity: 3),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Contrabbasso',
          quantity: 2),
    ],
  ),

  DefaultOrganTemplate(
    id: 'tpl_symphony_small',
    name: 'Grande Orchestra (ridotta)',
    category: 'Orchestra',
    description: 'Organico sinfonico base: 2 fiati per famiglia, ottoni, percussioni, archi',
    slots: [
      // Fiati (armonica)
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Flauto',
          quantity: 2),
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Oboe',
          quantity: 2),
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Clarinetto',
          quantity: 2),
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Fagotto',
          quantity: 2),
      // Ottoni (armonica)
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Corno',
          quantity: 4),
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Tromba in Bb',
          quantity: 2),
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Trombone',
          quantity: 3),
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Tuba',
          quantity: 1),
      // Percussioni (ritmica)
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Timpani',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.ritmica,
          instrument: 'Percussioni',
          quantity: 2),
      // Archi (orchestrale)
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Violino I',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Violino II',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Viola',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Violoncello',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.orchestrale,
          instrument: 'Contrabbasso',
          quantity: 1),
    ],
  ),

  // ─────────────────────────────────────────────────────────────
  // CORO
  // ─────────────────────────────────────────────────────────────
  DefaultOrganTemplate(
    id: 'tpl_choir_satb_piano',
    name: 'Coro SATB con Pianoforte',
    category: 'Coro',
    description: 'Soprano, contralto, tenore, basso + pianoforte',
    slots: [
      DefaultOrganTemplateSlot(
          section: OrganSection.armonica,
          instrument: 'Pianoforte',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.solistica,
          instrument: 'Soprano',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.solistica,
          instrument: 'Contralto',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.solistica,
          instrument: 'Tenore',
          quantity: 1),
      DefaultOrganTemplateSlot(
          section: OrganSection.solistica,
          instrument: 'Basso',
          quantity: 1),
    ],
  ),
];
