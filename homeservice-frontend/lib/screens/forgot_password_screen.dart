import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/auth_state.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _emailNode = FocusNode();

  bool _busy = false;
  bool _sent = false; // เมื่อส่งสำเร็จ จะแสดงหน้าสำเร็จ

  // ====== Palette: Deep Blue on White (matching Login) ======
  static const _primary = Color(0xFF1E3A8A); // deep indigo/blue
  static const _primarySoft = Color(0xFF2563EB); // accent blue
  static const _bgSoft = Color(0xFFF3F6FF); // very light blue background
  static const _card = Colors.white;
  static const _textMain = Color(0xFF0B1220); // near-navy
  static const _textSub = Color(0xFF475569); // slate-600
  static const _divider = Color(0xFFE5E7EB); // gray-200
  static const _fieldFill = Color(0xFFFFFFFF); // inputs white

  @override
  void dispose() {
    _email.dispose();
    _emailNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      // NOTE:
      // สร้างเมธอดนี้ใน AuthNotifier ของคุณให้คืนค่า bool:
      // Future<bool> requestPasswordReset(String email)
      final ok = await ref
          .read(authProvider.notifier)
          .requestPasswordReset(_email.text.trim());

      if (!mounted) return;
      if (ok) {
        setState(() {
          _sent = true; // แสดงหน้าสำเร็จ
          _busy = false;
        });
      } else {
        setState(() => _busy = false);
        _showError('Could not send reset email. Please try again.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.inter())));
  }

  InputDecoration _input(String label, {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      suffixIcon: suffix,
      labelStyle: GoogleFonts.inter(color: _textSub),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final pad = w > 720 ? 28.0 : 18.0;

    return Scaffold(
      backgroundColor: _bgSoft,
      appBar: AppBar(
        backgroundColor: _bgSoft,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(PhosphorIconsBold.caretLeft, color: _textMain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Forgot Password',
          style: GoogleFonts.inter(
            color: _textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _divider),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 30,
                      offset: Offset(0, 12),
                      color: Color(0x1420283A),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad + 6, pad, pad),
                  child: _sent ? _successBody() : _formBody(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formBody() {
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo / Header
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE9EEFF),
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsBold.envelopeSimple,
                size: 34,
                color: _primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Reset your password',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textMain,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your email address and we’ll send you a reset link.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13.5, color: _textSub),
            ),
            const SizedBox(height: 18),

            // Email
            TextFormField(
              controller: _email,
              focusNode: _emailNode,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: _input(
                'Email',
                prefix: const Icon(PhosphorIconsBold.envelopeSimple, size: 20),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Please enter your email';
                final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
                if (!ok) return 'Invalid email format';
                return null;
              },
              style: GoogleFonts.inter(fontSize: 15, color: _textMain),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(PhosphorIconsBold.paperPlaneTilt, size: 18),
                label: Text(
                  _busy ? 'Sending...' : 'Send reset link',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextButton.icon(
              onPressed: _busy ? null : () => context.go('/login'),
              icon: const Icon(PhosphorIconsBold.arrowLeft),
              style: TextButton.styleFrom(foregroundColor: _primarySoft),
              label: Text(
                'Back to sign in',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _successBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE9EEFF),
          ),
          alignment: Alignment.center,
          child: const Icon(
            PhosphorIconsBold.checkCircle,
            size: 38,
            color: _primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Check your inbox',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _textMain,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'We’ve sent a password reset link to your email.\nIf you don’t see it, check your spam folder.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: _textSub,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => context.go('/login'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Back to sign in'),
          ),
        ),

        const SizedBox(height: 10),

        // ปุ่มลองส่งอีกครั้ง (resend)
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(PhosphorIconsBold.arrowCounterClockwise, size: 18),
            label: Text(
              _busy ? 'Sending...' : 'Resend link',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
