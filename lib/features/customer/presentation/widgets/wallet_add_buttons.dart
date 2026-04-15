import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../l10n/context_l10n.dart';
import '../providers/customer_providers.dart';

/// أزرار إضافة البطاقة إلى Google / Apple Wallet (مشتركة بين الشاشة الرئيسية وشاشة المحفظة).
class WalletAddButtons extends ConsumerStatefulWidget {
  const WalletAddButtons({
    super.key,
    this.compact = false,
  });

  /// مسافات أصغر تحت الباركود في الصفحة الرئيسية.
  final bool compact;

  @override
  ConsumerState<WalletAddButtons> createState() => _WalletAddButtonsState();
}

class _WalletAddButtonsState extends ConsumerState<WalletAddButtons> {
  bool _busyGoogle = false;
  bool _busyApple = false;

  static Widget _brandedIcon(String assetPath, {double size = 26}) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Icon(Icons.wallet_outlined, size: size),
    );
  }

  Future<void> _addToGoogleWallet(BuildContext context) async {
    if (_busyGoogle) return;
    setState(() => _busyGoogle = true);
    try {
      final map =
          await ref.read(customerRepositoryProvider).invokeGeneratePasskitWalletUrls();
      final landingUrl = map['landingUrl'] as String?;
      if (landingUrl == null || landingUrl.isEmpty) {
        throw Exception('passkit_landing_url_missing');
      }
      if (kDebugMode) debugPrint('Google Wallet (PassKit) URL: $landingUrl');
      final ok = await launchUrl(
        Uri.parse(landingUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.walletOpenFailed)),
        );
      }
    } catch (e) {
      debugPrint('Google Wallet error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.walletAddFailed}\n$e'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyGoogle = false);
    }
  }

  bool get _useApplePkPass {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _addToAppleWallet(BuildContext context) async {
    if (_busyApple) return;
    setState(() => _busyApple = true);
    try {
      final map =
          await ref.read(customerRepositoryProvider).invokeGeneratePasskitWalletUrls();
      final applePassUrl = map['applePassUrl'] as String?;
      final landingUrl = map['landingUrl'] as String?;
      if (applePassUrl == null || applePassUrl.isEmpty) {
        throw Exception('passkit_apple_url_missing');
      }
      final uri = Uri.parse(
        _useApplePkPass ? applePassUrl : (landingUrl ?? applePassUrl),
      );
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.walletOpenFailed)),
        );
      }
    } catch (e) {
      debugPrint('PassKit / Apple Wallet error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.walletAddFailed}\n$e'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyApple = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gap = widget.compact ? 10.0 : 12.0;
    final top = widget.compact ? 4.0 : 0.0;

    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.compact ? 48 : 52,
            child: ElevatedButton.icon(
              onPressed:
                  _busyGoogle ? null : () => _addToGoogleWallet(context),
              icon: _busyGoogle
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _brandedIcon(AppAssets.googleWalletIcon),
              label: Text(
                l10n.addToGoogleWallet,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: widget.compact ? 13 : 14,
                ),
              ),
            ),
          ),
          SizedBox(height: gap),
          SizedBox(
            height: widget.compact ? 48 : 52,
            child: OutlinedButton.icon(
              onPressed: _busyApple ? null : () => _addToAppleWallet(context),
              icon: _busyApple
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _brandedIcon(AppAssets.appleWalletIcon),
              label: Text(
                l10n.addToAppleWallet,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: widget.compact ? 13 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
