import 'package:flutter/material.dart';

import 'package:billing_flutter_sdk/billing_flutter_sdk.dart';

void main() {
  runApp(const BillingExampleApp());
}

/// Example app: init on start, paste screen, sync button; show error notification when SDK returns failure.
class BillingExampleApp extends StatelessWidget {
  const BillingExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billing SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BillingExamplePage(),
    );
  }
}

class BillingExamplePage extends StatefulWidget {
  const BillingExamplePage({super.key});

  @override
  State<BillingExamplePage> createState() => _BillingExamplePageState();
}

class _BillingExamplePageState extends State<BillingExamplePage> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _uniqueIdController = TextEditingController();
  bool _syncing = false;
  String? _savedToken;

  @override
  void initState() {
    super.initState();
    _initSdk();
  }

  void _initSdk() {
    BillingSdk.configure(
      billingApiBaseUrl: 'https://billing.example.com',
      publicKeyPem: null, // use SDK default; set from Billing API in production
    );
    // In a real app: read saved token from secure storage and call BillingSdk.init(savedToken)
    BillingSdk.init(_savedToken);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade700),
    );
  }

  void _onPasteVerify() {
    final pasted = _tokenController.text.trim();
    if (pasted.isEmpty) {
      _showError('Paste a token first.');
      return;
    }
    final result = BillingSdk.verifyAndDecode(pasted);
    switch (result) {
      case VerifySuccess(:final payload):
        _savedToken = pasted;
        _showSuccess(
            'Token verified. Paying party: ${payload.payingPartyId}, subscriptions: ${payload.subscriptionIds.length}');
      case VerifyFailure(:final error):
        _showError(error.message);
    }
  }

  Future<void> _onSync() async {
    final uniqueId = _uniqueIdController.text.trim();
    if (uniqueId.isEmpty) {
      _showError('Enter email or SSO id.');
      return;
    }
    setState(() => _syncing = true);
    final result = await BillingSdk.syncFromServer(uniqueId: uniqueId);
    setState(() => _syncing = false);
    switch (result) {
      case SyncSuccess():
        _showSuccess('Billing synced.');
      case SyncFailure(:final message):
        _showError(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = BillingSdk.getPayload();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing SDK Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (payload != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current billing',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text('Paying party: ${payload.payingPartyId}'),
                      Text('Subscriptions: ${payload.subscriptionIds.join(", ")}'),
                      if (payload.email != null) Text('Email: ${payload.email}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Paste token',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Paste signed JWT from billing portal…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _onPasteVerify,
              child: const Text('Verify and save'),
            ),
            const SizedBox(height: 24),
            Text('Sync from server',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _uniqueIdController,
              decoration: const InputDecoration(
                labelText: 'Email or SSO id',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _syncing ? null : _onSync,
              child: _syncing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sync billing'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _uniqueIdController.dispose();
    super.dispose();
  }
}
