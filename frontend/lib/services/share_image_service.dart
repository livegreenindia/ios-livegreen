import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareImageService {
  /// Captures the widget encapsulated by the [GlobalKey] as an image and shares it.
  static Future<void> captureAndShare({
    required GlobalKey boundaryKey,
    required String subject,
    required String text,
  }) async {
    try {
      // Find the render object
      RenderRepaintBoundary? boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        debugPrint("Error: Could not find RenderRepaintBoundary.");
        return;
      }

      // Convert to image
      // Note: Use a high pixelRatio (e.g. 5.0) to ensure the image text and overlays
      // don't get blurry when captured from a scaled-down widget in a dialog constraint. 
      ui.Image image = await boundary.toImage(pixelRatio: 5.0);
      
      // Convert to byte data
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final buffer = byteData.buffer;
        
        // Save to temporary directory
        final tempDir = await getTemporaryDirectory();
        
        // Create unique timestamped file name
        final fileName = 'trek_share_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = await File('${tempDir.path}/$fileName').create();
        
        await file.writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        
        // Share via system share sheet
        await Share.shareXFiles(
          [XFile(file.path)], 
          subject: subject, 
          text: text
        );
      }
    } catch (e) {
      debugPrint("Error capturing and sharing image: $e");
      // Fallback: Just share the text if image generation fails
      await Share.share(text, subject: subject);
    }
  }
}
