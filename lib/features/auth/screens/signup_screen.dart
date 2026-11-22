import 'package:flutter/material.dart';

import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/auth/services/auth_service.dart';
import 'package:mp_agency/features/auth/screens/auth_gate.dart';
import 'package:mp_agency/features/auth/widgets/role_selector.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.initialRole = UserRole.customer});

  final UserRole initialRole;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  late UserRole _role = widget.initialRole;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [
      _emailCtrl,
      _pwCtrl,
      _pw2Ctrl,
      _nicknameCtrl,
      _storeCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final profile = await AuthService.instance.signUp(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
        nickname: _nicknameCtrl.text.trim(),
        role: _role,
        storeName: _storeCtrl.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, '가입 완료! 이제 같이 다먹어요 🍽️');
      goHome(context, profile);
    } catch (e) {
      if (mounted) showSnack(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label을(를) 입력해 주세요' : null;

  @override
  Widget build(BuildContext context) {
    final isSeller = _role == UserRole.seller;
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '어떤 회원으로 가입할까요?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RoleSelector(
                      value: _role,
                      onChanged: (r) => setState(() => _role = r),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
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
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '비밀번호 (6자 이상)',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? '비밀번호는 6자 이상이어야 합니다'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pw2Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '비밀번호 확인',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) =>
                          v != _pwCtrl.text ? '비밀번호가 일치하지 않습니다' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nicknameCtrl,
                      maxLength: 20,
                      decoration: InputDecoration(
                        labelText: isSeller ? '대표자 이름' : '닉네임',
                        prefixIcon: const Icon(Icons.person_outline),
                        counterText: '',
                      ),
                      validator: (v) =>
                          _required(v, isSeller ? '대표자 이름' : '닉네임'),
                    ),
                    if (isSeller) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _storeCtrl,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          labelText: '매장명',
                          hintText: '예) OO베이커리',
                          prefixIcon: Icon(Icons.storefront_outlined),
                          counterText: '',
                        ),
                        validator: (v) => _required(v, '매장명'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _signup,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text('${_role.label}로 가입하기'),
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
