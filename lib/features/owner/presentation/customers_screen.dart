import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _loading = false;
  List<CustomerModel> _list = [];
  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

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
    final initials = _initials(c.name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDetail(c),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEFF6FF),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _kPointBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name.isEmpty ? '—' : c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TierBadge(
                            tier: c.tier,
                            activePlanName: c.activePlanName,
                            activePlanNameAr: c.activePlanNameAr,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          c.phone.isEmpty ? '—' : c.phone,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${(c.cashbackBalance + c.subscriptionBalance).toStringAsFixed(0)} ر.س',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF085041),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.cashbackBalance,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '؟';
    if (p.length == 1) return p[0].isEmpty ? '؟' : p[0][0].toUpperCase();
    final a = p.first.isEmpty ? '' : p.first[0];
    final b = p.last.isEmpty ? '' : p.last[0];
    final r = '$a$b';
    return r.isEmpty ? '؟' : r.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kPageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'العملاء',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                '${_list.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _kPointBlue,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'ابحث بالاسم أو رقم الجوال',
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _reload(),
                    ),
                  ),
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.tune_rounded, color: _kPointBlue),
                    tooltip: l10n.search,
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _TierChip(
                  label: 'الكل',
                  selected: _tier == 'all',
                  onTap: () {
                    setState(() => _tier = 'all');
                    _reload();
                  },
                ),
                _TierChip(
                  label: 'ذهبي',
                  selected: _tier == 'gold',
                  onTap: () {
                    setState(() => _tier = 'gold');
                    _reload();
                  },
                ),
                _TierChip(
                  label: 'فضي',
                  selected: _tier == 'silver',
                  onTap: () {
                    setState(() => _tier = 'silver');
                    _reload();
                  },
                ),
                _TierChip(
                  label: 'برونزي',
                  selected: _tier == 'bronze',
                  onTap: () {
                    setState(() => _tier = 'bronze');
                    _reload();
                  },
                ),
                _TierChip(
                  label: 'ماسي',
                  selected: _tier == 'diamond',
                  onTap: () {
                    setState(() => _tier = 'diamond');
                    _reload();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
                    color: _kPointBlue,
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

class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF185FA5) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? const Color(0xFF185FA5) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: selected ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
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