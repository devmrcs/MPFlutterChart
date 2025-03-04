import 'package:flutter/widgets.dart';
import 'package:mp_chart/mp/chart/chart.dart';
import 'package:mp_chart/mp/controller/bar_line_scatter_candle_bubble_controller.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/touch_listener.dart';
import 'package:mp_chart/mp/core/utils/highlight_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:optimized_gesture_detector/details.dart';
import 'package:optimized_gesture_detector/direction.dart';

abstract class BarLineScatterCandleBubbleChart<
    C extends BarLineScatterCandleBubbleController> extends Chart<C> {
  const BarLineScatterCandleBubbleChart(C controller) : super(controller);
}

class BarLineScatterCandleBubbleState<T extends BarLineScatterCandleBubbleChart>
    extends ChartState<T> {
  IDataSet? _closestDataSetToTouch;

  Highlight? lastHighlighted;
  double _curX = 0.0;
  double _curY = 0.0;
  double _scale = -1.0;
  bool _isScaleDirectionConfirm = false;
  bool _isYDirection = false;

  MPPointF _getTrans(double x, double y) {
    return Utils.local2Chart(widget.controller, x, y, inverted: _inverted());
  }

  MPPointF _getTouchValue(TouchValueType type, double screenX, double screenY,
      double localX, localY) {
    if (type == TouchValueType.CHART) {
      return _getTrans(localX, localY);
    } else if (type == TouchValueType.SCREEN) {
      return MPPointF.getInstance1(screenX, screenY);
    } else {
      return MPPointF.getInstance1(localX, localY);
    }
  }

  bool _inverted() {
    var res = (_closestDataSetToTouch == null &&
            widget.controller.painter!.isAnyAxisInverted()) ||
        (_closestDataSetToTouch != null &&
            widget.controller.painter!
                .isInverted(_closestDataSetToTouch!.getAxisDependency()));
    return res;
  }

  @override
  void onTapDown(TapDownDetails details) {
    widget.controller.stopDeceleration();
    _curX = details.localPosition.dx;
    _curY = details.localPosition.dy;
    _closestDataSetToTouch = widget.controller.painter!.getDataSetByTouchPoint(
        details.localPosition.dx, details.localPosition.dy);
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener!.onTapDown(point.x, point.y);
    }
  }

  @override
  void onSingleTapUp(TapUpDetails details) {
    if (widget.controller.painter!.highLightPerTapEnabled) {
      Highlight? h = widget.controller.painter!.getHighlightByTouchPoint(
          details.localPosition.dx, details.localPosition.dy);
      lastHighlighted = HighlightUtils.performHighlight(
          widget.controller.painter, h, lastHighlighted);
      setStateIfNotDispose();
    } else {
      Highlight high = widget.controller.painter!.getHighlightByTouchPoint(
        details.localPosition.dx,
        details.localPosition.dy,
      )!;

      widget.controller.painter!.selectedValue(high);

      lastHighlighted = null;
    }
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener!.onSingleTapUp(point.x, point.y);
    }
  }

  @override
  void onDoubleTapUp(TapUpDetails details) {
    widget.controller.stopDeceleration();
    if (widget.controller.painter!.doubleTapToZoomEnabled &&
        (widget.controller.painter!.getData()?.getEntryCount() ?? 0) > 0) {
      MPPointF trans =
          _getTrans(details.localPosition.dx, details.localPosition.dy);
      widget.controller.painter!.zoom(
          widget.controller.painter!.scaleXEnabled ? 1.2 : 1,
          widget.controller.painter!.scaleYEnabled ? 1.2 : 1,
          trans.x,
          trans.y);
      setStateIfNotDispose();
      MPPointF.recycleInstance(trans);
    }
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener!.onDoubleTapUp(point.x, point.y);
    }
  }

  @override
  void onMoveStart(OpsMoveStartDetails details) {
    widget.controller.stopDeceleration();
    _curX = details.localPoint.dx;
    _curY = details.localPoint.dy;
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPoint.dx,
          details.globalPoint.dy,
          details.localPoint.dx,
          details.localPoint.dy);
      widget.controller.touchEventListener!.onMoveStart(point.x, point.y);
    }
  }

  @override
  void onMoveUpdate(OpsMoveUpdateDetails details) {
    var needStateIfNotDispose = false;
    var dx = details.localPoint.dx - _curX;
    var dy = details.localPoint.dy - _curY;

    if (widget.controller.painter!.highlightPerDragEnabled) {
      final highlighted = widget.controller.painter!.getHighlightByTouchPoint(
          details.localPoint.dx, details.localPoint.dy);
      if (highlighted?.equalTo(lastHighlighted) == false) {
        lastHighlighted = HighlightUtils.performHighlight(
            widget.controller.painter, highlighted, lastHighlighted);
        needStateIfNotDispose = true;
      }
    }

    if (widget.controller.painter!.dragYEnabled &&
        widget.controller.painter!.dragXEnabled) {
      if (_inverted()) {
        dy = -dy;
      }
      widget.controller.painter!.translate(dx, dy);
      needStateIfNotDispose = true;
    } else {
      if (widget.controller.painter!.dragXEnabled) {
        if (_inverted()) {
          dy = -dy;
        }
        widget.controller.painter!.translate(dx, 0.0);
        needStateIfNotDispose = true;
      } else if (widget.controller.painter!.dragYEnabled) {
        if (_inverted()) {
          dy = -dy;
        }
        widget.controller.painter!.translate(0.0, dy);
        needStateIfNotDispose = true;
      }
    }

    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPoint.dx,
          details.globalPoint.dy,
          details.localPoint.dx,
          details.localPoint.dy);
      widget.controller.touchEventListener!.onMoveUpdate(point.x, point.y);
    }

    if (needStateIfNotDispose) {
      setStateIfNotDispose();
    }

    _curX = details.localPoint.dx;
    _curY = details.localPoint.dy;
  }

  @override
  void onMoveEnd(OpsMoveEndDetails details) {
    widget.controller
      ..stopDeceleration()
      ..setDecelerationVelocity(details.velocity.pixelsPerSecond)
      ..computeScroll();
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPoint.dx,
          details.globalPoint.dy,
          details.localPoint.dx,
          details.localPoint.dy);
      widget.controller.touchEventListener!.onMoveEnd(point.x, point.y);
    }
  }

  @override
  void onScaleStart(OpsScaleStartDetails details) {
    widget.controller.stopDeceleration();
    _curX = details.localPoint.dx;
    _curY = details.localPoint.dy;
    _isScaleDirectionConfirm = false;
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPoint.dx,
          details.globalPoint.dy,
          details.localPoint.dx,
          details.localPoint.dy);
      widget.controller.touchEventListener!.onScaleStart(point.x, point.y);
    }
  }

  @override
  void onScaleUpdate(OpsScaleUpdateDetails details) {
    var needStateIfNotDispose = false;
    var pinchZoomEnabled = widget.controller.pinchZoomEnabled;

    if (!_isScaleDirectionConfirm) {
      _isScaleDirectionConfirm = true;
      _isYDirection = details.mainDirection == Direction.Y;
    }
    if (_scale == -1.0) {
      if (pinchZoomEnabled) {
        _scale = details.scale;
      } else {
        _scale =
            _isYDirection ? details.verticalScale : details.horizontalScale;
      }
      return;
    }

    var scale = 1.0;
    if (pinchZoomEnabled) {
      scale = details.scale / _scale;
    } else {
      scale = _isYDirection
          ? details.verticalScale / _scale
          : details.horizontalScale / _scale;
    }

    MPPointF trans = _getTrans(_curX, _curY);
    var h = widget.controller.painter!.viewPortHandler;
    scale = Utils.optimizeScale(scale);
    if (pinchZoomEnabled) {
      bool canZoomMoreX =
          scale < 1 ? h!.canZoomOutMoreX() : h!.canZoomInMoreX();
      bool canZoomMoreY = scale < 1 ? h.canZoomOutMoreY() : h.canZoomInMoreY();
      widget.controller.painter!.zoom(
          canZoomMoreX ? scale : 1, canZoomMoreY ? scale : 1, trans.x, trans.y);
      needStateIfNotDispose = true;
    } else {
      if (_isYDirection) {
        if (widget.controller.painter!.scaleYEnabled) {
          bool canZoomMoreY =
              scale < 1 ? h!.canZoomOutMoreY() : h!.canZoomInMoreY();
          widget.controller.painter!
              .zoom(1, canZoomMoreY ? scale : 1, trans.x, trans.y);
          needStateIfNotDispose = true;
        }
      } else {
        if (widget.controller.painter!.scaleXEnabled) {
          bool canZoomMoreX =
              scale < 1 ? h!.canZoomOutMoreX() : h!.canZoomInMoreX();
          widget.controller.painter!
              .zoom(canZoomMoreX ? scale : 1, 1, trans.x, trans.y);
          needStateIfNotDispose = true;
        }
      }
    }

    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalFocalPoint.dx,
          details.globalFocalPoint.dy,
          details.localFocalPoint.dx,
          details.localFocalPoint.dy);
      widget.controller.touchEventListener!.onScaleUpdate(point.x, point.y);
    }

    if (needStateIfNotDispose) {
      setStateIfNotDispose();
    }

    MPPointF.recycleInstance(trans);

    if (pinchZoomEnabled) {
      _scale = details.scale;
    } else {
      _scale = _isYDirection ? details.verticalScale : details.horizontalScale;
    }
  }

  @override
  void onScaleEnd(OpsScaleEndDetails details) {
    _scale = -1.0;
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPoint.dx,
          details.globalPoint.dy,
          details.localPoint.dx,
          details.localPoint.dy);
      widget.controller.touchEventListener!.onScaleEnd(point.x, point.y);
    }
  }

  void onDragStart(LongPressStartDetails details) {
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener!.onDragStart(point.x, point.y);
    }
  }

  void onDragUpdate(LongPressMoveUpdateDetails details) {
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener!.onDragUpdate(point.x, point.y);
    }
  }

  void onDragEnd(LongPressEndDetails details) {
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener!.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener!.onDragEnd(point.x, point.y);
    }
  }

  @override
  void updatePainter() {
    if (widget.controller.painter!.getData() != null &&
        widget.controller.painter!.getData()!.dataSets != null &&
        widget.controller.painter!.getData()!.dataSets!.length > 0)
      widget.controller.painter!.highlightValue6(lastHighlighted, false);
  }
}
