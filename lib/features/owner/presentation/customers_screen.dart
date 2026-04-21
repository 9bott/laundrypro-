import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/customer_model.dart';
import '../../../shared/models/transaction_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/tier_badge.dart';
import 'providers/owner_providers.dart';

class OwnerCustomersScreen extends ConsumerStatefulWidget {
  const OwnerCustomersScreen({super.key});

  @override
  ConsumerState<OwnerCustomersScreen> createState() =>
      _OwnerCustomersScreenState();
}

class _OwnerCustomersScreenState extends ConsumerState<OwnerCustomersScreen> {
  final _search = TextEditingController();
  String _tier = 'all';
  bool _dormant = false;
  bool _loading = false;
  List<CustomerModel> _list = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_reload);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(ownerRepositoryProvider);
      final tier = _tier == 'all' ? null : _tier;
      _list = await repo.fetchCustomersDirectory(
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        tier: tier,
        dormantOnly: _dormant,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(CustomerModel c) async {
    List<TransactionModel> txs = [];
    try {
      txs = await ref.read(ownerRepositoryProvider).fetchCustomerTransactions(c.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        maxChildSize: 0.92,
        builder: (_, ctl) => _CustomerDetailSheet(
          customer: c,
          transactions: txs,
          onRefresh: _reload,
          scroll: ctl,
        ),
      ),
    );
  }

  Widget _searchSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _rowSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 56,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: 180,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customerTile(CustomerModel c, AppLocalizations l10n) {
    final lv = c.lastVisitDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppCard(
        child: InkWell(
          onTap: () => _openDetail(c),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TierBadge(
                      tier: c.tier,
                      activePlanName: c.activePlanName,
                      activePlanNameAr: c.activePlanNameAr,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  c.phone.isEmpty ? '—' : c.phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${l10n.cashbackBalance}: '
                      '${c.cashbackBalance.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${l10n.filterSubscription}: '
                      '${c.subscriptionBalance.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${l10n.visits}: ${c.visitCount}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.lastVisit}: '
                  '${lv == null ? '—' : '${lv.toLocal()}'.split('.').first}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customersTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _reload,
                ),
              ),
              onSubmitted: (_) => _reload(),
            ),
          ),
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: Text(l10n.filterAll),
                selected: _tier == 'all' && !_dormant,
                onSelected: (_) {
                  setState(() {
                    _tier = 'all';
                    _dormant = false;
                  });
                  _reload();
                },
              ),
              ChoiceChip(
                label: Text(l10n.bronze),
                selected: _tier == 'bronze',
                onSelected: (_) {
                  setState(() => _tier = 'bronze');
                  _reload();
                },
              ),
              ChoiceChip(
                label: Text(l10n.silver),
                selected: _tier == 'silver',
                onSelected: (_) {
                  setState(() => _tier = 'silver');
                  _reload();
                },
              ),
              ChoiceChip(
                label: Text(l10n.gold),
                selected: _tier == 'gold',
                onSelected: (_) {
                  setState(() => _tier = 'gold');
                  _reload();
                },
              ),
              ChoiceChip(
                label: Text(l10n.filterDormant),
                selected: _dormant,
                onSelected: (v) {
                  setState(() => _dormant = v);
                  _reload();
                },
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    children: [
                      _searchSkeleton(),
                      ...List.generate(6, (_) => _rowSkeleton()),
                    ],
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _reload,
                    child: _list.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 120),
                            children: [
                              Center(
                                child: Text(
                                  l10n.nothingToShow,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
                            itemCount: _list.length,
                            itemBuilder: (_, i) => _customerTile(_list[i], l10n),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDetailSheet extends ConsumerStatefulWidget {
  const _CustomerDetailSheet({
    required this.customer,
    required this.transactions,
    required this.onRefresh,
    required this.scroll,
  });

  final CustomerModel customer;
  final List<TransactionModel> transactions;
  final VoidCallback onRefresh;
  final ScrollController scroll;

  @override
  ConsumerState<_CustomerDetailSheet> createState() => _CustomerDetailSheetState();
}

class _CustomerDetailSheetState extends ConsumerState<_CustomerDetailSheet> {
  Future<void> _adjustBalance() async {
    final subCtl = TextEditingController();
    final cbCtl = TextEditingController();
    final reasonCtl = TextEditingController();
    try {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final dl = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(dl.adjustBalance),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: dl.filterSubscription,
                    ),
                  ),
                  TextField(
                    controller: cbCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: dl.cashbackBalance,
                    ),
                  ),
                  TextField(
                    controller: reasonCtl,
                    decoration: InputDecoration(
                      labelText: dl.reasonRequired,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(dl.save),
              ),
            ],
          );
        },
      );
      if (go != true) return;
      final rs = reasonCtl.text.trim();
      if (rs.isEmpty) return;
      final ds = double.tryParse(subCtl.text.trim()) ?? 0;
      final dc = double.tryParse(cbCtl.text.trim()) ?? 0;
      if (ds == 0 && dc == 0) return;
      await ref.read(ownerRepositoryProvider).adjustCustomerBalance(
            customerId: widget.customer.id,
            deltaSubscription: ds,
            deltaCashback: dc,
            reason: rs,
          );
      if (!mounted) return;
      widget.onRefresh();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      subCtl.dispose();
      cbCtl.dispose();
      reasonCtl.dispose();
    }
  }

  Future<void> _toggleBlock() async {
    final c = widget.customer;
    final reasonCtl = TextEditingController();
    try {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final dl = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(
              c.isBlocked ? dl.unblockCustomer : dl.blockCustomer,
            ),
            content: c.isBlocked
                ? null
                : TextField(
                    controller: reasonCtl,
                    decoration: InputDecoration(
                      labelText: dl.reasonRequired,
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(dl.save),
              ),
            ],
          );
        },
      );
      if (go != true) return;
      await ref.read(ownerRepositoryProvider).setCustomerBlocked(
            customerId: c.id,
            blocked: !c.isBlocked,
            reason: reasonCtl.text.trim().isEmpty ? null : reasonCtl.text.trim(),
          );
      if (!mounted) return;
      widget.onRefresh();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      reasonCtl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = widget.customer;
    final txs = widget.transactions;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: ListTile(
                  title: Text(c.name),
                  subtitle: Text(
                    c.phone,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _adjustBalance,
                child: Text(
                  l10n.adjustBalance,
                ),
              ),
              OutlinedButton(
                onPressed: _toggleBlock,
                child: Text(
                  c.isBlocked ? l10n.unblockCustomer : l10n.blockCustomer,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: widget.scroll,
            padding: const EdgeInsets.all(12),
            itemCount: txs.length,
            itemBuilder: (_, i) {
              final t = txs[i];
              return ListTile(
                dense: true,
                title: Text(t.type),
                subtitle: Text(
                  '${t.createdAt.toLocal()}'.split('.').first,
                  textDirection: TextDirection.ltr,
                ),
                trailing: Text(
                  t.amount.toStringAsFixed(2),
                  textDirection: TextDirection.ltr,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}