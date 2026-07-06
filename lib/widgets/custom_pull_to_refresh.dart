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
  double _pullDistance = 0.0;
  bool _canTrigger = false;

  @override
  Widget build(BuildContext context) {
    // Determine the offset of the floating indicator pill.
    // If refreshing, keep it visible at full height. Otherwise, scale with pull distance.
    final double currentPull = widget.isRefreshing ? 80.0 : _pullDistance.clamp(0.0, 100.0);
    // When currentPull is 0, pill is hidden at top: -60. When currentPull is 80+, pill is at top: 20.
    final double topPosition = -60.0 + (currentPull * 1.0).clamp(0.0, 80.0);

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (widget.isRefreshing) return false;

        if (notification is ScrollUpdateNotification) {
          final double metrics = notification.metrics.pixels;
          if (metrics < 0) {
            setState(() {
              _pullDistance = -metrics;
              if (_pullDistance > 80.0) {
                _canTrigger = true;
              }
            });
          } else {
            if (_pullDistance != 0.0) {
              setState(() {
                _pullDistance = 0.0;
              });
            }
          }
        } else if (notification is ScrollEndNotification) {
          if (_canTrigger) {
            _canTrigger = false;
            widget.onRefresh();
          }
          setState(() {
            _pullDistance = 0.0;
          });
        }
        return false;
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The scrollable list content is rendered full height with no viewport resizing
          Positioned.fill(
            child: widget.child,
          ),
          
          // Floating overlay refresh pill
          Positioned(
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
                            _pullDistance >= 80.0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _pullDistance >= 80.0 ? 'Lepas untuk memperbarui' : 'Tarik untuk memperbarui',
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
          ),
        ],
      ),
    );
  }
}
