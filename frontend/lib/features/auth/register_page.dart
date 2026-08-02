import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../models/user.dart';

/// RegisterPage - 注册页面
/// 手机号+验证码+密码+昵称，含验证码倒计时功能
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreeTerms = false;

  // 验证码倒计时
  int _countdown = 0;
  bool _isSendingSms = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _smsController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  /// 开始倒计时
  void _startCountdown() {
    setState(() {
      _countdown = AppConstants.smsCountdown;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (_countdown > 0 && mounted) {
        setState(() {
          _countdown--;
        });
        _startCountdown();
      }
    });
  }

  /// 发送验证码
  Future<void> _sendSms() async {
    if (_phoneController.text.isEmpty ||
        !RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入正确的手机号'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isSendingSms = true;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        '/auth/sms/send',
        data: {'phone': _phoneController.text.trim()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('验证码已发送'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送失败: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingSms = false;
        });
      }
    }
  }

  /// 执行注册
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请同意用户协议和隐私政策'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
          phone: _phoneController.text.trim(),
          verificationCode: _smsController.text.trim(),
          password: _passwordController.text,
          nickname: _nicknameController.text.trim(),
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('注册成功'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      context.go('/main/timeline');
    } else if (mounted) {
      final errMsg = ref.read(authProvider).errorMessage ?? '注册失败';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('注册账号'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // 手机号
                _buildPhoneField(),
                const SizedBox(height: 16),
                // 验证码
                _buildSmsField(),
                const SizedBox(height: 16),
                // 密码
                _buildPasswordField(),
                const SizedBox(height: 16),
                // 昵称
                _buildNicknameField(),
                const SizedBox(height: 20),
                // 用户协议
                _buildAgreement(),
                const SizedBox(height: 32),
                // 注册按钮
                _buildRegisterButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: '手机号',
        hintText: '请输入手机号',
        prefixIcon: Icon(Icons.phone_outlined),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入手机号';
        }
        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
          return '请输入正确的手机号';
        }
        return null;
      },
    );
  }

  Widget _buildSmsField() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _smsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '验证码',
              hintText: '请输入验证码',
              prefixIcon: Icon(Icons.sms_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入验证码';
              }
              if (value.length != AppConstants.smsLength) {
                return '验证码为${AppConstants.smsLength}位';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _countdown > 0 || _isSendingSms ? null : _sendSms,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bg2,
              foregroundColor: AppTheme.accent,
              elevation: 0,
            ),
            child: Text(
              _countdown > 0 ? '${_countdown}s' : '获取验证码',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请设置密码（至少6位）',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword
              ? Icons.visibility_off
              : Icons.visibility),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请设置密码';
        }
        if (value.length < 6) {
          return '密码至少6位';
        }
        return null;
      },
    );
  }

  Widget _buildNicknameField() {
    return TextFormField(
      controller: _nicknameController,
      decoration: const InputDecoration(
        labelText: '昵称',
        hintText: '请输入昵称',
        prefixIcon: Icon(Icons.person_outline),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入昵称';
        }
        if (value.length > 20) {
          return '昵称最多20个字符';
        }
        return null;
      },
    );
  }

  Widget _buildAgreement() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreeTerms,
          onChanged: (value) {
            setState(() {
              _agreeTerms = value ?? false;
            });
          },
          activeColor: AppTheme.accent,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _agreeTerms = !_agreeTerms;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text.rich(
                TextSpan(
                  text: '我已阅读并同意',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.muted,
                    fontFamily: 'NotoSansSC',
                  ),
                  children: [
                    TextSpan(
                      text: '《用户协议》',
                      style: TextStyle(
                        color: AppTheme.accent,
                      ),
                    ),
                    TextSpan(text: '和'),
                    TextSpan(
                      text: '《隐私政策》',
                      style: TextStyle(
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _handleRegister,
        child: const Text('注册'),
      ),
    );
  }
}
