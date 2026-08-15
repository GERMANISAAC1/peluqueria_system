import 'package:flutter/services.dart';

/// Puente entre Flutter y el módulo nativo Android (MainActivity.kt / BlockerService.kt).
/// Todo lo relacionado con permisos especiales y el bloqueo real de apps pasa por aquí.
class BlockerChannel {
  static const _channel = MethodChannel('focusmind/blocker');

  static Future<bool> hasUsageAccess() async {
    final result = await _channel.invokeMethod<bool>('hasUsageAccess');
    return result ?? false;
  }

  static Future<bool> hasOverlayPermission() async {
    final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
    return result ?? false;
  }

  static Future<void> requestUsageAccess() =>
      _channel.invokeMethod('requestUsageAccess');

  static Future<void> requestOverlayPermission() =>
      _channel.invokeMethod('requestOverlayPermission');

  /// Devuelve [{packageName, label}, ...] de todas las apps con ícono en el launcher.
  static Future<List<InstalledApp>> getInstalledApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    if (result == null) return [];
    return result
        .map((e) => InstalledApp(
              packageName: (e as Map)['packageName'] as String,
              label: e['label'] as String,
            ))
        .toList();
  }

  static Future<bool> startBlocking(List<String> packages) async {
    final result = await _channel.invokeMethod<bool>('startBlocking', {
      'packages': packages,
    });
    return result ?? false;
  }

  static Future<bool> stopBlocking() async {
    final result = await _channel.invokeMethod<bool>('stopBlocking');
    return result ?? false;
  }
}

class InstalledApp {
  final String packageName;
  final String label;
  InstalledApp({required this.packageName, required this.label});
}

/// Categorías predefinidas con paquetes comunes en Latinoamérica.
/// El usuario puede además agregar cualquier app manualmente desde su lista de instaladas.
class AppCategories {
  static const Map<String, List<String>> presets = {
    'Redes sociales': [
      'com.instagram.android',
      'com.zhiliaoapp.musically', // TikTok
      'com.facebook.katana',
      'com.twitter.android',
      'com.snapchat.android',
      'com.reddit.frontpage',
      'com.pinterest',
    ],
    'Video / streaming': [
      'com.google.android.youtube',
      'com.netflix.mediaclient',
      'tv.twitch.android.app',
      'com.disney.disneyplus',
    ],
    'Mensajería (no urgente)': [
      'com.whatsapp',
      'org.telegram.messenger',
      'com.discord',
    ],
    'Juegos': [
      'com.supercell.clashofclans',
      'com.king.candycrushsaga',
      'com.mojang.minecraftpe',
      'com.roblox.client',
    ],
  };
}
