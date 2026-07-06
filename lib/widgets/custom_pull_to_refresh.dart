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

class _CustomPullToRefreshState extends State<CustomPullToRefresh> {
  final ValueNotifier<double> _pullDistanceNotifier = ValueNotifier<double>(0.0);
  bool _canTrigger = false;

  @override
  void dispose() {
    _pullDistanceNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomPullToRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing && !widget.isRefreshing) {
      // Reset indicator position when refreshing is done
      _pullDistanceNotifier.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (widget.isRefreshing) return false;

        if (notification is ScrollUpdateNotification) {
          final double metrics = notification.metrics.pixels;
          if (metrics < 0) {
            _pullDistanceNotifier.value = -metrics;
            if (-metrics > 80.0) {
              _canTrigger = true;
            }
          } else {
            if (_pullDistanceNotifier.value != 0.0) {
              _pullDistanceNotifier.value = 0.0;
            }
          }
        } else if (notification is ScrollEndNotification) {
          if (_canTrigger) {
            _canTrigger = false;
            widget.onRefresh();
          }
          _pullDistanceNotifier.value = 0.0;
        }
        return false;
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Scrollable content viewport (full height, no resize to prevent jitters)
          Positioned.fill(
            child: widget.child,
          ),
          
          // Re-build ONLY the floating pill when pull distance changes
          ValueListenableBuilder<double>(
            valueListenable: _pullDistanceNotifier,
            builder: (context, pullDistance, child) {
              final double currentPull = widget.isRefreshing ? 80.0 : pullDistance.clamp(0.0, 100.0);
              // topPosition maps 0..80 pull distance to -60..20 pixel offset
              final double topPosition = -60.0 + (currentPull * 1.0).clamp(0.0, 80.0);

              return Positioned(
                top: topPosition,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: currentPull > 15 ? 1.0 : 0.0,
                    child: Card(
                      elevation: 6,
                      shadowColor: Colors.black.withOpacity(0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      color: Theme.of(context).cardColor,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: widget.subTitleColor.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isRefreshing) ...[
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Memperbarui...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.subTitleColor.withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else ...[
                              Icon(
                                pullDistance >= 80.0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pullDistance >= 80.0 ? 'Lepas untuk memperbarui' : 'Tarik untuk memperbarui',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.subTitleColor.withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
