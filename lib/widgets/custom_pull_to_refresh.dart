import 'package:flutter/material.dart';

class CustomPullToRefresh extends StatefulWidget {
  final Widget child;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final Color subTitleColor;

  const CustomPullToRefresh({
    super.key,
    required this.child,
    required this.isRefreshing,
    required this.onRefresh,
    required this.subTitleColor,
  });

  @override
  State<CustomPullToRefresh> createState() => _CustomPullToRefreshState();
}

class _CustomPullToRefreshState extends State<CustomPullToRefresh> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  double _startY = 0.0;
  double _scrollOffset = 0.0;
  bool _isDragging = false;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.isRefreshing) {
      _animationController.value = 1.0;
      _hasTriggered = true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomPullToRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing && !widget.isRefreshing) {
      // Refresh ended, slide the header back up
      _animationController.animateTo(0.0, curve: Curves.easeOut);
      _hasTriggered = false;
    } else if (!oldWidget.isRefreshing && widget.isRefreshing) {
      // Refresh started externally, show the header
      _animationController.animateTo(1.0, curve: Curves.easeOut);
      _hasTriggered = true;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.isRefreshing || _hasTriggered) return;
    _startY = event.position.dy;
    _isDragging = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (widget.isRefreshing || _hasTriggered) return;
    
    final double deltaY = event.position.dy - _startY;
    
    // Once we start dragging, we continue updating progress regardless of minor scroll changes (prevents freezing mid-drag)
    // We allow a safer top offset limit (<= 10.0 pixels) to start the pull action
    if (_isDragging || (_scrollOffset <= 10.0 && deltaY > 0)) {
      _isDragging = true;
      // Spring damping formula (dragOffset / 2.2) to give a satisfying heavy spring resistance feel
      final double pullDistance = deltaY / 2.2;
      
      if (pullDistance >= 80.0) {
        // Auto-trigger and lock immediately when threshold is reached!
        _hasTriggered = true;
        _isDragging = false;
        _animationController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
        widget.onRefresh();
      } else {
        // Map pullDistance (0..80) to animation value (0..1)
        final double progress = (pullDistance / 80.0).clamp(0.0, 1.2);
        _animationController.value = progress;
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (widget.isRefreshing || _hasTriggered || !_isDragging) return;
    _isDragging = false;

    // Only gets hit if the user released the touch BEFORE reaching the threshold (80.0)
    _animationController.animateTo(0.0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Track the current scroll position of the child scroll view
        _scrollOffset = notification.metrics.pixels;
        return false;
      },
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        behavior: HitTestBehavior.translucent,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final double progress = _animationController.value;
            // Height maps 0..1 progress to 0..80 pixels height
            final double containerHeight = (progress * 80.0).clamp(0.0, 80.0);
            final bool showContent = progress > 0.15;

            return Stack(
              children: [
                // Translate the ENTIRE viewport content down based on pull progress
                // This prevents overlapping with headers on all screens
                Transform.translate(
                  offset: Offset(0, containerHeight),
                  child: widget.child,
                ),
                
                // Sliding loader header (clean transparent style)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: containerHeight,
                    width: double.infinity,
                    color: Colors.transparent,
                    child: showContent
                        ? Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.isRefreshing || progress >= 1.0) ...[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Memperbarui data...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.subTitleColor.withOpacity(0.7),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tarik untuk memperbarui',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.subTitleColor.withOpacity(0.7),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
