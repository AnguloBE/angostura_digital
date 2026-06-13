import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Android → Google. iOS/macOS → Apple.
class AuthPlataforma {
  AuthPlataforma._();

  static bool get usaGoogle {
    if (kIsWeb) return true;
    return Platform.isAndroid;
  }

  static bool get usaApple {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

}
