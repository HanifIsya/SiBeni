import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Responsive page wrapper.
///
/// Guarantees three things on every screen:
///  1. A readable gutter that adapts from phone to tablet.
///  2. A capped content width so lines never run across a desktop display.
///  3. A scrollable body that always respects the system insets and the
///     keyboard, which is what previously pushed controls off-screen.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.slivers,
    this.controller,
    this.padding,
    this.maxWidth = AppTheme.contentMaxWidth,
    this.bottomInset = AppTheme.xxl,
    this.onRefresh,
  });

  final List<Widget> slivers;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final double maxWidth;
  final double bottomInset;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = AppTheme.gutter(width);
        final inner = padding ??
            EdgeInsets.fromLTRB(gutter, gutter * 0.75, gutter, bottomInset);

        Widget content = CustomScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: inner,
              sliver: SliverList(
                delegate: SliverChildListDelegate(slivers),
              ),
            ),
          ],
        );

        if (onRefresh != null) {
          content = RefreshIndicator(
            onRefresh: onRefresh!,
            color: AppTheme.brand,
            backgroundColor: AppTheme.surface,
            displacement: 28,
            child: content,
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: content,
          ),
        );
      },
    );
  }
}

/// Convenience for short, non-scrolling content blocks.
class AdaptiveBody extends StatelessWidget {
  const AdaptiveBody({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = AppTheme.contentMaxWidth,
  });

  final Widget child;
  final EdgeInsets? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppTheme.gutter(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding ?? EdgeInsets.fromLTRB(gutter, gutter, gutter, gutter),
              child: child,
            ),
          ),
        );
      },
    );
  }
}