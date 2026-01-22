import 'package:flutter/material.dart';


/// A wrapper widget to apply staggered animations to a list of children.
/// This uses the `flutter_staggered_animations` package pattern but simplified if dependency not added.
/// Actually, since we don't want to add a new dependency if possible, let's implement a simple custom one.
class SimpleStaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration duration;
  final double verticalOffset;

  const SimpleStaggeredList({
    super.key,
    required this.children,
    this.duration = const Duration(milliseconds: 375),
    this.verticalOffset = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(children.length, (index) {
        return _AnimatedListItem(
          index: index,
          duration: duration,
          verticalOffset: verticalOffset,
          child: children[index],
        );
      }),
    );
  }
}

class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Duration duration;
  final double verticalOffset;
  final Widget child;

  const _AnimatedListItem({
    required this.index,
    required this.duration,
    required this.verticalOffset,
    required this.child,
  });

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.verticalOffset / 100), // Approximate offset
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    ));

    // Stagger delay based on index
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
