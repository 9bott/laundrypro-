import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/offline_pending_provider.dart';
import '../../../l10n/context_l10n.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/app_logo_loader.dart';
import '../data/staff_repository.dart';
import 'providers/staff_providers.dart';

/// شل موحّد: المالك/المدير يرى 5 تبويبات، الموظف 3 (نفس الفروع 0،1،4).
class UnifiedStaffShell extends ConsumerStatefulWidget {
  const UnifiedStaffShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _iconsStaff = [
    Icons.qr_code_scanner_outlined,
    Icons.receipt_long_outlined,
    Icons.person_outline,
  ];
  static const _iconsMgr = [
    Icons.qr_code_scanner_outlined,
    Icons.receipt_long_outlined,
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.person_outline,
  ];

  static const _staffBranchBySlot = [0, 1, 4];

  @override
  ConsumerState<UnifiedStaffShell> createState() => _UnifiedStaffShellState();
}

class _UnifiedStaffShellState extends ConsumerState<UnifiedStaffShell> {
  bool _isManager(StaffMember? m) {
    final r = (m?.role ?? 'staff').toLowerCase();
    return r == 'owner' || r == 'manager';
  }

  int? _navSlotForBranch(int branch, bool isMgr) {
    if (isMgr) {
      return branch >= 0 && branch < 5 ? branch : null;
    }
    switch (branch) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 4:
        return 2;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    ref.listen(staffMemberProvider, (prev, next) {
      next.whenData((member) {
        if (!_isManager(member)) {
          final idx = navigationShell.currentIndex;
          if (idx == 2 || idx == 3) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) navigationShell.goBranch(0);
            });
          }
        }
      });
    });

    final staffAsync = ref.watch(staffMemberProvider);
    final isMgr = staffAsync.maybeWhen(data: _isManager, orElse: () => false);
    final l10n = context.l10n;
    final labelsStaff = [
      l10n.tabScanner,
      l10n.transactions,
      l10n.tabStore,
    ];
    final labelsMgr = [
      l10n.tabScanner,
      l10n.transactions,
      l10n.dashboard,
      l10n.customersTitle,
      l10n.tabStore,
    ];
    final n = isMgr ? 5 : 3;
    final selBranch = navigationShell.currentIndex;
    final selSlot = _navSlotForBranch(selBranch, isMgr);
    ref.watch(offlinePendingCountProvider);

    final loadingGuard =
        staffAsync.isLoading && (selBranch == 2 || selBranch == 3);

    return OfflineBanner(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: loadingGuard
            ? const Center(child: AppLogoLoader(size: 120, background: Colors.white))
            : navigationShell,
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.primaryBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: List.generate(n, (i) {
                  final on = selSlot == i;
                  final icon = isMgr ? UnifiedStaffShell._iconsMgr[i] : UnifiedStaffShell._iconsStaff[i];
                  final label = isMgr ? labelsMgr[i] : labelsStaff[i];
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final branch =
                            isMgr ? i : UnifiedStaffShell._staffBranchBySlot[i];
                        navigationShell.goBranch(branch);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: on ? AppColors.primaryTint : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: on
                                      ? AppColors.primaryMid.withValues(alpha: 0.35)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: on ? AppColors.primaryDark : AppColors.textHint,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: on
                                    ? AppColors.primaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
