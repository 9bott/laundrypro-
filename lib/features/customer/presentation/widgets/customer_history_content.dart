import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatting/arabic_numbers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/context_l10n.dart';
import '../../../../shared/models/transaction_model.dart';
import '../../../../shared/widgets/app_card.dart';
import '../providers/customer_providers.dart';
import '../providers/history_notifier.dart';
import '../transaction_type_labels.dart';

bool customerHistoryIsBonusType(String type) {
  switch (type) {
    case 'cashback_bonus':
    case 'referral_bonus':
    case 'streak_bonus':
    case 'birthday_bonus':
      return true;
    default:
      return false;
  }
}

({Color bg, Color fg, IconData icon}) customerHistoryTxVisuals(String type) {
  switch (type) {
    case 'cashback_earned':
      return (
        bg: AppColors.goldTint,
        fg: AppColors.gold,
        icon: Icons.account_balance_wallet_outlined,
      );
    case 'purchase':
      return (
        bg: AppColors.primaryTint,
        fg: AppColors.primary,
        icon: Icons.shopping_bag_outlined,
      );
    case 'redemption':
      return (
        bg: AppColors.warningTint,
        fg: AppColors.warning,
        icon: Icons.account_balance_wallet_outlined,
      );
    case 'subscription':
      return (
        bg: AppColors.txSubscriptionBg,
        fg: AppColors.iconSubscriptionFg,
        icon: Icons.star_rounded,
      );
    default:
      if (customerHistoryIsBonusType(type)) {
        return (
          bg: AppColors.successTint,
          fg: AppColors.success,
          icon: Icons.card_giftcard_rounded,
        );
      }
      return (
        bg: AppColors.primaryTint,
        fg: AppColors.primary,
        icon: Icons.receipt_long_rounded,
      );
  }
}

/// Horizontal filter chips (non-sliver).
class CustomerHistoryChips extends ConsumerWidget {
  const CustomerHistoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          _chip(ref, 'all', l10n.filterAll),
          _chip(ref, 'purchase', l10n.filterPurchase),
          _chip(ref, 'redemption', l10n.filterRedemption),
          _chip(ref, 'subscription', l10n.filterSubscription),
          _chip(ref, 'rewards', l10n.filterBonus),
        ],
      ),
    );
  }

  Widget _chip(WidgetRef ref, String key, String label) {
    final sel = (ref.watch(customerHistoryProvider).value?.filter ?? 'all') == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(customerHistoryProvider.notifier).applyFilter(key);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: sel
                  ? const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                    )
                  : null,
              color: sel ? null : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? Colors.transparent : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sliver list: transactions + pagination loader.
class CustomerHistorySliverList extends ConsumerWidget {
  const CustomerHistorySliverList({super.key});

  static const _slideBegin = Offset(0.3, 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = ref.watch(customerHistoryProvider);

    return hist.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 24, 0, 48),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: _HistoryEmptyBody()),
      data: (state) {
        if (state.items.isEmpty) {
          return const SliverToBoxAdapter(child: _HistoryEmptyBody());
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }
                return CustomerStaggeredTxTile(
                  index: i,
                  slideBegin: _slideBegin,
                  tx: state.items[i],
                );
              },
              childCount: state.items.length + (state.hasMore ? 1 : 0),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryEmptyBody extends StatelessWidget {
  const _HistoryEmptyBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 56, color: AppColors.primary.withOpacity(0.45)),
          const SizedBox(height: 12),
          Text(
            l10n.noTransactions,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerStaggeredTxTile extends StatefulWidget {
  const CustomerStaggeredTxTile({
    super.key,
    required this.index,
    required this.slideBegin,
    required this.tx,
  });

  final int index;
  final Offset slideBegin;
  final TransactionModel tx;

  @override
  State<CustomerStaggeredTxTile> createState() => _CustomerStaggeredTxTileState();
}

class _CustomerStaggeredTxTileState extends State<CustomerStaggeredTxTile> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final delayMs = widget.index * 60;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : widget.slideBegin,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        child: CustomerTxTile(tx: widget.tx),
      ),
    );
  }
}

class CustomerTxTile extends StatelessWidget {
  const CustomerTxTile({super.key, required this.tx});

  final TransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final arabicDigits = useArabicDigits(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final isRedemption = tx.type == 'redemption';
    final isCashback = tx.type == 'cashback_earned';
    final visuals = customerHistoryTxVisuals(tx.type);
    final typeLabel = transactionTypeLocalized(context, tx.type);
    final dt = DateFormat.yMMMd(localeTag)
        .add_jm()
        .format(tx.createdAt.toLocal());

    final mainAmount = isRedemption
        ? (tx.subscriptionUsed + tx.cashbackUsed)
        : tx.amount;
    final amountColor = isRedemption ? AppColors.error : AppColors.success;
    final amountPrefix = isRedemption ? '-' : '+';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        radius: 16,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visuals.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(visuals.icon, color: visuals.fg, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    typeLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dt,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$amountPrefix${formatMoneyAr(mainAmount, arabicDigits: arabicDigits)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                if (!isCashback && tx.cashbackEarned > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+${formatMoneyAr(tx.cashbackEarned, arabicDigits: arabicDigits)} ${l10n.cashbackEarnedSuffix}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
