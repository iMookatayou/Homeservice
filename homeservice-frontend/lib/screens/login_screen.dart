import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _emailNode = FocusNode();
  final _pwNode = FocusNode();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  static const _primary = Color(0xFF1E3A8A);
  static const _primarySoft = Color(0xFF2563EB); 
  static const _bgSoft = Color(0xFFF3F6FF);
  static const _card = Colors.white;
  static const _textMain = Color(0xFF0B1220); 
  static const _textSub = Color(0xFF475569);
  static const _divider = Color(0xFFE5E7EB); // gray-200
  static const _fieldFill = Color(0xFFFFFFFF); // inputs white

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _emailNode.dispose();
    _pwNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref
        .read(authProvider.notifier)
        .login(_email.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      context.go('/home');
    } else {
      setState(() => _error = 'Invalid email or password');
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
                          // Logo: house inside soft circle
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE9EEFF),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              // FIX: 'houseLine' -> 'house'
                              PhosphorIconsBold.house,
                              size: 34,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Home Service 6/188',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _textMain,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to manage your home tasks and services.',
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
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 4),

                          // Email
                          TextFormField(
                            controller: _email,
                            focusNode: _emailNode,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            textInputAction: TextInputAction.next,
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
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: _input(
                              'Password',
                              prefix: const Icon(
                                PhosphorIconsBold.lockKey,
                                size: 20,
                              ),
                              suffix: IconButton(
                                tooltip: _obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? PhosphorIconsBold.eye
                                      : PhosphorIconsBold.eyeSlash,
                                  size: 20,
                                  color: _textSub,
                                ),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Please enter your password'
                                : null,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: _textMain,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => context.go('/forgot'),
                              style: TextButton.styleFrom(
                                foregroundColor: _primarySoft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _busy ? null : _submit,
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
                              child: _busy
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
                                  : const Text('Sign in'),
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

                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => context.go('/register'),
                              icon: const Icon(
                                PhosphorIconsBold.userPlus,
                                size: 18,
                              ),
                              label: Text(
                                'Create an account',
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
