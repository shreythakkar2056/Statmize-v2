import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:app/screens/signup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onSkip;
  const LoginScreen({super.key, this.onSkip});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  bool _passwordObscured = true;
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
        if (e.message.toLowerCase().contains('invalid login credentials')) {
          //ask user to sign up
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Not registered yet?'),
                content: const Text('This email is not registered. Please create an account to continue.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    child: const Text('Sign Up'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: TextField(
            controller: _resetEmailController,
            decoration: const InputDecoration(hintText: "Enter your email"),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Send Reset Link'),
              onPressed: () async {
                try {
                  await supabase.auth.resetPasswordForEmail(
                    _resetEmailController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset link sent. Please check your email.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } on AuthException catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.message),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('An unexpected error occurred: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    // Logo with subtle glow (rounded square)
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.white.withAlpha(38)
                                  : Theme.of(context).colorScheme.primary.withAlpha(31),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue your training journey',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        hintText: 'Email Address',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF232323) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _passwordObscured,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'Password',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF232323) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        suffixIcon: IconButton(
                          icon: Icon(_passwordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () {
                            setState(() {
                              _passwordObscured = !_passwordObscured;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text('Forgot Password?'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                   const SizedBox(height: 8),
                    // Sign In button (matches Start Session theme)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: isDark ? const Color(0xFFEFEDE6) : const Color(0xFF0A0E25),
                          foregroundColor: isDark ? const Color(0xFF0A0E25) : Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 12),
                                  Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF0A0E25) : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            'Or continue with',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Apple button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: Icon(
                          Icons.apple,
                          size: 26,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        label: const Text('Continue with Apple'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          side: BorderSide(color: Theme.of(context).dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Google button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          side: BorderSide(color: Theme.of(context).dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Make sure this asset is included in pubspec.yaml
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Image.asset('assets/icon/google_g.png'),
                            ),
                            const SizedBox(width: 10),
                            const Text('Continue with Google'),
                          ],
                        ),
                      ),
                    ),
                   
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => SignupScreen(
                                  onSkip: widget.onSkip,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Skip button (top right)
            Positioned(
              top: 12,
              right: 12,
              child: TextButton(
                onPressed: widget.onSkip,
                child: const Text('Skip'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // Back button (top left)
            Positioned(
              top: 12,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 