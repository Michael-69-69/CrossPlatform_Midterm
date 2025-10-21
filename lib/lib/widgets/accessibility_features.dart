import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class AccessibilityFeatures {
  static Widget buildAccessibleButton({
    required Widget child,
    required VoidCallback onPressed,
    required String semanticLabel,
    String? hint,
    bool enabled = true,
  }) {
    return Semantics(
      label: semanticLabel,
      hint: hint,
      enabled: enabled,
      button: true,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
    );
  }

  static Widget buildAccessibleCard({
    required Widget child,
    required String semanticLabel,
    String? hint,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: semanticLabel,
      hint: hint,
      button: onTap != null,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }

  static Widget buildAccessibleIcon({
    required IconData icon,
    required String semanticLabel,
    double? size,
    Color? color,
  }) {
    return Semantics(
      label: semanticLabel,
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }

  static Widget buildAccessibleText({
    required String text,
    String? semanticLabel,
    TextStyle? style,
  }) {
    return Semantics(
      label: semanticLabel ?? text,
      child: Text(
        text,
        style: style,
      ),
    );
  }

  static void announceToScreenReader(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  static Widget buildFocusIndicator({
    required Widget child,
    required bool hasFocus,
    Color? focusColor,
  }) {
    return Container(
      decoration: hasFocus
          ? BoxDecoration(
              border: Border.all(
                color: focusColor ?? Colors.blue,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: child,
    );
  }

  static Widget buildHighContrastText({
    required String text,
    TextStyle? style,
    Color? backgroundColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: style?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ) ?? TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Widget buildScreenReaderOnly({
    required Widget child,
  }) {
    return Semantics(
      child: child,
      excludeSemantics: false,
    );
  }

  static Widget buildAccessibleProgressIndicator({
    required double value,
    required String semanticLabel,
    Color? color,
    Color? backgroundColor,
  }) {
    return Semantics(
      label: semanticLabel,
      value: '${(value * 100).round()}%',
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? Colors.blue),
      ),
    );
  }
}

class AccessibleScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final String? floatingActionButtonLabel;

  const AccessibleScaffold({
    Key? key,
    required this.body,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'App title: $title',
          child: Text(title),
        ),
        actions: actions,
      ),
      body: Semantics(
        label: 'Main content area',
        child: body,
      ),
      floatingActionButton: floatingActionButton != null
          ? Semantics(
              label: floatingActionButtonLabel ?? 'Floating action button',
              child: floatingActionButton!,
            )
          : null,
    );
  }
}

class AccessibleDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final String? semanticLabel;

  const AccessibleDialog({
    Key? key,
    required this.title,
    required this.content,
    required this.actions,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? 'Dialog: $title',
      child: AlertDialog(
        title: Semantics(
          label: 'Dialog title: $title',
          child: Text(title),
        ),
        content: Semantics(
          label: 'Dialog content',
          child: content,
        ),
        actions: actions.map((action) {
          return Semantics(
            label: 'Dialog action',
            child: action,
          );
        }).toList(),
      ),
    );
  }
}
