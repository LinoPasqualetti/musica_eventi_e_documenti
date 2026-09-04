// lib/utils/ui_performance.dart

import 'performance_logger.dart';

class UIPerformance {
  // 🔥 Log per il caricamento di una pagina
  static void pageLoad(String pageName) {
    PerformanceLogger.start('UI_PageLoad_$pageName');
    PerformanceLogger.info('UI_PageLoad', details: 'Caricamento $pageName');
  }

  static void pageLoadComplete(String pageName) {
    PerformanceLogger.stop('UI_PageLoad_$pageName');
    PerformanceLogger.info('UI_PageLoad', details: '$pageName caricata');
  }

  // 🔥 Log per il rendering di una lista
  static void listRender(String listName, int itemCount) {
    PerformanceLogger.info('UI_Render', details: '$listName: $itemCount items');
    if (itemCount > 100) {
      PerformanceLogger.warning('UI_Render_Large',
          details: '$listName ha $itemCount items - considerare paginazione');
    }
  }

  // 🔥 Log per il tempo di rendering di una pagina
  static void pageRender(String pageName, int elapsedMs) {
    if (elapsedMs > 500) {
      PerformanceLogger.warning('UI_Render_Slow',
          details: '$pageName: ${elapsedMs}ms - LENTO!');
    } else if (elapsedMs > 200) {
      PerformanceLogger.info('UI_Render_Medium',
          details: '$pageName: ${elapsedMs}ms');
    } else {
      PerformanceLogger.info('UI_Render_Fast',
          details: '$pageName: ${elapsedMs}ms');
    }
  }

  // 🔥 Log per le interazioni utente
  static void userAction(String action, {String? details}) {
    PerformanceLogger.info('UI_Action',
        details: '$action${details != null ? " - $details" : ""}');
  }

  // 🔥 Log per navigazione
  static void navigation(String fromScreen, String toScreen) {
    PerformanceLogger.info('UI_Navigation',
        details: '$fromScreen → $toScreen');
  }

  // 🔥 Log per refresh
  static void refresh(String screenName) {
    PerformanceLogger.info('UI_Refresh', details: 'Refresh $screenName');
    pageLoad(screenName);
  }

  // 🔥 Log per errori UI
  static void uiError(String screenName, String error) {
    PerformanceLogger.error('UI_Error', details: '$screenName: $error');
  }
}