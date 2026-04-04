import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/formatting/arabic_numbers.dart';
import '../../../l10n/context_l10n.dart';
import '../../../shared/widgets/animated_bg.dart';
import '../../../shared/widgets/app_logo_loader.dart';
import '../../../shared/widgets/gradient_header.dart';
import 'providers/customer_providers.dart';
import 'wallet_hero_constants.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final arabicDigits = useArabicDigits(context);
    final async = ref.watch(customerStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: async.when(
          loading: () => const Center(
            child: AppLogoLoader(size: 120, background: Colors.white),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$e', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(customerStreamProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
          data: (c) {
            if (c == null) {
              return Center(
                child: Text(
                  l10n.error,
                ),
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: GradientHeader(
                    title: l10n.myWallet,
                    subtitle: l10n.walletHowItWorks,
                    trailing: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    pillText:
                        '${l10n.totalColon} ${formatMoneyAr(c.subscriptionBalance + c.cashbackBalance, arabicDigits: arabicDigits)}',
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        Hero(
                          tag: kCustomerWalletHeroTag,
                          flightShuttleBuilder: (_, animation, flightDirection,
                              fromContext, toContext) {
                            final shuttleHero = toContext.widget as Hero;
                            return shuttleHero.child;
                          },
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.primaryMid],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _detailCard(
                          context,
                          title: l10n.subscriptionShort,
                          amount: c.subscriptionBalance,
                          subtitle: l10n.walletSubscriptionHelp,
                          accent: AppColors.success,
                          arabicDigits: arabicDigits,
                        ),
                        const SizedBox(height: 16),
                        _detailCard(
                          context,
                          title: l10n.cashbackBalance,
                          amount: c.cashbackBalance,
                          subtitle: l10n.walletCashbackHelp,
                          accent: AppColors.gold,
                          arabicDigits: arabicDigits,
                        ),
                        const SizedBox(height: 24),
                        _step(
                          context,
                          Icons.payments_outlined,
                          l10n.walletStepPayCash,
                        ),
                        _step(
                          context,
                          Icons.percent,
                          l10n.walletStepCashback,
                        ),
                        _step(
                          context,
                          Icons.redeem,
                          l10n.walletStepUseNext,
                        ),
                        const SizedBox(height: 140),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _detailCard(
    BuildContext context, {
    required String title,
    required double amount,
    required String subtitle,
    required Color accent,
    required bool arabicDigits,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withOpacity(0.4), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              formatMoneyAr(amount, arabicDigits: arabicDigits),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _step(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
