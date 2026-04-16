import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_logo_loader.dart';
import '../../customer/presentation/widgets/customer_history_content.dart';
import '../data/staff_repository.dart';
import 'providers/staff_providers.dart';
import 'staff_route_models.dart';

class StaffCustomerCardScreen extends ConsumerWidget {
  const StaffCustomerCardScreen({super.key});

  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    if (p.length == 1) {
      final s = p.first;
      if (s.length >= 2) return s.substring(0, 2).toUpperCase();
      return s.toUpperCase();
    }
    return ('${p[0][0]}${p[1][0]}').toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(staffCustomerProvider);
    if (c == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(staffShellScannerPathForRef(ref));
      });
      // Don't show an intermediate "spinner page" while redirecting.
      return const Scaffold(body: SizedBox.shrink());
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kPageBg,
        appBar: AppBar(
          backgroundColor: _kPageBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              staffHaptic();
              ref.read(staffCustomerProvider.notifier).select(null);
              context.go(staffShellScannerPathForRef(ref));
            },
          ),
          title: const Text(
            'بطاقة العميل',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopCustomerCard(customer: c, initials: _initials(c.name)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _BalanceCard2(
                      title: 'كاش باك',
                      amount: c.cashbackBalance,
                      bg: const Color(0xFFFAEEDA),
                      fg: const Color(0xFF633806),
                      amountSize: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BalanceCard2(
                      title: 'رصيد الاشتراك',
                      amount: c.subscriptionBalance,
                      bg: const Color(0xFFE1F5EE),
                      fg: const Color(0xFF085041),
                      amountSize: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ActionButton(
                label: 'شراء',
                icon: Icons.shopping_bag_outlined,
                bg: _kPointBlue,
                fg: Colors.white,
                onTap: () {
                  staffHaptic();
                  ref.read(staffTxnModeProvider.notifier).setMode(StaffTxnMode.purchase);
                  context.push('/staff/amount-entry');
                },
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'استرداد',
                icon: Icons.call_made_rounded,
                bg: const Color(0xFFFAEEDA),
                fg: const Color(0xFF633806),
                onTap: () {
                  staffHaptic();
                  ref.read(staffTxnModeProvider.notifier).setMode(StaffTxnMode.redeem);
                  context.push('/staff/amount-entry');
                },
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'باقة اشتراك',
                icon: Icons.credit_card_rounded,
                bg: const Color(0xFFEEEDFE),
                fg: const Color(0xFF3C3489),
                onTap: () {
                  staffHaptic();
                  ref.read(staffSelectedPlanIdProvider.notifier).setSelectedPlanId(null);
                  context.push('/staff/add-subscription');
                },
              ),
              const SizedBox(height: 18),
              _transactionsCard(context, ref, customerId: c.id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transactionsCard(
    BuildContext context,
    WidgetRef ref, {
    required String customerId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(staffCustomerTransactionsProvider(customerId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.recentTransactionsTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 10),
            async.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: AppLogoLoader(size: 56, background: Colors.white),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '$e',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.noTransactions,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                final show = items.take(8).toList();
                final subs = items.where((t) => t.type == 'subscription').take(5).toList();
                return Column(
                  children: [
                    if (subs.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _miniHeader(l10n.recentSubscriptionsTitle),
                      for (final tx in subs) CustomerTxTile(tx: tx),
                      const Divider(height: 20),
                    ],
                    for (final tx in show) CustomerTxTile(tx: tx),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _miniHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TopCustomerCard extends StatelessWidget {
  const _TopCustomerCard({required this.customer, required this.initials});

  final StaffCustomerView customer;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final tier = customer.tier.toLowerCase();
    final pill = _tierPill(tier);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF185FA5),
            child: ClipOval(
              child: customer.avatarUrl != null && customer.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: customer.avatarUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      memCacheHeight: 160,
                    )
                  : Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            customer.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              customer.phoneE164.isEmpty ? '—' : customer.phoneE164,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: pill.bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pill.label,
              style: TextStyle(color: pill.fg, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  ({Color bg, Color fg, String label}) _tierPill(String tier) {
    switch (tier) {
      case 'gold':
        return (bg: const Color(0xFFFFE8B6), fg: const Color(0xFF8A5A00), label: 'ذهبي ⭐');
      case 'silver':
        return (bg: const Color(0xFFE9ECEF), fg: const Color(0xFF343A40), label: 'فضي');
      case 'diamond':
        return (bg: const Color(0xFFE7E0FF), fg: const Color(0xFF3A2A7A), label: 'ماسي');
      default:
        return (bg: const Color(0xFFFFD6B8), fg: const Color(0xFF7A3A00), label: 'برونزي');
    }
  }
}

class _BalanceCard2 extends StatelessWidget {
  const _BalanceCard2({
    required this.title,
    required this.amount,
    required this.bg,
    required this.fg,
    required this.amountSize,
  });

  final String title;
  final double amount;
  final Color bg;
  final Color fg;
  final double amountSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ر.س',
                style: TextStyle(fontWeight: FontWeight.w800, color: fg.withValues(alpha: 0.9)),
              ),
              const SizedBox(width: 6),
              Text(
                amount.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: amountSize,
                  fontWeight: FontWeight.w900,
                  color: fg,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: fg),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w900, color: fg, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
