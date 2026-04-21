import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/context_l10n.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/widgets/animated_bg.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_language_selector.dart';
import '../../../shared/widgets/app_logo_loader.dart';
import '../../../shared/widgets/biometric_toggle.dart';
import '../../../shared/widgets/glass_card.dart';
import 'providers/staff_providers.dart';

class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final staffAsync = ref.watch(staffMemberProvider);

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: staffAsync.when(
            loading: () => const Center(child: AppLogoLoader(size: 120, background: Colors.white)),
            error: (e, _) => Center(child: Text('$e')),
            data: (staff) {
              if (staff == null) {
                return Center(
                  child: Text(
                    l10n.error,
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
                  ),
                );
              }
              final r = staff.role.toLowerCase();
              final roleLabel = (r == 'owner' || r == 'manager')
                  ? l10n.roleManager
                  : l10n.roleStaffMember;

              final branchLabel = staff.branch.trim().isEmpty
                  ? l10n.mainBranch
                  : staff.branch;

              final roleValue = r == 'owner'
                  ? l10n.roleOwnerLabel
                  : r == 'manager'
                      ? l10n.roleManager
                      : l10n.roleStaffMember;

              final activeLabel =
                  staff.isActive ? l10n.statusActive : l10n.statusInactive;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Text(
                    l10n.tabStore,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          staff.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          staff.phone,
                          textDirection: TextDirection.ltr,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (r == 'owner' || r == 'manager')
                                  ? AppColors.goldTint
                                  : AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (r == 'owner' || r == 'manager')
                                    ? AppColors.gold.withValues(alpha: 0.35)
                                    : AppColors.primaryBorder,
                              ),
                            ),
                            child: Text(
                              roleLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: (r == 'owner' || r == 'manager')
                                    ? AppColors.gold
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: EdgeInsets.zero,
                    radius: 16,
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.person_rounded,
                          label: l10n.name,
                          value: staff.name,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _InfoTile(
                          icon: Icons.phone_rounded,
                          label: l10n.mobilePhone,
                          value: staff.phone,
                          ltrValue: true,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _InfoTile(
                          icon: Icons.store_rounded,
                          label: l10n.branchLabel,
                          value: branchLabel,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _InfoTile(
                          icon: Icons.badge_rounded,
                          label: l10n.roleField,
                          value: roleValue,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _InfoTile(
                          icon: Icons.verified_rounded,
                          label: l10n.statusField,
                          value: activeLabel,
                          valueColor:
                              staff.isActive ? AppColors.success : AppColors.error,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      child: AppLanguageSelector(dense: true),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: const BiometricToggle(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () async {
                      staffHaptic();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove(kLoginModePrefKey);
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go('/auth/phone');
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(l10n.logout),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.ltrValue = false,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ltrValue;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  textDirection: ltrValue ? TextDirection.ltr : null,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
