import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatting/arabic_numbers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/context_l10n.dart';
import '../../../shared/models/subscription_plan_model.dart';
import '../../../shared/widgets/animated_bg.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_header.dart';
import 'providers/customer_providers.dart';

enum _PlanTier { silver, gold, diamond }

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String? _selectedId;

  List<SubscriptionPlanModel> _fallbackPlans() {
    // Default 3 plans:
    // pay 100 -> get 120 (20%), pay 150 -> get 180 (20%), pay 200 -> get 250 (25%).
    return const [
      SubscriptionPlanModel(
        id: 'p100',
        name: '100 SAR',
        nameAr: '١٠٠ ريال',
        price: 100,
        credit: 120,
        bonusPercentage: 20,
        isActive: true,
        sortOrder: 1,
      ),
      SubscriptionPlanModel(
        id: 'p150',
        name: '150 SAR',
        nameAr: '١٥٠ ريال',
        price: 150,
        credit: 180,
        bonusPercentage: 20,
        isActive: true,
        sortOrder: 2,
      ),
      SubscriptionPlanModel(
        id: 'p200',
        name: '200 SAR',
        nameAr: '٢٠٠ ريال',
        price: 200,
        credit: 250,
        bonusPercentage: 25,
        isActive: true,
        sortOrder: 3,
      ),
    ];
  }

  List<SubscriptionPlanModel> _ensureDefaultPlans(List<SubscriptionPlanModel> remote) {
    // If backend returns fewer plans (or none), always ensure the 3 default plans exist.
    // We match by price point to avoid duplicates.
    final out = [...remote];
    final defaults = _fallbackPlans();
    bool hasPrice(double p) => out.any((x) => (x.price - p).abs() < 0.001);
    for (final d in defaults) {
      if (!hasPrice(d.price)) out.add(d);
    }
    return out;
  }

  List<SubscriptionPlanModel> _sorted(List<SubscriptionPlanModel> all) {
    final list = [...all]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  int _savePct(SubscriptionPlanModel p) {
    if (p.price <= 0) return 0;
    final pct = ((p.credit - p.price) / p.price) * 100;
    return pct.isFinite ? pct.round() : 0;
  }

  _PlanTier _tierFor(SubscriptionPlanModel p, List<SubscriptionPlanModel> sorted) {
    final i = sorted.indexWhere((x) => x.id == p.id);
    if (sorted.length >= 3) {
      if (i == 0) return _PlanTier.silver;
      if (i == 1) return _PlanTier.gold;
      return _PlanTier.diamond;
    }
    if (sorted.length == 2) {
      return i == 0 ? _PlanTier.silver : _PlanTier.gold;
    }
    return _PlanTier.silver;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final arabicDigits = useArabicDigits(context);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final cust = ref.watch(customerStreamProvider);

    final remoteList = plansAsync.asData?.value ?? const <SubscriptionPlanModel>[];
    final effective = _ensureDefaultPlans(remoteList);
    final sorted = _sorted(effective);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        extraOrbs: true,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                title: l10n.navPlans,
                subtitle: l10n.subscriptionScreenSubtitle,
                pillText: cust.maybeWhen(
                  data: (c) => c == null
                      ? null
                      : '${l10n.currentSubscriptionBalancePrefix} ${formatMoneyAr(c.subscriptionBalance, arabicDigits: arabicDigits)}',
                  orElse: () => null,
                ),
                trailing: plansAsync.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _planCard(context, sorted[i], sorted),
                  ),
                  childCount: sorted.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.howToBuy,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _bullet(l10n.howToBuyStep1),
                    _bullet(l10n.howToBuyStep2),
                    _bullet(l10n.howToBuyStep3),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }

  Widget _planCard(
    BuildContext context,
    SubscriptionPlanModel p,
    List<SubscriptionPlanModel> sorted,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final arabicDigits = useArabicDigits(context);
    final langAr = Localizations.localeOf(context).languageCode == 'ar';
    final tier = _tierFor(p, sorted);
    final sel = _selectedId == p.id;
    final savePctValue = _savePct(p);
    final bonusPctValue = p.bonusPercentage?.round();
    final showPct = bonusPctValue != null && bonusPctValue > 0
        ? bonusPctValue
        : (savePctValue > 0 ? savePctValue : null);
    final pctLabel = showPct == null
        ? ''
        : '${formatIntAr(showPct, arabicDigits: arabicDigits)}%';
    final isDiamond = tier == _PlanTier.diamond;
    final isGold = tier == _PlanTier.gold;
    final isSilver = tier == _PlanTier.silver;
    final savings = p.credit - p.price;

    final accent = isDiamond
        ? AppColors.primaryDark
        : (isGold ? AppColors.gold : AppColors.primary);
    final accentSoft = accent.withValues(alpha: 0.10);

    // Glass-like surface defaults (matches global background).
    Color tint;
    Color borderC;
    if (isDiamond) {
      tint = Colors.white.withValues(alpha: 0.88);
      borderC = AppColors.primaryDark;
    } else if (isGold) {
      tint = Colors.white.withValues(alpha: 0.86);
      borderC = AppColors.gold;
    } else if (isSilver) {
      tint = Colors.white.withValues(alpha: 0.82);
      borderC = AppColors.primary.withValues(alpha: 0.65);
    } else {
      tint = Colors.white.withValues(alpha: 0.78);
      borderC = AppColors.primaryMid.withValues(alpha: 0.55);
    }

    final card = AnimatedScale(
      scale: sel ? 1.015 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedId = p.id);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: borderC.withValues(alpha: sel ? 0.35 : 0.18),
                blurRadius: sel ? 20 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Decorative blur circles for a premium feel.
              PositionedDirectional(
                top: -40,
                start: -30,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.08),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -46,
                end: -26,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.06),
                  ),
                ),
              ),
              if (isSilver)
                PositionedDirectional(
                  top: -10,
                  end: 14,
                  child: GlassCard(
                    borderRadius: 999,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    tint: AppColors.primary,
                    borderColor: AppColors.primary,
                    child: Text(
                      l10n.mostPopular,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (isGold)
                PositionedDirectional(
                  top: -10,
                  end: 14,
                  child: GlassCard(
                    borderRadius: 999,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    tint: AppColors.gold.withValues(alpha: 0.15),
                    borderColor: AppColors.gold,
                    child: Text(
                      l10n.planLabelPremium,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
              if (isDiamond)
                PositionedDirectional(
                  top: -10,
                  end: 14,
                  child: GlassCard(
                    borderRadius: 999,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    tint: AppColors.primaryDark.withValues(alpha: 0.10),
                    borderColor: AppColors.primaryDark,
                    child: Text(
                      l10n.planLabelDiamond,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                start: 12,
                top: 10,
                child: AnimatedScale(
                  scale: sel ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: isSilver || isGold || isDiamond ? 18 : 6),
                child: GlassCard(
                  borderRadius: 18,
                  padding: EdgeInsets.fromLTRB(
                    18,
                    isSilver ? 20 : 16,
                    16,
                    16,
                  ),
                  tint: tint,
                  borderColor: borderC.withValues(alpha: sel ? 0.85 : 0.55),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: accent,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _planInner(
                          context,
                          p,
                          arabicDigits,
                          langAr,
                          tier,
                          pctLabel,
                          savings,
                          accent,
                          accentSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 0),
      child: IntrinsicHeight(child: card),
    );
  }

  Widget _planInner(
    BuildContext context,
    SubscriptionPlanModel p,
    bool arabicDigits,
    bool langAr,
    _PlanTier tier,
    String pctLabel,
    double savings,
    Color accent,
    Color accentSoft,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isDiamond = tier == _PlanTier.diamond;
    final isGold = tier == _PlanTier.gold;
    final payLabel = l10n.planPayHeader;
    final getLabel = l10n.planGetHeader;

    final tierLabel = tier == _PlanTier.silver
        ? l10n.silver
        : (tier == _PlanTier.gold ? l10n.gold : l10n.planLabelDiamond);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tier == _PlanTier.silver
                        ? Icons.brightness_5_rounded
                        : (tier == _PlanTier.gold
                            ? Icons.auto_awesome_rounded
                            : Icons.diamond_rounded),
                    size: 14,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tierLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              langAr ? p.nameAr : p.name,
              textAlign: TextAlign.end,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDiamond
                    ? AppColors.primaryDark
                    : (isGold ? AppColors.gold : AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatMoneyAr(p.price, arabicDigits: arabicDigits)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                  color: accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      getLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatMoneyAr(p.credit, arabicDigits: arabicDigits)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (pctLabel.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: GlassCard(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tint: AppColors.successTint.withValues(alpha: 0.65),
              borderColor: AppColors.success.withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.savePercentLabel(pctLabel),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    ),
                  ),
                  if (savings > 0.001) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${formatMoneyAr(savings, arabicDigits: arabicDigits)}${l10n.sarSuffix}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        // (Savings amount is shown under the green Save badge.)
        ],
      ),
    );
  }

  Widget _bullet(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              t,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
