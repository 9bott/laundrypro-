import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/context_l10n.dart';
import 'providers/customer_providers.dart';
import 'widgets/wallet_add_buttons.dart';

class CustomerWalletScreen extends ConsumerWidget {
  const CustomerWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final customerAsync = ref.watch(customerStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.walletTitle, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
      ),
      body: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(l10n.error, style: GoogleFonts.cairo(color: AppColors.textPrimary)),
        ),
        data: (customer) {
          if (customer == null) {
            return Center(child: Text(l10n.error, style: GoogleFonts.cairo()));
          }

          final total =
              (customer.subscriptionBalance + customer.cashbackBalance).toStringAsFixed(2);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      customer.name,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.totalBalance(total),
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.walletSubtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textHint,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const WalletAddButtons(),
            ],
          );
        },
      ),
    );
  }
}
