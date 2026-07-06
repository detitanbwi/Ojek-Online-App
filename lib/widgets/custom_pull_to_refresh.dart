import 'package:flutter/material.dart';

class CustomPullToRefresh extends StatefulWidget {
  final Widget child;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  const CustomPullToRefresh({
    super.key,
    required this.child,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  State<CustomPullToRefresh> createState() => _CustomPullToRefreshState();
}

class _CustomPullToRefreshState extends State<CustomPullToRefresh> {
  double _pullDistance = 0.0;
  bool _canTrigger = false;

  @override
  Widget build(BuildContext context) {
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
      child: widget.child,
    );
  }
}
