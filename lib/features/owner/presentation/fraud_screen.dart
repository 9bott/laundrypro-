import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/owner_repository.dart';
import '../../../core/providers/active_store_provider.dart';
import 'providers/owner_providers.dart';

String _flagLabel(AppLocalizations l10n, String type) {
  switch (type) {
    case 'self_transaction':
      return l10n.fraudFlagSelfTx;
    case 'velocity_exceeded':
      return l10n.fraudFlagVelocity;
    case 'large_amount':
      return l10n.fraudFlagLarge;
    case 'duplicate_device':
      return l10n.fraudFlagDevice;
    default:
      return type;
  }
}

class OwnerFraudScreen extends ConsumerStatefulWidget {
  const OwnerFraudScreen({super.key});

  @override
  ConsumerState<OwnerFraudScreen> createState() => _OwnerFraudScreenState();
}

class _OwnerFraudScreenState extends ConsumerState<OwnerFraudScreen> {
  bool _loading = true;
  List<FraudFlagRow> _rows = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final storeId = ref.read(activeStoreProvider).asData?.value;
      if (storeId == null || storeId.isEmpty) {
        throw Exception('missing_active_store');
      }
      _rows = await ref
          .read(ownerRepositoryProvider)
          .fetchFraudFlags(storeId: storeId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(FraudFlagRow f, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final storeId = ref.read(activeStoreProvider).asData?.value;
      if (storeId == null || storeId.isEmpty) {
        throw Exception('missing_active_store');
      }
      await ref.read(ownerRepositoryProvider).resolveFraudFlag(
            storeId: storeId,
            flagId: f.id,
            action: action,
            notes: action,
          );
      if (mounted) {
        await _load();
        messenger.showSnackBar(const SnackBar(content: Text('OK')));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fraudAlerts),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Text(
                    l10n.nothingToShow,
                  ),
                )
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (_, i) {
                    final f = _rows[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _flagLabel(l10n, f.flagType),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text('${l10n.staffListTitle}: ${f.staffName ?? f.staffId}'),
                            Text('${l10n.customersTitle}: ${f.customerName ?? f.customerId}'),
                            if (f.transactionId != null)
                              Text(
                                'TX ${f.txType} ${f.txAmount?.toStringAsFixed(2) ?? ""} · ${f.transactionId}',
                              ),
                            Text(f.createdAt.toLocal().toString()),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                FilledButton.tonal(
                                  onPressed: () => _resolve(f, 'review'),
                                  child: Text(
                                    l10n.markReviewed,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                  ),
                                  onPressed: f.transactionId == null
                                      ? null
                                      : () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) {
                                              final dl = AppLocalizations.of(ctx)!;
                                              return AlertDialog(
                                                title: Text(
                                                  dl.reverseTransaction,
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, false),
                                                    child: Text(
                                                      dl.cancel,
                                                    ),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: Text(
                                                      dl.reverseTransaction,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (ok == true) await _resolve(f, 'reverse');
                                        },
                                  child: Text(
                                    l10n.reverseTransaction,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
