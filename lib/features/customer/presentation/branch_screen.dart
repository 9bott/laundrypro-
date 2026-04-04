import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/animated_bg.dart';

class BranchScreen extends ConsumerWidget {
  const BranchScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchBranches() async {
    final res = await Supabase.instance.client
        .from('branches')
        .select()
        .eq('is_active', true)
        .order('created_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.contactUsTitle,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: AnimatedBackground(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchBranches(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final branches = snapshot.data ?? const <Map<String, dynamic>>[];

            if (branches.isEmpty) {
              return Center(
                child: Text(
                  l10n.branchesEmpty,
                  style: GoogleFonts.cairo(color: AppColors.textSecondary),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: branches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final branch = branches[index];
                return _BranchCard(branch: branch);
              },
            );
          },
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  const _BranchCard({required this.branch});

  Future<List<Map<String, dynamic>>> _fetchStaffForBranch(String branchName) async {
    final res = await Supabase.instance.client
        .from('staff')
        .select('name, phone, branch, role')
        .eq('is_active', true)
        .eq('branch', branchName)
        .order('name');
    return (res as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = langAr
        ? (branch['name_ar'] ?? branch['name'])
        : (branch['name'] ?? branch['name_ar']);
    final address = langAr
        ? (branch['address_ar'] ?? branch['address'])
        : (branch['address'] ?? branch['address_ar']);
    final phone = branch['phone'] as String?;
    final whatsapp = branch['whatsapp'] as String?;
    final branchName = (branch['name'] ?? branch['name_ar'] ?? '').toString().trim();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.blueGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.store_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (name ?? '').toString(),
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (address != null)
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    iconColor: AppColors.error,
                    label: l10n.addressLabel,
                    value: address.toString(),
                  ),
                if (address != null) const SizedBox(height: 12),
                if (phone != null)
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    iconColor: AppColors.success,
                    label: l10n.phoneLabelShort,
                    value: phone,
                    onTap: () => launchUrl(Uri.parse('tel:$phone')),
                  ),
                if (phone != null) const SizedBox(height: 12),
                if (whatsapp != null)
                  _InfoRow(
                    icon: Icons.chat_rounded,
                    iconColor: const Color(0xFF25D366),
                    label: l10n.whatsappLabel,
                    value: whatsapp,
                    onTap: () => launchUrl(
                      Uri.parse(
                        'https://wa.me/${whatsapp.replaceAll('+', '')}',
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (phone != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            launchUrl(Uri.parse('tel:$phone'));
                          },
                          icon: const Icon(Icons.phone_rounded, size: 18),
                          label: Text(
                            l10n.callAction,
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (phone != null && whatsapp != null)
                      const SizedBox(width: 10),
                    if (whatsapp != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            launchUrl(
                              Uri.parse(
                                'https://wa.me/${whatsapp.replaceAll('+', '')}',
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          label: Text(
                            l10n.whatsappAction,
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),

                if (branchName.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchStaffForBranch(branchName),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final staffList =
                          snapshot.data ?? const <Map<String, dynamic>>[];
                      if (staffList.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              l10n.teamSectionTitle,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...staffList.map((staff) {
                          final staffName = (staff['name'] ?? '').toString();
                          final role = (staff['role'] ?? '').toString();
                          final roleLabel = role == 'owner'
                              ? l10n.roleOwnerLabel
                              : role == 'manager'
                                  ? l10n.roleManager
                                  : l10n.roleStaffMember;
                          final staffPhone = staff['phone']?.toString();
                          final initial = staffName.trim().isNotEmpty
                              ? staffName.trim().characters.first
                              : '؟';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primaryBorder,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      initial,
                                      style: GoogleFonts.cairo(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        staffName,
                                        style: GoogleFonts.cairo(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        roleLabel,
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (staffPhone != null &&
                                    staffPhone.trim().isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      launchUrl(
                                        Uri.parse('tel:$staffPhone'),
                                      );
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.successTint,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.phone_rounded,
                                        color: AppColors.success,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
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
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        onTap != null ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textHint,
            ),
        ],
      ),
    );
  }
}

