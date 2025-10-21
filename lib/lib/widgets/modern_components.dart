import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const ModernCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Card(
        elevation: elevation ?? 0,
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: Padding(
            padding: padding ?? EdgeInsets.all(16),
            child: Semantics(
              label: semanticLabel,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final List<Color>? gradientColors;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  const GradientButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.gradientColors,
    this.borderRadius,
    this.padding,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: colors.first.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Semantics(
              label: semanticLabel,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? textStyle;
  final String? semanticLabel;

  const AnimatedCounter({
    Key? key,
    required this.value,
    this.duration = const Duration(milliseconds: 500),
    this.textStyle,
    this.semanticLabel,
  }) : super(key: key);

  @override
  _AnimatedCounterState createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = IntTween(begin: _previousValue, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _animation.value;
      _animation = IntTween(begin: _previousValue, end: widget.value)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Semantics(
          label: widget.semanticLabel ?? 'Counter: ${_animation.value}',
          child: Text(
            _animation.value.toString(),
            style: widget.textStyle,
          ),
        );
      },
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final String status;
  final Color color;
  final IconData icon;
  final String? semanticLabel;

  const StatusIndicator({
    Key? key,
    required this.status,
    required this.color,
    required this.icon,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 4),
          Semantics(
            label: semanticLabel ?? 'Status: $status',
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ModernProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  const ModernProgressBar({
    Key? key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 8,
    this.borderRadius,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade300,
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Theme.of(context).colorScheme.primary,
            borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 0.8,
    this.maxScale = 1.0,
  }) : super(key: key);

  @override
  _PulseAnimationState createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}

class ModernBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  const ModernBottomSheet({
    Key? key,
    required this.child,
    this.title,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || actions != null)
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class HapticFeedbackButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final HapticFeedbackType feedbackType;
  final String? semanticLabel;

  const HapticFeedbackButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.feedbackType = HapticFeedbackType.light,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () {
          switch (feedbackType) {
            case HapticFeedbackType.light:
              HapticFeedback.lightImpact();
              break;
            case HapticFeedbackType.medium:
              HapticFeedback.mediumImpact();
              break;
            case HapticFeedbackType.heavy:
              HapticFeedback.heavyImpact();
              break;
            case HapticFeedbackType.selection:
              HapticFeedback.selectionClick();
              break;
          }
          onPressed?.call();
        },
        child: child,
      ),
    );
  }
}

enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}
