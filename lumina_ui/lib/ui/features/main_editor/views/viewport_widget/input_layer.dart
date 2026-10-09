part of '../viewport_widget.dart';

/// The viewport's keyboard handler and its pointer layer (navigation,
/// gizmo drags, selection clicks and marquee).
mixin _ViewportInputLayer on _ViewportWidgetStateBase, _ViewportPieSession, _ViewportCameraControls, _ViewportPointerInteraction {
  /// The viewport's keys: F focuses, End drops to the floor, Space cycles the
  /// transform tool, the arrows move the camera; WASD/QE as the flight preference says.
  KeyEventResult _onViewportKeyEvent(FocusNode node, KeyEvent event) {
    // The running game takes the keyboard itself, in PieController,
    // because the editor's focus can be on any panel when Play is
    // pressed. Here we only keep the editor flycam off those keys.
    if (widget.viewModel.pieController.acceptsGameInput) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _pressedKeys.add(event.logicalKey);
      // Chords (Ctrl+S, Ctrl+D, Ctrl+Z, Alt+P, ...) are the
      // editor shell's shortcuts, not camera keys.
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        if (widget.viewModel.selectedActor != null) {
          widget.viewModel.focusCameraOnActor(
            widget.viewModel.selectedActor!,
          );
        } else {
          widget.viewModel.resetCamera();
        }
        _updateNativeCamera();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.end) {
        _handleEndDrop();
        return KeyEventResult.handled;
      }
      final label = event.logicalKey.keyLabel.toLowerCase();
      // W/A/S/D/Q/E fly the camera as Editor Preferences say
      // (by default while the right button is
      // held); otherwise Q/W/E/R are the transform tools, which
      // the shell's shortcuts switch.
      if (['w', 'a', 's', 'd', 'q', 'e'].contains(label)) {
        return _wasdFlies ? KeyEventResult.handled : KeyEventResult.ignored;
      }
      // Space cycles Move → Rotate → Scale.
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (event is KeyDownEvent) _cycleTransformTool();
        return KeyEventResult.handled;
      }
      if ([
        'arrow up',
        'arrow down',
        'arrow left',
        'arrow right',
      ].contains(label)) {
        if (!_isRmbDown) {
          widget.viewModel.moveCameraWASD(label);
          _updateNativeCamera();
        }
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
    return KeyEventResult.ignored;
  }

  /// The navigation and selection layer over the native view: RMB flycam, LMB
  /// walk/orbit/gizmo/marquee, MMB pan, Alt dolly, wheel speed, and the overlay
  /// painter (grid, gizmo, marquee, drop marker).
  Widget _buildViewportInputLayer() {
    return MouseRegion(
      cursor: _viewportCursor(),
      onHover: (event) {
        if (_piePointer(event)) return;
        final renderBox =
            _viewportKey.currentContext?.findRenderObject()
                as RenderBox?;
        if (renderBox != null) {
          _handleMouseHover(
            event.localPosition,
            renderBox.size,
          );
        }
      },
      child: Listener(
        // While the game's camera draws, the overlay below
        // paints nothing and would not be hit: the view still
        // takes every press (the game's clicks).
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_piePointer(event)) return;
          _downPos = event.localPosition;
          _hasMovedDuringDrag = false;
          if (!_keyboardFocus.hasPrimaryFocus) _keyboardFocus.requestFocus();
          // A text field this press lands outside of (a search
          // box, a Details field) unfocuses itself on the same
          // pointer event, after this listener, which would hand
          // focus to the shell's scope and leave RMB + WASD dead
          // Ask again once that has run.
          scheduleMicrotask(() {
            if (mounted && !_keyboardFocus.hasPrimaryFocus) _keyboardFocus.requestFocus();
          });

          if ((event.buttons & kSecondaryMouseButton) != 0) {
            _isRmbDown = true;
            // The shell's single-key shortcuts stand down while flying.
            widget.viewModel.isFlyNavigating = true;
          }
          if ((event.buttons & kPrimaryMouseButton) != 0) {
            _isLmbDown = true;
            final renderBox =
                _viewportKey.currentContext?.findRenderObject()
                    as RenderBox?;
            if (renderBox != null) {
              _handlePanStart(
                event.localPosition,
                renderBox.size,
              );
              if (_draggingGizmoAxis == null &&
                  widget.viewModel.activeTool == 'select') {
                if (!_checkActorHitForMarqueeStart(
                  event.localPosition,
                  renderBox.size,
                )) {
                  _marqueeStart = event.localPosition;
                  _marqueeCurrent = event.localPosition;
                }
              }
            }
          }
          if ((event.buttons & kMiddleMouseButton) != 0) {
            _isMmbDown = true;
          }
          setState(() {});
        },
        onPointerMove: (event) {
          if (_piePointer(event)) return;
          if ((event.position - _downPos).distance > 3.0) {
            _hasMovedDuringDrag = true;
          }

          final isAlt = HardwareKeyboard.instance.isAltPressed;
          final buttons = event.buttons;

          // A. Both Left + Right Buttons Held Together (Pan & Pedestal)
          if ((buttons &
                  (kPrimaryMouseButton |
                      kSecondaryMouseButton)) ==
              (kPrimaryMouseButton | kSecondaryMouseButton)) {
            widget.viewModel.panPedestal(
              event.delta.dx,
              event.delta.dy,
            );
            _updateNativeCamera();
          }
          // B. Right Mouse Button (Flycam Look / Alt+RMB Dolly)
          else if ((buttons & kSecondaryMouseButton) != 0) {
            if (isAlt) {
              // Alt + RMB Smooth Dolly Zoom
              widget.viewModel.dollyCamera(
                -event.delta.dy * 2.0,
              );
              _updateNativeCamera();
            } else {
              // RMB Mouselook (First-person gaze rotation)
              widget.viewModel.rotateCamera(
                event.delta.dx,
                event.delta.dy,
              );
              _updateNativeCamera();
            }
          }
          // C. Left Mouse Button (Alt+LMB Orbit, Gizmo Drag, or Walk & Turn)
          else if ((buttons & kPrimaryMouseButton) != 0) {
            if (isAlt) {
              // Alt + LMB Orbit / Tumble Camera around Pivot
              widget.viewModel.orbitCamera(
                event.delta.dx,
                event.delta.dy,
              );
              _updateNativeCamera();
            } else if (_draggingGizmoAxis != null) {
              // Dragging 3D Actor Transform Gizmo Axis
              _handleGizmoDrag(event.localPosition);
              _updateNativeCamera();
            } else if (_marqueeStart != null) {
              _marqueeCurrent = event.localPosition;
              setState(() {});
            } else if (_hasMovedDuringDrag) {
              // LMB Walk (Forward/Backward & Turn Yaw)
              widget.viewModel.walkMove(
                event.delta.dx,
                event.delta.dy,
              );
              _updateNativeCamera();
            }
          }
          // D. Middle Mouse Button (MMB Screen-Space Pan)
          else if ((buttons & kMiddleMouseButton) != 0 ||
              (buttons == kPrimaryMouseButton &&
                  isAlt &&
                  HardwareKeyboard.instance.isShiftPressed)) {
            widget.viewModel.panCamera(
              event.delta.dx,
              event.delta.dy,
            );
            _updateNativeCamera();
          }
          // E. Hovering without buttons
          else {
            final renderBox =
                _viewportKey.currentContext?.findRenderObject()
                    as RenderBox?;
            if (renderBox != null) {
              _handleMouseHover(
                event.localPosition,
                renderBox.size,
              );
            }
          }
        },
        onPointerUp: (event) {
          if (_piePointer(event)) return;
          if ((event.buttons & kSecondaryMouseButton) == 0) {
            _isRmbDown = false;
            widget.viewModel.isFlyNavigating = false;
          }
          // A left-button release only: releasing the right
          // button (fly / look) or the middle one is camera
          // navigation, never a selection click.
          if (_isLmbDown && (event.buttons & kPrimaryMouseButton) == 0) {
            if (_draggingGizmoAxis != null) {
              widget.viewModel.endTransformDrag();
              _draggingGizmoAxis = null;
              _marqueeStart = null;
              _marqueeCurrent = null;
            } else if (!_hasMovedDuringDrag) {
              // Click selection only when mouse did not drag
              final renderBox =
                  _viewportKey.currentContext
                          ?.findRenderObject()
                      as RenderBox?;
              if (renderBox != null) {
                if (_marqueeStart != null &&
                    _marqueeCurrent != null &&
                    (_marqueeStart! - _marqueeCurrent!)
                            .distance >
                        5.0) {
                  // Perform Marquee selection
                  _applyMarqueeSelection(renderBox.size);
                } else {
                  _handleViewportClick(
                    event.localPosition,
                    renderBox.size,
                  );
                }
              }
            }
            _marqueeStart = null;
            _marqueeCurrent = null;
            _isLmbDown = false;
          }
          if ((event.buttons & kMiddleMouseButton) == 0) {
            _isMmbDown = false;
          }
          setState(() {});
        },
        onPointerCancel: (event) {
          _piePointer(event);
          _isRmbDown = false;
          widget.viewModel.isFlyNavigating = false;
          _isLmbDown = false;
          _isMmbDown = false;
          _draggingGizmoAxis = null;
          setState(() {});
        },
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (_isRmbDown) {
              // RMB + Scroll Wheel = Adjust Camera Fly Speed
              widget.viewModel.adjustCameraSpeed(
                event.scrollDelta.dy > 0 ? -1 : 1,
              );
              _triggerSpeedFeedback();
            } else {
              // Standard Dolly Zoom Step
              widget.viewModel.dollyCamera(
                event.scrollDelta.dy * 0.5,
              );
            }
            _updateNativeCamera();
          }
        },
        child: CustomPaint(
          size: Size.infinite,
          // While the game's camera owns the view, every editor
          // overlay is drawn with the wrong projection and belongs
          // to a scene the player is not looking at. Suspend them.
          painter: _pieCameraDrivesView
              ? null
              : _PerspectiveGridPainter(
                  viewModel: widget.viewModel,
                  activeGizmoAxis:
                      _hoveredGizmoAxis ?? _draggingGizmoAxis,
                  marqueeRect:
                      (_marqueeStart != null &&
                          _marqueeCurrent != null)
                      ? Rect.fromPoints(
                          _marqueeStart!,
                          _marqueeCurrent!,
                        )
                      : null,
                  dropPreviewPos: _dropPreviewPos,
                  dropPreviewName: _dropPreviewAsset?.fileName,
                ),
        ),
      ),
    );
  }
}
