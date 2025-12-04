import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/wearable_integration_service.dart';
import '../integrations/smartkit_stub.dart';

/// Small debug/admin screen to store Fitbit OAuth credentials into secure storage.
/// Use this only for development/testing. Do NOT commit secrets into source control.
class WearableAdminScreen extends StatefulWidget {
  const WearableAdminScreen({super.key});

  @override
  State<WearableAdminScreen> createState() => _WearableAdminScreenState();
}

class _WearableAdminScreenState extends State<WearableAdminScreen> {
  final _clientIdController = TextEditingController();
  final _redirectController = TextEditingController(text: 'livegreen://auth');
  final _backendController = TextEditingController();
  static const String _defaultBackendBase = 'https://us-central1-livegreen-bf838.cloudfunctions.net/api';
  final _formKey = GlobalKey<FormState>();
  final _service = WearableIntegrationService();
  bool _saving = false;
  bool _testing = false;
  Map<String, dynamic>? _testResult;
  DateTime? _lastSync;
  Timer? _expiryTimer;
  String? _accessExpiresAt;
  bool _debugging = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await _service.readFitbitCredentials();
  if (cfg['client_id'] != null) _clientIdController.text = cfg['client_id']!;
    if (cfg['redirect_uri'] != null) _redirectController.text = cfg['redirect_uri']!;
  // backend API base (optional) - e.g. https://us-central1-<project>.cloudfunctions.net/api
  final backend = await _service.readBackendBase();
  // If backend isn't stored yet, pre-fill with the known deployed functions URL
  if (backend != null && backend.trim().isNotEmpty) {
      _backendController.text = backend;
  } else {
      _backendController.text = _defaultBackendBase;
      // persist the default backend so flows that read secure storage will find it
      try {
        await _service.saveBackendBase(_defaultBackendBase);
      } catch (_) {}
  }
    // load connection/test status and last sync
    await _loadTestAndExpiry();
    await _loadLastSync();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadTestAndExpiry() async {
    try {
      final res = await _service.testConnection();
      if (!mounted) return;
      setState(() { _testResult = res; _accessExpiresAt = res['access_expires_at'] as String?; });
      _startExpiryTimer();
    } catch (_) {}
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    if (_accessExpiresAt == null) return;
    _expiryTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final now = DateTime.now().toUtc();
      try {
        final exp = DateTime.parse(_accessExpiresAt!).toUtc();
        if (mounted) setState(() {});
        if (exp.difference(now).inSeconds <= 0) {
          await _loadTestAndExpiry();
        }
      } catch (_) {}
    });
  }

  Future<void> _loadLastSync() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['last_sync'] != null) {
          final ts = data['last_sync'];
          DateTime dt;
          if (ts is Timestamp) dt = ts.toDate(); else dt = DateTime.parse(ts.toString());
          if (!mounted) return;
          setState(() { _lastSync = dt.toLocal(); });
        }
      }
    } catch (_) {}
  }

  Widget _statusIcon(bool ok) => Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.orange, size: 18);

  String _formatExpiry(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat.yMd().add_jm().format(dt);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      // Do not persist client_secret from the Admin UI. Server MUST be used
      // to store confidential values. We save only client_id and redirect_uri.
      await _service.saveFitbitCredentials(
        clientId: _clientIdController.text.trim(),
        clientSecret: '',
        redirectUri: _redirectController.text.trim(),
      );
      // also save backend base if provided
      if (_backendController.text.trim().isNotEmpty) {
        await _service.saveBackendBase(_backendController.text.trim());
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitbit credentials saved (secure storage).')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving credentials: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _validate() async {
    final cfg = await _service.readFitbitCredentials();
    final backend = await _service.readBackendBase();
    final clientId = cfg['client_id'];
    final clientSecret = cfg['client_secret'];
    final redirect = cfg['redirect_uri'];

    final missing = <String>[];
    if (clientId == null || clientId.trim().isEmpty) missing.add('Client ID');
    if (redirect == null || redirect.trim().isEmpty) missing.add('Redirect URI');

    final content = StringBuffer();
    if (missing.isEmpty) {
      content.writeln('Fitbit credentials appear configured.');
    } else {
      content.writeln('Missing: ${missing.join(', ')}');
    }
    content.writeln('\nStored values (masked where appropriate):');
    content.writeln('Client ID: ${clientId ?? '<not set>'}');
    final clientSecretDisplay = kReleaseMode
      ? '<server-managed - not stored on device>'
      : (clientSecret != null && clientSecret.isNotEmpty ? '<set (hidden)>' : '<not set - PKCE mode>');
    content.writeln('Client Secret: $clientSecretDisplay');
    content.writeln('Redirect URI: ${redirect ?? '<not set>'}');
    content.writeln('Backend API base: ${backend ?? '<not set>'}');

    // Offer simple checks for redirect URI format
    if (redirect != null && redirect.contains('://')) {
      final scheme = redirect.split('://').first;
      content.writeln('\nRedirect scheme: $scheme');
      content.writeln('Ensure this scheme is registered in AndroidManifest and matches the Fitbit app redirect URI.');
    } else if (redirect != null) {
      content.writeln('\nRedirect URI looks unusual; expected a custom-scheme like livegreen://auth');
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fitbit configuration'),
        content: SingleChildScrollView(child: Text(content.toString())),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wearable Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter Fitbit OAuth configuration (development only).', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              // If a backend is configured, client_id/client_secret are managed server-side.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _backendController,
                builder: (ctx, val, child) {
                  final hasBackend = val.text.trim().isNotEmpty;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _clientIdController,
                        decoration: InputDecoration(labelText: 'Fitbit Client ID', helperText: hasBackend ? 'Managed by backend when Backend API base is set' : null),
                        validator: (v) => hasBackend ? null : (v == null || v.trim().isEmpty) ? 'Required' : null,
                        enabled: !hasBackend,
                      ),
                      const SizedBox(height: 8),
                      // Client secret is not accepted via this Admin UI. Secrets must be
                      // configured on the server (Cloud Functions) to avoid storing
                      // confidential values on user devices.
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: const Text(
                          'Client secret must be configured on the server (Cloud Functions).\nDo not store client secrets on devices.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _backendController,
                decoration: const InputDecoration(labelText: 'Backend API base (optional)'),
                validator: (v) => null,
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              TextFormField(
                controller: _redirectController,
                decoration: const InputDecoration(labelText: 'Redirect URI (custom scheme)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Credentials'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _validate,
                child: const Text('Validate config'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _testing ? null : () async {
                  setState(() => _testing = true);
                  try {
                    final widget = await _service.testConnection();
                    if (!mounted) return;
                    setState(() { _testResult = widget; _accessExpiresAt = widget['access_expires_at'] as String?; });
                    final buf = StringBuffer();
                    buf.writeln('Backend: ${widget['backend_base'] ?? '<not set>'}');
                    buf.writeln('Backend reachable: ${widget['backend_ok'] == true ? 'Yes' : 'No'}');
                    buf.writeln('Client ID: ${widget['client_id'] ?? '<not set>'}');
                    buf.writeln('Redirect URI: ${widget['redirect_uri'] ?? '<not set>'}');
                    buf.writeln('Has access token: ${widget['has_access_token'] == true ? 'Yes' : 'No'}');
                    if (widget['access_expires_at'] != null) buf.writeln('Access expires at: ${widget['access_expires_at']}');
                    if (!mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Connection Test'),
                        content: SingleChildScrollView(child: Text(buf.toString())),
                        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
                      ),
                    );
                    if (mounted) _startExpiryTimer();
                  } finally {
                    if (mounted) setState(() => _testing = false);
                  }
                },
                child: _testing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Test Connection'),
              ),
              const SizedBox(height: 8),
              // View SmartKit Dashboard (Coming Soon)
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('SmartKit integration coming soon! Wearable dashboard will be available after SDK integration.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.watch),
                label: const Text('View Wearable Dashboard (Coming Soon)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              // Manual sync now button (admin convenience)
              ElevatedButton.icon(
                onPressed: _saving ? null : () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to sync wearables')));
                    return;
                  }
                    if (!mounted) return;
                    setState(() => _saving = true);
                  try {
                    await _service.startFullSync(user.uid);
                    await _loadLastSync();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync started (check progress screen)')));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                  } finally {
                      if (mounted) setState(() => _saving = false);
                  }
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sync Now'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              const SizedBox(height: 8),
              // Debug: run full sync and show detailed error/stack in a dialog
              ElevatedButton.icon(
                onPressed: _debugging ? null : () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to run debug sync')));
                    return;
                  }
                  if (!mounted) return;
                  setState(() => _debugging = true);
                  try {
                    final res = await _service.debugRunFullSync(user.uid);
                    // print to console and show dialog
                    debugPrint('debugRunFullSync result: $res');
                    if (!mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Debug Sync Result'),
                        content: SingleChildScrollView(child: Text(res.toString())),
                        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
                      ),
                    );
                    await _loadLastSync();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debug sync error: $e')));
                  } finally {
                    if (mounted) setState(() => _debugging = false);
                  }
                },
                icon: const Icon(Icons.bug_report),
                label: const Text('Run Debug Sync'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              ElevatedButton(
                onPressed: () async {
                  // convenience: paste clipboard into client id if empty
                  final clip = await Clipboard.getData('text/plain');
                  if (clip != null && clip.text != null) {
                    _clientIdController.text = clip.text!.trim();
                  }
                },
                child: const Text('Paste clipboard into Client ID'),
              ),
              const SizedBox(height: 8),
              // Server setup helper + small quick-save for client_id and redirect (no client_secret)
              ElevatedButton(
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) {
                      final cidCtrl = TextEditingController(text: _clientIdController.text);
                      final redCtrl = TextEditingController(text: _redirectController.text);
                      final backendCtrl = TextEditingController(text: _backendController.text);
                      return AlertDialog(
                        title: const Text('Server setup & Save Client ID'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(controller: cidCtrl, decoration: const InputDecoration(labelText: 'Client ID')),
                              const SizedBox(height: 8),
                              TextField(controller: redCtrl, decoration: const InputDecoration(labelText: 'Redirect URI')),
                              const SizedBox(height: 8),
                              TextField(controller: backendCtrl, decoration: const InputDecoration(labelText: 'Backend API base (optional)')),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('Server setup instructions (run on your development machine):', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SelectableText(
                                'firebase functions:config:set fitbit.client_id="<FITBIT_CLIENT_ID>" fitbit.client_secret="<FITBIT_CLIENT_SECRET>"\n# then deploy functions:\nfirebase deploy --only functions',
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 8),
                              Text('Tip: replace <FITBIT_CLIENT_ID> with the Client ID shown above and <FITBIT_CLIENT_SECRET> with the secret from Fitbit developer console.'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                          TextButton(onPressed: () async {
                            // save client_id, redirect and backend only (do not save client_secret)
                            try {
                              await _service.saveFitbitCredentials(clientId: cidCtrl.text.trim(), clientSecret: '', redirectUri: redCtrl.text.trim());
                              if (backendCtrl.text.trim().isNotEmpty) await _service.saveBackendBase(backendCtrl.text.trim());
                              // update controllers shown on screen
                              if (!mounted) return;
                              setState(() {
                                _clientIdController.text = cidCtrl.text.trim();
                                _redirectController.text = redCtrl.text.trim();
                                _backendController.text = backendCtrl.text.trim();
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client ID and redirect saved (secret must be set on server)')));
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                            } finally {
                              Navigator.of(ctx).pop();
                            }
                          }, child: const Text('Save Client ID')),
                        ],
                      );
                    }
                  );
                },
                child: const Text('Server Setup & Save Client ID'),
              ),
              const SizedBox(height: 12),
              // Connection status summary row
              if (_testResult != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statusIcon(_testResult!['backend_ok'] == true),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Backend: ${_testResult!['backend_base'] ?? '<not set>' }')),
                    const SizedBox(width: 8),
                    if (_accessExpiresAt != null) Text('Token expires: ${_formatExpiry(_accessExpiresAt!)}'),
                  ],
                ),
                if (_lastSync != null) ...[
                  const SizedBox(height: 8),
                  Text('Last sync: ${DateFormat.yMd().add_jm().format(_lastSync!)}'),
                ],
              ],
              const SizedBox(height: 12),
              const Text('Warning: These values are stored in device secure storage. Do not commit them to source control.', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ),
    );
  }
}
