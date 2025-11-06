import 'package:flutter/material.dart';

/// Smooth page transition helper with slide animation
class SmoothPageTransition {
  /// Create a smooth slide transition from right to left
  /// Optimized duration (150ms) for snappy feel
  static Route createRoute(
    Widget page, {
    Duration duration = const Duration(milliseconds: 150),
    Offset beginOffset = const Offset(1.0, 0.0),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide transition
        var slideAnimation = Tween<Offset>(begin: beginOffset, end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
            );

        // Fade transition
        var fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeIn));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
    );
  }

  /// Navigate to a page with smooth transition
  static Future<T?> navigateTo<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(context, createRoute(page) as Route<T>);
  }

  /// Replace current page with smooth transition
  static Future<T?> navigateAndReplace<T>(BuildContext context, Widget page) {
    return Navigator.pushReplacement<T, void>(
      context,
      createRoute(page) as Route<T>,
    );
  }

  /// Navigate and remove all previous routes
  static Future<T?> navigateAndRemoveUntil<T>(
    BuildContext context,
    Widget page, {
    bool Function(Route<dynamic>)? predicate,
  }) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      createRoute(page) as Route<T>,
      predicate ?? (route) => false,
    );
  }
}
