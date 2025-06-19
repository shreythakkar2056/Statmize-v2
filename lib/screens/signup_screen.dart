import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback? onSkip;
  const SignupScreen({super.key, this.onSkip});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool agree = false;
  String selectedSport = 'Cricket';

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
                                  ? Colors.white.withOpacity(0.15)
                                  : Theme.of(context).colorScheme.primary.withOpacity(0.12),
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
                      'Get Started',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account to start training',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Full Name
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Full Name',
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
                    // Email
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined),
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
                    // Phone
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: 'Phone Number',
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
                    // Password
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline),
                        hintText: 'Password',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF232323) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        suffixIcon: Icon(Icons.visibility_off_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Confirm Password
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline),
                        hintText: 'Confirm Password',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF232323) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        suffixIcon: Icon(Icons.visibility_off_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Terms and Policy
                    Row(
                      children: [
                        Checkbox(
                          value: agree,
                          onChanged: (val) => setState(() => agree = val ?? false),
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                        Flexible(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                                  // Add gesture recognizer if needed
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Create Account button (matches Sign In theme)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: isDark ? const Color(0xFFEFEDE6) : const Color(0xFF0A0E25),
                          foregroundColor: isDark ? const Color(0xFF0A0E25) : Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF0A0E25) : Colors.white,
                          ),
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
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                          'Already have an account? ',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sportTab(BuildContext context, String label, bool isSelected, IconData icon, Color iconColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => selectedSport = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue.shade700 : Colors.blue.shade50)
              : (isDark ? Colors.transparent : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 