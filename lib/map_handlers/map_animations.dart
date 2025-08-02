import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

mixin MapAnimationsMixin on TickerProviderStateMixin {
  late AnimationController markerAnimationController;
  late Animation<double> markerAnimation;
  late AnimationController backgroundAnimationController;
  late Animation<AlignmentGeometry> backgroundAlignmentAnimation;
  late AnimationController pulseAnimationController;
  late Animation<double> pulseAnimation;
  late AnimationController slideAnimationController;
  late Animation<Offset> slideAnimation;

  void initializeMapAnimations() {
    markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    markerAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: markerAnimationController,
        curve: Curves.easeInOutSine,
      ),
    );

    backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    backgroundAlignmentAnimation = TweenSequence<AlignmentGeometry>([
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topLeft, end: Alignment.bottomRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomRight, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft),
        weight: 1,
      ),
    ]).animate(backgroundAnimationController);

    pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: slideAnimationController,
            curve: Curves.elasticOut,
          ),
        );

    slideAnimationController.forward();
  }

  void disposeMapAnimations() {
    markerAnimationController.dispose();
    backgroundAnimationController.dispose();
    pulseAnimationController.dispose();
    slideAnimationController.dispose();
  }
}

class LatLngTween extends Tween<LatLng> {
  LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) {
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}
