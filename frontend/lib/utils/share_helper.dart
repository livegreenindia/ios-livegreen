import 'dart:ui';
import 'package:share_plus/share_plus.dart';

/// Wrapper around share_plus that always supplies a valid [sharePositionOrigin].
///
/// On iPad, presenting the iOS share sheet (a popover) without a non-zero
/// source rect raises an NSException and crashes the app (SIGABRT). Since the
/// app is iPhone-only it still runs on iPad in compatibility mode, where Apple
/// reviews it — so every share must provide an origin. We anchor the popover
/// near the top-center of the screen, which is always a valid rect.
class ShareHelper {
  static Rect _origin() {
    final view = PlatformDispatcher.instance.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 3),
      width: 1,
      height: 1,
    );
  }

  static Future<void> shareText(String text, {String? subject}) {
    return Share.share(text, subject: subject, sharePositionOrigin: _origin());
  }

  static Future<void> shareFiles(
    List<XFile> files, {
    String? text,
    String? subject,
  }) {
    return Share.shareXFiles(
      files,
      text: text,
      subject: subject,
      sharePositionOrigin: _origin(),
    );
  }
}
