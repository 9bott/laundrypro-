import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/biometric_service.dart';
import '../../../shared/widgets/app_logo_loader.dart';
import 'providers/customer_providers.dart';

const _kNotifPref = 'notifications_enabled';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

  bool _notif = true;
  bool _bioAvailChecked = false;
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final p = await SharedPreferences.getInstance();
      final notif = p.getBool(_kNotifPref) ?? true;
      final avail = await BiometricService.isAvailable();
      final enabled = await BiometricService.isEnabled();
      if (!mounted) return;
      setState(() {
        _notif = notif;
        _bioAvailChecked = true;
        _bioAvailable = avail;
        _bioEnabled = enabled;
      });
    });
  }

  Future<void> _pickAndUpload(String customerId) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    final file = File(x.path);
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
        return AlertDialog(
          title: const Text('تعديل الاسم'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: ctl,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'اكتب اسمك'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'الاسم مطلوب';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(ctx, ctl.text.trim());
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
    ctl.dispose();
    if (name == null || name.isEmpty) return;
    await ref.read(customerRepositoryProvider).updateCustomer(
      customerId,
      {kCustomersName: name},
    );
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\\s+'));
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts[0].isEmpty ? '؟' : parts[0][0].toUpperCase();
    final a = parts.first.isEmpty ? '' : parts.first[0];
    final b = parts.last.isEmpty ? '' : parts.last[0];
    final r = '$a$b';
    return r.isEmpty ? '؟' : r.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cust = ref.watch(customerStreamProvider);

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kPageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: cust.when(
        loading: () => const Center(
          child: AppLogoLoader(size: 120, background: Colors.white),
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (c) {
          if (c == null) {
            return const Center(child: Text('تعذر تحميل البيانات'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: _kPointBlue,
                          child: Text(
                            _initials(c.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: -4,
                          end: -4,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: () => _pickAndUpload(c.id),
                              icon: const Icon(Icons.camera_alt_rounded, color: _kPointBlue),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _editName(c.id, c.name),
                          icon: const Icon(Icons.edit_rounded, color: _kPointBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          c.phone,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    if (_bioAvailChecked && _bioAvailable) ...[
                      _SettingsRowSwitch(
                        icon: Icons.face_retouching_natural_rounded,
                        title: 'Face ID / البصمة',
                        value: _bioEnabled,
                        onChanged: (v) async {
                          if (v) {
                            final ok = await BiometricService.authenticate();
                            if (!ok) return;
                          }
                          await BiometricService.setEnabled(v);
                          if (!mounted) return;
                          setState(() => _bioEnabled = v);
                        },
                      ),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                    ],
                    _SettingsRowSwitch(
                      icon: Icons.notifications_rounded,
                      title: 'الإشعارات',
                      value: _notif,
                      onChanged: (v) async {
                        setState(() => _notif = v);
                        final p = await SharedPreferences.getInstance();
                        await p.setBool(_kNotifPref, v);
                      },
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                    _SettingsRowNav(
                      icon: Icons.store_rounded,
                      title: 'متاجري',
                      onTap: () => context.push('/customer/my-stores'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _logout,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsRowSwitch extends StatelessWidget {
  const _SettingsRowSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF185FA5)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _SettingsRowNav extends StatelessWidget {
  const _SettingsRowNav({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF185FA5)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
    );
  }
}
