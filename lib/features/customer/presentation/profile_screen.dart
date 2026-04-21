import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/formatting/arabic_numbers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/context_l10n.dart';
import '../../../shared/widgets/animated_bg.dart';
import '../../../shared/widgets/app_language_selector.dart';
import '../../../shared/widgets/app_logo_loader.dart';
import '../../../shared/widgets/biometric_toggle.dart';
import '../../../shared/widgets/gradient_header.dart';
import 'providers/customer_providers.dart';

const _kNotifPref = 'notifications_enabled';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notif = true;

  String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
  }

  Widget _sectionTitle(BuildContext context, String t) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          t,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget value,
    VoidCallback? onTap,
  }) {
    final row = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              value,
            ],
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textHint.withValues(alpha: 0.9)),
        ],
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: row,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final p = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _notif = p.getBool(_kNotifPref) ?? true);
      }
    });
  }

  Future<void> _pickAndUpload(String customerId) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    final file = File(x.path);
    setState(() {});
    try {
      final repo = ref.read(customerRepositoryProvider);
      final url = await repo.uploadAvatarFile(customerId: customerId, file: file);
      await repo.updateCustomer(customerId, {kCustomersAvatarUrl: url});
      ref.invalidate(customerStreamProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _editName(String customerId, String current) async {
    final ctl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();
        final dl = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(
            dl.registerYourName,
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: ctl,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              enableSuggestions: true,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: dl.registerFullNameHint,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return dl.nameRequired;
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(dl.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(ctx, ctl.text.trim());
              },
              child: Text(dl.save),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    await ref.read(customerRepositoryProvider).updateCustomer(customerId, {kCustomersName: name});
    ref.invalidate(customerStreamProvider);
  }

  Future<void> _pickBirthday(String customerId, DateTime? current) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (d == null) return;
    await ref.read(customerRepositoryProvider).updateCustomer(customerId, {
      kCustomersBirthday: d.toIso8601String().split('T').first,
    });
    ref.invalidate(customerStreamProvider);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kLoginModePrefKey);
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(currentCustomerIdProvider);
    ref.invalidate(customerStreamProvider);
    if (mounted) context.go('/auth/phone');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final arabicDigits = useArabicDigits(context);
    final cust = ref.watch(customerStreamProvider);
    final stats = ref.watch(referralStatsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        extraOrbs: true,
        child: cust.when(
        loading: () => const Center(child: AppLogoLoader(size: 120, background: Colors.white)),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: AppColors.textPrimary))),
        data: (c) {
          if (c == null) {
            return Center(child: Text(l10n.error));
          }
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: GradientHeader(
                  title: l10n.profile,
                  subtitle: l10n.accountSettingsSubtitle,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 38,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.16),
                                    child: ClipOval(
                                      child: c.avatarUrl != null &&
                                              c.avatarUrl!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: c.avatarUrl!,
                                              width: 76,
                                              height: 76,
                                              fit: BoxFit.cover,
                                              memCacheWidth: 152,
                                              memCacheHeight: 152,
                                            )
                                          : Text(
                                              _initial(c.name),
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                    ),
                                  ),
                                  PositionedDirectional(
                                    bottom: -6,
                                    end: -6,
                                    child: Material(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => _pickAndUpload(c.id),
                                        child: const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _editName(c.id, c.name),
                                          icon: const Icon(
                                            Icons.edit_note_rounded,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      l10n.tapToEditName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      _sectionTitle(
                        context,
                        l10n.sectionInformation,
                      ),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _infoRow(
                              context: context,
                              icon: Icons.phone_iphone_rounded,
                              title: l10n.phoneLabelShort,
                              value: Text(
                                c.phone,
                                textDirection: TextDirection.ltr,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Divider(height: 1, color: AppColors.border),
                            _infoRow(
                              context: context,
                              icon: Icons.cake_outlined,
                              title: l10n.birthday,
                              value: Text(
                                c.birthday == null
                                    ? '—'
                                    : '${c.birthday!.year}-${c.birthday!.month}-${c.birthday!.day}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              onTap: () => _pickBirthday(c.id, c.birthday),
                            ),
                            Divider(height: 1, color: AppColors.border),
                            ListTile(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.push('/customer/branch');
                              },
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.store_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                l10n.contactUsTitle,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                l10n.contactUsSubtitle,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.textHint,
                              ),
                            ),
                            Divider(height: 1, color: AppColors.border),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
                              child: AppLanguageSelector(
                                onLanguageApplied: (code) async {
                                  await ref
                                      .read(customerRepositoryProvider)
                                      .updateCustomer(c.id, {
                                    kCustomersPreferredLanguage: code,
                                  });
                                  ref.invalidate(customerStreamProvider);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      _sectionTitle(
                        context,
                        l10n.referralCode,
                      ),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SelectableText(
                                c.referralCode ?? '—',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final code = c.referralCode ?? '';
                                  Share.share(
                                    l10n.referralShare(code),
                                  );
                                },
                                icon: const Icon(Icons.share),
                                label: Text(l10n.share),
                              ),
                              const SizedBox(height: 10),
                              stats.when(
                                data: (s) => Text(
                                  '${l10n.referredCount(s.referredPeople)} — ${l10n.youEarned(formatMoneyAr(s.referralEarnings, arabicDigits: arabicDigits))}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      _sectionTitle(context, l10n.sectionPreferences),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            const BiometricToggle(),
                            Divider(height: 1, color: AppColors.border),
                            SwitchListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              title: Text(
                                l10n.notifications,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              value: _notif,
                              onChanged: (v) async {
                                setState(() => _notif = v);
                                final p = await SharedPreferences.getInstance();
                                await p.setBool(_kNotifPref, v);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _logout,
                        child: Text(l10n.logout),
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
}
