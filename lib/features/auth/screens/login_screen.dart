import 'package:flutter/material.dart';

import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/auth/services/auth_service.dart';
import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/screens/auth_gate.dart';
import 'package:mp_agency/features/auth/screens/signup_screen.dart';
import 'package:mp_agency/core/widgets/brand_header.dart';
import 'package:mp_agency/features/auth/widgets/role_selector.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  UserRole _role = UserRole.customer;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.signIn(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
        expectedRole: _role,
      );
      if (!mounted) return;
      goHome(context, user);
    } catch (e) {
      if (mounted) showSnack(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (!emailRegex.hasMatch(email)) {
      showSnack(context, '비밀번호를 찾을 이메일을 먼저 입력해 주세요.');
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) showSnack(context, '비밀번호 재설정 메일을 보냈습니다.');
    } catch (e) {
      if (mounted) showSnack(context, authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(),
                    const SizedBox(height: 36),
                    RoleSelector(
                      value: _role,
                      onChanged: (r) => setState(() => _role = r),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) => emailRegex.hasMatch(v?.trim() ?? '')
                          ? null
                          : '올바른 이메일을 입력해 주세요',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pwCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _loading ? null : _login(),
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '비밀번호를 입력해 주세요' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        child: const Text(
                          '비밀번호를 잊으셨나요?',
                          style: TextStyle(color: AppColors.subText),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text('${_role.label}로 로그인'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '아직 회원이 아니신가요?',
                          style: TextStyle(color: AppColors.subText),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SignupScreen(initialRole: _role),
                                  ),
                                ),
                          child: const Text(
                            '회원가입',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
