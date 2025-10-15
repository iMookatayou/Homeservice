import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/auth_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();

  final _nameNode = FocusNode();
  final _emailNode = FocusNode();
  final _pwNode = FocusNode();
  final _pw2Node = FocusNode();

  bool _busy = false;
  bool _obscurePw = true;
  bool _obscurePw2 = true;
  String? _error;

  // ====== Palette: Deep Blue on White (same as Login) ======
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
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    _pw2.dispose();
    _nameNode.dispose();
    _emailNode.dispose();
    _pwNode.dispose();
    _pw2Node.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // NOTE: ปรับให้ตรงกับฟังก์ชันจริงใน authProvider ของคุณ
    // แนะนำให้มี register(String name, String email, String password)
    final ok = await ref
        .read(authProvider.notifier)
        .register(_name.text.trim(), _email.text.trim(), _pw.text);

    setState(() => _busy = false);
    if (!mounted) return;

    if (ok) {
      // สมัครเสร็จ: ไปหน้า home หรือจะแก้เป็น /login ก็ได้
      context.go('/home');
    } else {
      setState(() => _error = 'Unable to create account. Please try again.');
    }
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
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo/icon
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE9EEFF),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              PhosphorIconsBold.userPlus,
                              size: 34,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Create your account',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _textMain,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Join Home Service 6/188 to manage tasks and services.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              color: _textSub,
                            ),
                          ),
                          const SizedBox(height: 18),

                          if (_error != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    PhosphorIconsFill.warningCircle,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        color: const Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 4),

                          // Name
                          TextFormField(
                            controller: _name,
                            focusNode: _nameNode,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            onFieldSubmitted: (_) => _emailNode.requestFocus(),
                            decoration: _input(
                              'Full name',
                              prefix: const Icon(
                                PhosphorIconsBold.userCircle,
                                size: 20,
                              ),
                            ),
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return 'Please enter your name';
                              if (s.length < 2) {
                                return 'Name is too short';
                              }
                              return null;
                            },
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: _textMain,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Email
                          TextFormField(
                            controller: _email,
                            focusNode: _emailNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            onFieldSubmitted: (_) => _pwNode.requestFocus(),
                            decoration: _input(
                              'Email',
                              prefix: const Icon(
                                PhosphorIconsBold.envelopeSimple,
                                size: 20,
                              ),
                            ),
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return 'Please enter your email';
                              final ok = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(s);
                              if (!ok) return 'Invalid email format';
                              return null;
                            },
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: _textMain,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _pw,
                            focusNode: _pwNode,
                            obscureText: _obscurePw,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) => _pw2Node.requestFocus(),
                            decoration: _input(
                              'Password',
                              prefix: const Icon(
                                PhosphorIconsBold.lockKey,
                                size: 20,
                              ),
                              suffix: IconButton(
                                tooltip: _obscurePw
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () =>
                                    setState(() => _obscurePw = !_obscurePw),
                                icon: Icon(
                                  _obscurePw
                                      ? PhosphorIconsBold.eye
                                      : PhosphorIconsBold.eyeSlash,
                                  size: 20,
                                  color: _textSub,
                                ),
                              ),
                            ),
                            validator: (v) {
                              final s = v ?? '';
                              if (s.isEmpty) return 'Please enter a password';
                              if (s.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: _textMain,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Confirm Password
                          TextFormField(
                            controller: _pw2,
                            focusNode: _pw2Node,
                            obscureText: _obscurePw2,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: _input(
                              'Confirm password',
                              prefix: const Icon(
                                PhosphorIconsBold.lockKeyOpen,
                                size: 20,
                              ),
                              suffix: IconButton(
                                tooltip: _obscurePw2
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () =>
                                    setState(() => _obscurePw2 = !_obscurePw2),
                                icon: Icon(
                                  _obscurePw2
                                      ? PhosphorIconsBold.eye
                                      : PhosphorIconsBold.eyeSlash,
                                  size: 20,
                                  color: _textSub,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (v != _pw.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: _textMain,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Terms
                          Text(
                            'By creating an account, you agree to our Terms and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: _textSub,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Submit
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              icon: _busy
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      PhosphorIconsBold.userPlus,
                                      size: 18,
                                    ),
                              label: Text(
                                _busy ? 'Creating...' : 'Create account',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: _busy ? null : _submit,
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

                          Row(
                            children: [
                              const Expanded(child: Divider(color: _divider)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.inter(color: _textSub),
                                ),
                              ),
                              const Expanded(child: Divider(color: _divider)),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Go to Sign in
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => context.go('/login'),
                              icon: const Icon(
                                PhosphorIconsBold.signIn,
                                size: 18,
                              ),
                              label: Text(
                                'Sign in instead',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
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

                          const SizedBox(height: 6),

                          Text(
                            'We keep your information secure and private.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: _textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
