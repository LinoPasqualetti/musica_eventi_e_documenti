// lib/services/notation_player_launcher.dart
import 'package:url_launcher/url_launcher.dart';

class NotationPlayerLauncher {
  static Future<void> openWithNotationPlayer(String filePath) async {
    try {
      // Crea URL per NotationPlayer
      // NotationPlayer supporta URI scheme: notationplayer://open?file=...
      final uri = Uri.parse(
          'notationplayer://open?file=${Uri.encodeComponent(filePath)}'
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // Fallback: apri con browser (se file è accessibile via web)
      final webUri = Uri.parse('https://notationplayer.com/abc?file=${Uri.encodeComponent(filePath)}');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri);
      }
    } catch (e) {
      print('❌ Errore apertura NotationPlayer: $e');
    }
  }
}