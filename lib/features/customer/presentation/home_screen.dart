import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/context_l10n.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/customer_model.dart';
import '../../../shared/widgets/animated_bg.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/tier_badge.dart';
import 'providers/customer_providers.dart';
import 'widgets/customer_history_content.dart';
import 'widgets/wallet_add_buttons.dart';

String _westernDigitsToArabic(String s) {
  // Requirement: always show Western (English) digits.
  return s;
}

String _formatPhoneForDisplay(String phone, {required bool arabicDigits}) {
  if (!phone.startsWith('+966')) {
    return arabicDigits ? _westernDigitsToArabic(phone) : phone;
  }
  final rest = phone.substring(4).replaceAll(RegExp(r'\D'), '');
  if (rest.length >= 9) {
    final a = '${rest.substring(0, 2)} ${rest.substring(2, 5)} ${rest.substring(5)}';
    final out = '+966 $a';
    return arabicDigits ? _westernDigitsToArabic(out) : out;
  }
  return phone;
}

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  late final ScrollController _scroll;

  Future<void> _showWelcomeIfNeeded(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getBool('welcome_shown') ?? false;
      if (shown) return;

      final session = SupabaseService.client.auth.currentSession;
      if (session == null) return;

      final customerId = await ref.read(currentCustomerIdProvider.future);
      if (customerId == null) return;

      // Only show if welcome bonus transaction exists.
      final res = await SupabaseService.client
          .from('transactions')
          .select('id')
          .eq('customer_id', customerId)
          .eq('type', 'cashback_bonus')
          .eq('notes', 'welcome_bonus')
          .limit(1);

      final hasBonus = (res as List).isNotEmpty;
      if (!hasBonus) return;

      await prefs.setBool('welcome_shown', true);
      if (!context.mounted) return;

      final l10n = AppLocalizations.of(context)!;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: const Text('🎁', style: TextStyle(fontSize: 72)),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.welcomeDialogTitle,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.welcomeDialogBody,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.welcomeGiftBadge,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.tierGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.welcomeGiftAmount,
                      style: GoogleFonts.cairo(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                    Text(
                      l10n.welcomeGiftCaption,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.welcomeGetStarted,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Welcome dialog error: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScrollLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        try {
          final id = await ref.read(currentCustomerIdProvider.future);
          await NotificationService.syncCustomerDeviceToken(id);
        } catch (_) {}
      }());
      unawaited(_showWelcomeIfNeeded(context));
    });
  }

  void _onScrollLoadMore() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 120) {
      ref.read(customerHistoryProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScrollLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final arabicDigits = useArabicDigits(context);
    final customerAsync = ref.watch(customerStreamProvider);
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        extraOrbs: true,
        child: customerAsync.when(
          loading: () => _HomeLoadingTimeout(
            onRetry: () => ref.invalidate(customerStreamProvider),
            child: const _HomeLoadingSkeleton(),
          ),
          error: (err, stack) {
            if (kDebugMode) {
              debugPrint('[HOME ERROR] $err');
              debugPrint('[HOME STACK] $stack');
            }
            return _HomeErrorState(
              message: l10n.homeLoadErrorMessage,
              onRetry: () => ref.invalidate(customerStreamProvider),
            );
          },
          data: (customer) {
            if (customer == null) {
              return Center(
                child: Text(
                  l10n.error,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(customerStreamProvider);
                await ref.read(customerHistoryProvider.notifier).refresh();
                await Future<void>.delayed(const Duration(milliseconds: 400));
              },
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 0),
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        radius: 18,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    l10n.welcomeUser(customer.name),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.homeBalanceReady,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                ),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => HapticFeedback.lightImpact(),
                                icon: const Icon(
                                  Icons.notifications_active_outlined,
                                  color: AppColors.primaryLight,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _WalletGradientCard(
                        customer: customer,
                        arabicDigits: arabicDigits,
                        onOpenWallet: () => context.push('/customer/wallet'),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _HomeQrSection(customerId: customer.id),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _formatPhoneForDisplay(
                            customer.phone,
                            arabicDigits: arabicDigits,
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                      child: Text(
                        l10n.transactions,
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: const CustomerHistoryChips(),
                  ),
                  const CustomerHistorySliverList(),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeLoadingTimeout extends StatelessWidget {
  const _HomeLoadingTimeout({required this.onRetry, required this.child});

  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<void>(
      future: Future<void>.delayed(const Duration(seconds: 12)),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return child;
        }
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.loadingTakingLong,
                style: GoogleFonts.cairo(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(l10n.retry, style: GoogleFonts.cairo()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WalletGradientCard extends StatelessWidget {
  const _WalletGradientCard({
    required this.customer,
    required this.arabicDigits,
    required this.onOpenWallet,
  });

  final CustomerModel customer;
  final bool arabicDigits;
  final VoidCallback onOpenWallet;

  String _amt(double v) {
    final s = v.toStringAsFixed(2);
    return arabicDigits ? _westernDigitsToArabic(s) : s;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final sub = customer.subscriptionBalance;
    final cb = customer.cashbackBalance;

    return Hero(
      tag: 'customer_balance_hero_card',
      flightShuttleBuilder: (_, animation, flightDirection, fromContext, toContext) {
        final shuttleHero = toContext.widget as Hero;
        return shuttleHero.child;
      },
      child: _PressableScale(
        enableAnim: !disableAnim,
        onTap: onOpenWallet,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.blueGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: AppColors.blueShadow,
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TierBadge(
                          tier: customer.tier,
                          activePlanName: customer.activePlanName,
                          activePlanNameAr: customer.activePlanNameAr,
                          onDarkBackground: true,
                          dense: false,
                        ),
                        Text(
                          l10n.myBalance,
                          style: GoogleFonts.cairo(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.subscriptionShort,
                                  style: GoogleFonts.cairo(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _amt(sub),
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  l10n.currencyDisplay,
                                  style: GoogleFonts.cairo(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            color: Colors.white24,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.cashbackBalance,
                                  style: GoogleFonts.cairo(
                                    color: AppColors.goldLight,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _amt(cb),
                                  style: GoogleFonts.cairo(
                                    color: AppColors.goldLight,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  l10n.currencyDisplay,
                                  style: GoogleFonts.cairo(
                                    color: AppColors.gold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// QR ثابت = `customers.id` (نفس قيمة الباركود في Google/Apple Wallet).
class _HomeQrSection extends StatelessWidget {
  const _HomeQrSection({required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.showQrToStaff,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.55),
                  ),
                ),
                child: QrImageView(
                  data: customerId,
                  size: 196,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0F172A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.staticLoyaltyQrHint,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: AppColors.textHint,
            ),
          ),
          const WalletAddButtons(compact: true),
        ],
      ),
    );
  }
}

class _HomeLoadingSkeleton extends StatelessWidget {
  const _HomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppCard(
              padding: const EdgeInsets.all(20),
              borderColor: AppColors.error.withValues(alpha: 0.4),
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.8)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              child: Text(
                l10n.retry,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({
    required this.child,
    required this.onTap,
    this.enableAnim = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enableAnim;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.enableAnim) setState(() => _scale = 0.97);
      },
      onTapUp: (_) {
        if (widget.enableAnim) setState(() => _scale = 1);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () {
        if (widget.enableAnim) setState(() => _scale = 1);
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
