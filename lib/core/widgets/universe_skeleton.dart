import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme.dart';

/// Skeleton loading UniVerse — blocs bleu/violet inspirés des pixels du logo.
class UniverseSkeleton extends StatelessWidget {
  const UniverseSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Shimmer.fromColors(
      baseColor: t.surfaceElevated,
      highlightColor: UniverseColors.blue.withValues(alpha: 0.35),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: t.surfaceElevated,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class VideoFeedSkeleton extends StatelessWidget {
  const VideoFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UniverseSkeleton(height: 180, borderRadius: 12),
          SizedBox(height: 10),
          UniverseSkeleton(width: 220, height: 14),
          SizedBox(height: 6),
          UniverseSkeleton(width: 140, height: 12),
        ],
      ),
    );
  }
}

class ListTileSkeleton extends StatelessWidget {
  const ListTileSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const Row(
        children: [
          UniverseSkeleton(width: 48, height: 48, borderRadius: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UniverseSkeleton(width: 160, height: 14),
                SizedBox(height: 6),
                UniverseSkeleton(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RailSkeleton extends StatelessWidget {
  const RailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        6,
        (i) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: UniverseSkeleton(width: 44, height: 44, borderRadius: 22),
        ),
      ),
    );
  }
}
