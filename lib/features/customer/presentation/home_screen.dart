import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatting/arabic_numbers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/context_l10n.dart';
import '../../../shared/models/customer_model.dart';
import '../../../shared/models/transaction_model.dart';
import 'providers/customer_providers.dart';
import 'transaction_type_labels.dart';
import 'widgets/customer_history_content.dart';

const Color _kPageBg = Color(0xFFF8F9FA);
const Color _kPointBlue = Color(0xFF185FA5);
const Color _kTeal = Color(0xFF1D9E75);
const Color _kAmber = Color(0xFFEF9F27);

Color _parseHexColor(String? hex, {Color fallback = _kPointBlue}) {
  if (hex == null) return fallback;
  var h = hex.trim();
  if (h.isEmpty) return fallback;
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return fallback;
  return Color(v);
}

String _initials(String name) {
  final t = name.trim();
  if (t.isEmpty) return 'مت';
  final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return t.characters.take(2).toString();
  if (parts.length == 1) return parts.first.characters.take(2).toString();
  return (parts.first.characters.take(1).toString() +
          parts.last.characters.take(1).toString())
      .toUpperCase();
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

class _StoreView {
  const _StoreView({
    required this.name,
    required this.logoUrl,
    required this.brandColor,
  });

  final String name;
  final String? logoUrl;
  final Color brandColor;
}

final _storeByIdProvider = FutureProvider.family<_StoreView, String>((ref, storeId) async {
  if (!Env.hasSupabase) {
    return const _StoreView(name: 'متجري', logoUrl: null, brandColor: _kPointBlue);
  }
  final row = await Supabase.instance.client
      .from('stores')
      .select('name, logo_url, brand_color')
      .eq('id', storeId)
      .maybeSingle();
  final name = (row?['name'] as String?)?.trim();
  final logo = row?['logo_url'] as String?;
  final color = _parseHexColor(row?['brand_color'] as String?, fallback: _kPointBlue);
  return _StoreView(name: (name == null || name.isEmpty) ? 'متجري' : name, logoUrl: logo, brandColor: color);
});

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
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        try {
          final id = await ref.read(currentCustomerIdProvider.future);
          await NotificationService.syncCustomerDeviceToken(id);
        } catch (_) {}
      }());
      unawaited(_showWelcomeIfNeeded(context));
      unawaited(() async {
        // Prime recent transactions once on first open.
        try {
          await ref.read(customerHistoryProvider.notifier).refresh();
        } catch (_) {}
      }());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arabicDigits = useArabicDigits(context);
    final customerAsync = ref.watch(customerStreamProvider);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: customerAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _kPointBlue),
        ),
        error: (err, stack) {
          if (kDebugMode) {
            debugPrint('[HOME ERROR] $err');
            debugPrint('[HOME STACK] $stack');
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'تعذر تحميل البيانات. حاول مرة أخرى.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => ref.invalidate(customerStreamProvider),
                    style: FilledButton.styleFrom(backgroundColor: _kPointBlue),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('تعذر تحميل بيانات العميل.'));
          }

          final storeAsync = ref.watch(_storeByIdProvider(customer.storeId));
          final histAsync = ref.watch(customerHistoryProvider);

          return RefreshIndicator(
            color: _kPointBlue,
            onRefresh: () async {
              ref.invalidate(customerStreamProvider);
              await ref.read(customerHistoryProvider.notifier).refresh();
              await Future<void>.delayed(const Duration(milliseconds: 250));
            },
            child: SafeArea(
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: storeAsync.when(
                  loading: () => _HomeBody(
                    customer: customer,
                    arabicDigits: arabicDigits,
                    store: const _StoreView(name: '...', logoUrl: null, brandColor: _kPointBlue),
                    histAsync: histAsync,
                    onViewAll: () => _openAllTransactions(context),
                  ),
                  error: (_, __) => _HomeBody(
                    customer: customer,
                    arabicDigits: arabicDigits,
                    store: const _StoreView(name: 'متجري', logoUrl: null, brandColor: _kPointBlue),
                    histAsync: histAsync,
                    onViewAll: () => _openAllTransactions(context),
                  ),
                  data: (store) => _HomeBody(
                    customer: customer,
                    arabicDigits: arabicDigits,
                    store: store,
                    histAsync: histAsync,
                    onViewAll: () => _openAllTransactions(context),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAllTransactions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: CustomScrollView(
                controller: controller,
                slivers: const [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
                      child: Center(
                        child: SizedBox(
                          width: 42,
                          height: 5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFE9ECEF),
                              borderRadius: BorderRadius.all(Radius.circular(999)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
                      child: Text(
                        'كل المعاملات',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: CustomerHistoryChips()),
                  CustomerHistorySliverList(),
                  SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.customer,
    required this.arabicDigits,
    required this.store,
    required this.histAsync,
    required this.onViewAll,
  });

  final CustomerModel customer;
  final bool arabicDigits;
  final _StoreView store;
  final AsyncValue<HistoryState> histAsync;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(customerName: customer.name, store: store),
        const SizedBox(height: 16),
        _HeroWalletCard(
          customer: customer,
          store: store,
          arabicDigits: arabicDigits,
          onOpenQr: () => context.push('/customer/qr'),
        ),
        const SizedBox(height: 14),
        const _WalletButtonsRow(),
        const SizedBox(height: 16),
        _QuickStatsRow(
          totalSpent: customer.totalSpent,
          visitCount: customer.visitCount,
          tier: customer.tier,
          arabicDigits: arabicDigits,
        ),
        const SizedBox(height: 22),
        _RecentTransactionsSection(
          histAsync: histAsync,
          arabicDigits: arabicDigits,
          onViewAll: onViewAll,
        ),
        const SizedBox(height: 110),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.customerName, required this.store});

  final String customerName;
  final _StoreView store;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _OutlinedIconButton(
          icon: Icons.notifications_none_rounded,
          onPressed: () => HapticFeedback.lightImpact(),
        ),
        const Spacer(),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'مرحباً، $customerName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StoreMiniLogo(store: store),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreMiniLogo extends StatelessWidget {
  const _StoreMiniLogo({required this.store});

  final _StoreView store;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(store.name);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (store.logoUrl == null || store.logoUrl!.isEmpty)
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Color(0xFF374151),
                ),
              ),
            )
          : Image.network(
              store.logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ),
    );
  }
}

