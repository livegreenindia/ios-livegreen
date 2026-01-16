import 'package:flutter/material.dart';

class MonitoredApp {
  final String packageName;
  final String name;
  final IconData icon;
  final Color color;

  const MonitoredApp({
    required this.packageName,
    required this.name,
    required this.icon,
    required this.color,
  });
}

const List<MonitoredApp> monitoredApps = [
  MonitoredApp(
    packageName: 'com.whatsapp',
    name: 'WhatsApp',
    icon: Icons.chat,
    color: Colors.green,
  ),
  MonitoredApp(
    packageName: 'com.instagram.android',
    name: 'Instagram',
    icon: Icons.camera_alt,
    color: Colors.pink,
  ),
  MonitoredApp(
    packageName: 'com.facebook.katana',
    name: 'Facebook',
    icon: Icons.thumb_up,
    color: Color(0xFF1565C0),
  ),
  MonitoredApp(
    packageName: 'com.google.android.youtube',
    name: 'YouTube',
    icon: Icons.play_circle,
    color: Colors.red,
  ),
  MonitoredApp(
    packageName: 'com.twitter.android',
    name: 'Twitter',
    icon: Icons.alternate_email,
    color: Colors.blue,
  ),
  MonitoredApp(
    packageName: 'com.snapchat.android',
    name: 'Snapchat',
    icon: Icons.camera,
    color: Color(0xFFFBC02D),
  ),
];

Set<String> monitoredPackageNames() =>
    monitoredApps.map((e) => e.packageName).toSet();
