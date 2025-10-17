import 'package:flutter/material.dart';
import 'ui_theme.dart';

/// Elegant animated status card for map screen
class AnimatedStatusCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color primaryColor;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;

  const AnimatedStatusCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.icon,
    this.onTap,
    this.isActive = false,
  });

  @override
  State<AnimatedStatusCard> createState() => _AnimatedStatusCardState();
}

class _AnimatedStatusCardState extends State<AnimatedStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(AllyTheme.spacingLG),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.primaryColor.withOpacity(0.05),
                widget.primaryColor.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AllyTheme.radiusLG),
            border: Border.all(
              color: widget.primaryColor.withOpacity(0.1),
              width: 1.5,
            ),
            boxShadow: [AllyTheme.shadowMD],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AllyTheme.spacingMD),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, widget.primaryColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AllyTheme.radiusMD),
                  boxShadow: [AllyTheme.shadowLG],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AllyTheme.spacingLG),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AllyTheme.bodyLG.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AllyTheme.spacingSM),
                    Text(
                      widget.subtitle,
                      style: AllyTheme.bodySM.copyWith(
                        color: AllyTheme.lightTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.isActive)
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AllyTheme.successColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AllyTheme.successColor.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enhanced info badge widget
class InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const InfoBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AllyTheme.spacingMD,
        vertical: AllyTheme.spacingSM,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AllyTheme.radiusMD),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AllyTheme.spacingSM),
          Text(
            label,
            style: AllyTheme.captionSM.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced nav item for bottom navigation with ripple effect
class EnhancedNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const EnhancedNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  State<EnhancedNavItem> createState() => _EnhancedNavItemState();
}

class _EnhancedNavItemState extends State<EnhancedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant EnhancedNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AllyTheme.spacingMD),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? AllyTheme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AllyTheme.radiusMD),
              ),
              child: Icon(
                widget.icon,
                color: widget.isActive
                    ? AllyTheme.primaryColor
                    : AllyTheme.lightTextColor,
                size: 24,
              ),
            ),
            const SizedBox(height: AllyTheme.spacingSM),
            Text(
              widget.label,
              style: AllyTheme.bodySM.copyWith(
                color: widget.isActive
                    ? AllyTheme.primaryColor
                    : AllyTheme.lightTextColor,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating stats card for showing quick metrics with subtle float animation
class FloatingStatsCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const FloatingStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<FloatingStatsCard> createState() => _FloatingStatsCardState();
}

class _FloatingStatsCardState extends State<FloatingStatsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _controller.value * 4 - 2),
          child: Container(
            padding: const EdgeInsets.all(AllyTheme.spacingLG),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(0.1),
                  widget.color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AllyTheme.radiusLG),
              border: Border.all(
                color: widget.color.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.1),
                  blurRadius: 12,
                  offset: Offset(0, 4 + _controller.value * 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.color,
                      size: 20,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AllyTheme.spacingSM,
                        vertical: AllyTheme.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AllyTheme.radiusXS),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: widget.color,
                        size: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AllyTheme.spacingMD),
                Text(
                  widget.value,
                  style: AllyTheme.headingMD.copyWith(
                    color: widget.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AllyTheme.spacingSM),
                Text(
                  widget.title,
                  style: AllyTheme.bodySM.copyWith(
                    color: AllyTheme.lightTextColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
