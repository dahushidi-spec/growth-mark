import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';

/// LoginPage - 登录页面
/// 手机号+密码登录，提供跳转注册入口
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 表单校验
  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    return true;
  }

  /// 执行登录
  Future<void> _handleLogin() async {
    if (!_validateForm()) return;

    final success = await ref.read(authProvider.notifier).login(
          _phoneController.text.trim(),
          _passwordController.text,
        );

    if (success && mounted) {
      context.go('/main/timeline');
    } else if (mounted) {
      // 登录失败，显示错误提示
      final errorMsg = ref.read(authProvider).errorMessage ?? '登录失败';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // Logo和标题
                _buildHeader(),
                const SizedBox(height: 48),
                // 手机号输入框
                _buildPhoneField(),
                const SizedBox(height: 16),
                // 密码输入框
                _buildPasswordField(),
                const SizedBox(height: 12),
                // 忘记密码
                _buildForgotPassword(),
                const SizedBox(height: 32),
                // 登录按钮
                _buildLoginButton(authState.isLoading),
                const SizedBox(height: 24),
                // 分隔线
                _buildDivider(),
                const SizedBox(height: 24),
                // 注册链接
                _buildRegisterLink(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 头部Logo和标题
  Widget _buildHeader() {
    return Column(
      children: [
        // Logo圆形图标
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.accentLight, AppTheme.accent],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.child_care,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppConstants.appName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansSC',
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppConstants.appSlogan,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'NotoSansSC',
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }

  /// 手机号输入框
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

  /// 密码输入框
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请输入密码',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入密码';
        }
        if (value.length < 6) {
          return '密码至少6位';
        }
        return null;
      },
    );
  }

  /// 忘记密码
  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          // TODO: 跳转忘记密码页面
        },
        child: const Text('忘记密码？'),
      ),
    );
  }

  /// 登录按钮
  Widget _buildLoginButton(bool isLoading) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleLogin,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('登录'),
      ),
    );
  }

  /// 分隔线
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.rule)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '或',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.muted,
              fontFamily: 'NotoSansSC',
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.rule)),
      ],
    );
  }

  /// 注册链接
  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '还没有账号？',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.muted,
            fontFamily: 'NotoSansSC',
          ),
        ),
        GestureDetector(
          onTap: () => context.go('/register'),
          child: Text(
            '立即注册',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
              fontFamily: 'NotoSansSC',
            ),
          ),
        ),
      ],
    );
  }
}