class _HeroWalletCard extends StatelessWidget {
  const _HeroWalletCard({
    required this.customer,
    required this.store,
    required this.arabicDigits,
    required this.onOpenQr,
  });

  final CustomerModel customer;
  final _StoreView store;
  final bool arabicDigits;
  final VoidCallback onOpenQr;

  String _money(double v) => formatMoneyAr(v, arabicDigits: arabicDigits);

  @override
  Widget build(BuildContext context) {
    final pill = _tierPill(customer.tier);
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: store.brandColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pill.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    pill.label,
                    style: TextStyle(
                      color: pill.fg,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (store.logoUrl == null || store.logoUrl!.isEmpty)
                      ? Center(
                          child: Text(
                            _initials(store.name),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Color(0xFF111827),
                            ),
                          ),
                        )
                      : Image.network(
                          store.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              _initials(store.name),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كاش باك',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_money(customer.cashbackBalance)} ر.س',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kAmber,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رصيد الاشتراك',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_money(customer.subscriptionBalance)} ر.س',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                _OutlinedCircle(
                  icon: Icons.qr_code_rounded,
                  onPressed: onOpenQr,
                ),
                const Spacer(),
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletButtonsRow extends ConsumerStatefulWidget {
  const _WalletButtonsRow();

  @override
  ConsumerState<_WalletButtonsRow> createState() => _WalletButtonsRowState();
}

class _WalletButtonsRowState extends ConsumerState<_WalletButtonsRow> {
  bool _busy = false;

  bool get _isIOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get _isAndroid {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> _openWallet(BuildContext context) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      // Reuse existing wallet generation behavior.
      final map = await ref.read(customerRepositoryProvider).invokeGeneratePasskitWalletUrls();

      if (_isIOS) {
        final url = map['applePassUrl'] as String?;
        if (url == null || url.isEmpty) throw Exception('apple_pass_url_missing');
        final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!ok) {
          messenger.showSnackBar(
            const SnackBar(content: Text('تعذر فتح المحفظة. حاول مرة أخرى.')),
          );
        }
      } else {
        final url = map['landingUrl'] as String?;
        if (url == null || url.isEmpty) throw Exception('wallet_landing_url_missing');
        final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!ok) {
          messenger.showSnackBar(
            const SnackBar(content: Text('تعذر فتح المحفظة. حاول مرة أخرى.')),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر إنشاء البطاقة. حاول مرة أخرى.\n$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isIOS && !_isAndroid) {
      return const SizedBox.shrink();
    }

    if (_isIOS) {
      return SizedBox(
        height: 46,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : () => _openWallet(context),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Image.asset(AppAssets.appleWalletIcon, width: 22, height: 22),
          label: const Text(
            'إضافة إلى Apple Wallet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : () => _openWallet(context),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Image.asset(AppAssets.googleWalletIcon, width: 22, height: 22),
        label: const Text(
          'إضافة إلى Google Wallet',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.totalSpent,
    required this.visitCount,
    required this.tier,
    required this.arabicDigits,
  });

  final double totalSpent;
  final int visitCount;
  final String tier;
  final bool arabicDigits;

  @override
  Widget build(BuildContext context) {
    final pill = _tierPill(tier);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'إجمالي الإنفاق',
            value: '${formatMoneyAr(totalSpent, arabicDigits: arabicDigits)} ر.س',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'عدد الزيارات',
            value: formatIntAr(visitCount, arabicDigits: arabicDigits),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'المستوى',
            value: pill.label.replaceAll(' ⭐', ''),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({
    required this.histAsync,
    required this.arabicDigits,
    required this.onViewAll,
  });

  final AsyncValue<HistoryState> histAsync;
  final bool arabicDigits;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: onViewAll,
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _kPointBlue),
                ),
              ),
              const Spacer(),
              const Text(
                'آخر المعاملات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          histAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(color: _kPointBlue)),
            ),
            error: (_, __) => const _TxEmptyState(),
            data: (state) {
              final items = state.items.take(5).toList(growable: false);
              if (items.isEmpty) return const _TxEmptyState();
              return Column(
                children: items.map((tx) => _TxRow(tx: tx, arabicDigits: arabicDigits)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TxEmptyState extends StatelessWidget {
  const _TxEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 44, color: _kPointBlue.withValues(alpha: 0.35)),
          const SizedBox(height: 10),
          const Text(
            'لا توجد معاملات بعد',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx, required this.arabicDigits});

  final TransactionModel tx;
  final bool arabicDigits;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dt = DateFormat.yMMMd(localeTag).format(tx.createdAt.toLocal());

    final isRedemption = tx.type == 'redemption';
    final typeLabel = transactionTypeLocalized(context, tx.type);

    final mainAmount = isRedemption ? (tx.subscriptionUsed + tx.cashbackUsed) : tx.amount;
    final amountPrefix = isRedemption ? '-' : '+';
    final amountColor = isRedemption ? const Color(0xFFF97316) : _kTeal;

    final icon = isRedemption ? Icons.call_made_rounded : Icons.call_received_rounded;
    final iconColor = amountColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            '$amountPrefix${formatMoneyAr(mainAmount, arabicDigits: arabicDigits)}',
            style: TextStyle(fontWeight: FontWeight.w900, color: amountColor, fontSize: 15),
          ),
          const Spacer(),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  typeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  dt,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ],
      ),
    );
  }
}

class _OutlinedIconButton extends StatelessWidget {
  const _OutlinedIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
        ),
        child: Icon(icon, color: const Color(0xFF111827)),
      ),
    );
  }
}

class _OutlinedCircle extends StatelessWidget {
  const _OutlinedCircle({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          shape: const CircleBorder(),
          backgroundColor: Colors.white.withValues(alpha: 0.10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
