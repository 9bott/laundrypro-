import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/app_colors.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_logo_loader.dart';
import '../../../shared/widgets/tier_badge.dart';
import '../../customer/presentation/widgets/customer_history_content.dart';
import 'providers/staff_providers.dart';
import 'staff_route_models.dart';

class StaffCustomerCardScreen extends ConsumerWidget {
  const StaffCustomerCardScreen({super.key});

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
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final c = ref.watch(staffCustomerProvider);
    if (c == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(staffShellScannerPathForRef(ref));
      });
      // Don't show an intermediate "spinner page" while redirecting.
      return const Scaffold(body: SizedBox.shrink());
    }

    final dateStr = c.lastVisitDate != null
        ? DateFormat.yMMMd(localeTag).format(c.lastVisitDate!)
        : '—';
    final createdStr =
        c.createdAt != null ? DateFormat.yMMMd(localeTag).format(c.createdAt!) : '—';
    final birthStr =
        c.birthday != null ? DateFormat.yMMMd(localeTag).format(c.birthday!) : '—';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            staffHaptic();
            ref.read(staffCustomerProvider.notifier).select(null);
            context.go(staffShellScannerPathForRef(ref));
          },
        ),
        title: Text(l10n.customerCardTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: ClipOval(
                  child: c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: c.avatarUrl!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          memCacheWidth: 176,
                          memCacheHeight: 176,
                        )
                      : Text(
                          _initials(c.name),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TierBadge(
                      tier: c.tier,
                      activePlanName: c.activePlanName,
                      activePlanNameAr: c.activePlanNameAr,
                      dense: false,
                    ),
                    if (c.isBlocked) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.errorTint,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.block_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.blockedBadge,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _balanceCard(
                  context,
                  title: l10n.subscriptionBalance,
                  value: c.subscriptionBalance,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _balanceCard(
                  context,
                  title: l10n.cashbackBalance,
                  value: c.cashbackBalance,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoCard(
            context,
            title: l10n.customerInformation,
            children: [
              _infoRow(l10n.mobilePhone, _prettyPhone(c.phoneE164)),
              _infoRow(
                l10n.totalSpentLabel,
                '${c.totalSpent.toStringAsFixed(2)}${l10n.sarSuffix}',
              ),
              _infoRow(l10n.visits, '${c.visitCount}'),
              _infoRow(l10n.streakLabel, '${c.streakCount}'),
              _infoRow(l10n.birthday, birthStr),
              _infoRow(l10n.language, c.preferredLanguage ?? '—'),
              _infoRow(l10n.registeredOn, createdStr),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.visitNumber(c.visitCount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.lastVisit}: $dateStr',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 72,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                staffHaptic();
                ref
                    .read(staffTxnModeProvider.notifier)
                    .setMode(StaffTxnMode.purchase);
                context.push('/staff/amount-entry');
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.recordPurchase,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    l10n.addsCashback,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            width: double.infinity,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                staffHaptic();
                ref
                    .read(staffTxnModeProvider.notifier)
                    .setMode(StaffTxnMode.redeem);
                context.push('/staff/amount-entry');
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.redeemBalance,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    l10n.deductsFromBalance,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                staffHaptic();
                ref
                    .read(staffSelectedPlanIdProvider.notifier)
                    .setSelectedPlanId(null);
                context.push('/staff/add-subscription');
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.addSubscription,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    l10n.topUpWithCash,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _transactionsCard(context, ref, customerId: c.id),
        ],
        ),
      ),
    );
  }

  Widget _balanceCard(
    BuildContext context, {
    required String title,
    required double value,
    required Color color,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${value.toStringAsFixed(2)}${l10n.sarSuffix}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _prettyPhone(String raw) {
    final s = raw.trim();
    return s.isEmpty ? '—' : s;
  }

  Widget _infoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
