import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_filament/filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/world/world.dart';

/// Result descriptor from a GPU pixel-exact picking query.
class LuminaPickResult {
  final bool hasHit;
  final int entity;
  final LuminaActor? actor;
  final LuminaSceneComponent? component;
  final double depth;
  final Vector3? worldLocation;
  final (double, double) fragCoords;

  const LuminaPickResult({
    required this.hasHit,
    this.entity = 0,
    this.actor,
    this.component,
    this.depth = 0.0,
    this.worldLocation,
    this.fragCoords = (0.0, 0.0),
  });

  const LuminaPickResult.miss({
    (double, double) fragCoords = (0.0, 0.0),
  }) : this(
          hasHit: false,
          entity: 0,
          actor: null,
          component: null,
          depth: 0.0,
          worldLocation: null,
          fragCoords: fragCoords,
        );

  @override
  String toString() =>
      'LuminaPickResult(hasHit: $hasHit, entity: $entity, actor: $actor, component: $component, depth: $depth, worldLocation: $worldLocation, fragCoords: $fragCoords)';
}

/// Stateless static utility facade for GPU viewport operations (pixel picking, ray unprojection, and screenshot capture).
abstract final class LuminaViewportStatics {
  static int inFlightPicks = 0;
  static final List<Completer<dynamic>> _pendingCompleters = [];

  /// Registers a pending future completer so it can be aborted safely on world cleanup.
  static void _registerPending(Completer<dynamic> c) {
    _pendingCompleters.add(c);
  }

  static void _unregisterPending(Completer<dynamic> c) {
    _pendingCompleters.remove(c);
  }

  /// Cancels and fails all currently pending pick and screenshot operations.
  static void cancelAllPending(String reason) {
    final list = List<Completer<dynamic>>.from(_pendingCompleters);
    _pendingCompleters.clear();
    for (final c in list) {
      if (!c.isCompleted) {
        c.completeError(StateError(reason));
      }
    }
  }

  /// Performs a GPU pixel-exact picking query at the given Flutter logical [screenX] and [screenY] coordinates.
  ///
  /// Automatically translates from Flutter top-left origin to Filament bottom-left viewport origin.
  ///
  /// Note: For fast synchronous physics traces, use collision raycasts via `collision_subsystem`.
  /// For pixel-exact selection of rendered/skinned geometry, use this method.
  static Future<LuminaPickResult> pickAtScreen(
    LuminaWorld world,
    double screenX,
    double screenY, {
    int? viewportWidth,
    int? viewportHeight,
    FilamentView? targetView,
    Matrix4? customInvViewProj,
    Future<PickingResult> Function(int x, int y)? pickOverride,
  }) {
    if (world.isCleanedUp) {
      return Future.error(StateError('Cannot perform picking on a cleaned up world'));
    }

    final vpW = viewportWidth ?? 800;
    final vpH = viewportHeight ?? 600;
    final pickX = screenX.toInt();
    final pickY = vpH - screenY.toInt() - 1;

    inFlightPicks++;
    final completer = Completer<LuminaPickResult>();
    _registerPending(completer);

    try {
      final Future<PickingResult> pickFuture = pickOverride != null
          ? pickOverride(pickX, pickY)
          : (targetView != null
              ? targetView.pick(pickX, pickY)
              : throw StateError('No active FilamentView or pickOverride provided for picking'));

      pickFuture.then((pickingResult) {
        if (completer.isCompleted) return;

        if (pickingResult.renderable == null || pickingResult.renderable!.id == 0) {
          final res = LuminaPickResult.miss(fragCoords: pickingResult.fragCoords);
          completer.complete(res);
          return;
        }

        final entityId = pickingResult.renderable!.id;
        final comp = world.entityRegistry.componentForEntity(entityId);
        final actor = comp?.owner ?? world.entityRegistry.actorForEntity(entityId);

        // Unproject (fragCoords, depth) to world space
        Vector3? worldLoc;
        if (customInvViewProj != null) {
          final fx = pickingResult.fragCoords.$1;
          final fy = pickingResult.fragCoords.$2;
          final ndcX = (fx / vpW) * 2.0 - 1.0;
          final ndcY = (fy / vpH) * 2.0 - 1.0;
          final ndcZ = pickingResult.depth * 2.0 - 1.0;

          final clip = Vector4(ndcX, ndcY, ndcZ, 1.0);
          final worldVec = customInvViewProj.transform(clip);
          if (worldVec.w != 0.0) {
            worldLoc = Vector3(worldVec.x / worldVec.w, worldVec.y / worldVec.w, worldVec.z / worldVec.w);
          } else {
            worldLoc = Vector3(worldVec.x, worldVec.y, worldVec.z);
          }
        }

        final res = LuminaPickResult(
          hasHit: true,
          entity: entityId,
          actor: actor,
          component: comp,
          depth: pickingResult.depth,
          worldLocation: worldLoc,
          fragCoords: pickingResult.fragCoords,
        );

        completer.complete(res);
      }).catchError((dynamic e, StackTrace st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      });
    } catch (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
    }

    completer.future.whenComplete(() {
      if (inFlightPicks > 0) inFlightPicks--;
      _unregisterPending(completer);
    }).ignore();

    return completer.future;
  }

  /// Calculates a world-space ray (origin and normalized direction) from screen coordinates.
  static (Vector3 origin, Vector3 direction) screenToWorldRay(
    LuminaWorld world,
    double screenX,
    double screenY, {
    int? viewportWidth,
    int? viewportHeight,
    Matrix4? customInvViewProj,
  }) {
    final vpW = (viewportWidth ?? 800).toDouble();
    final vpH = (viewportHeight ?? 600).toDouble();

    final ndcX = (screenX / vpW) * 2.0 - 1.0;
    final ndcY = ((vpH - screenY - 1.0) / vpH) * 2.0 - 1.0;

    final invVP = customInvViewProj ?? Matrix4.identity();

    final pNear = invVP.transform(Vector4(ndcX, ndcY, -1.0, 1.0));
    final pFar = invVP.transform(Vector4(ndcX, ndcY, 1.0, 1.0));

    final origin = pNear.w != 0.0
        ? Vector3(pNear.x / pNear.w, pNear.y / pNear.w, pNear.z / pNear.w)
        : Vector3(pNear.x, pNear.y, pNear.z);

    final end = pFar.w != 0.0
        ? Vector3(pFar.x / pFar.w, pFar.y / pFar.w, pFar.z / pFar.w)
        : Vector3(pFar.x, pFar.y, pFar.z);

    final diff = end - origin;
    final length = diff.length;
    final direction = length > 1e-6 ? diff / length : Vector3(0, 0, -1);

    return (origin, direction);
  }

  /// Vertically flips RGBA pixel buffer rows (from bottom-left to top-down convention).
  static Uint8List flipRowsVertically(Uint8List source, int width, int height) {
    final stride = width * 4;
    final result = Uint8List(source.length);
    for (int y = 0; y < height; y++) {
      final srcRowStart = y * stride;
      final dstRowStart = (height - 1 - y) * stride;
      result.setRange(dstRowStart, dstRowStart + stride, source, srcRowStart);
    }
    return result;
  }

  /// Captures an offscreen screenshot of the world into an RGBA8 byte buffer with top-down row ordering.
  static Future<Uint8List> captureScreenshot(
    LuminaWorld world, {
    int? width,
    int? height,
    Uint8List? fakePixels,
    bool isInsideFrame = false,
  }) {
    if (world.isCleanedUp) {
      return Future.error(StateError('Cannot capture screenshot on a cleaned up world'));
    }
    if (isInsideFrame) {
      return Future.error(StateError('Cannot capture screenshot while frame is being rendered'));
    }

    final w = width ?? 800;
    final h = height ?? 600;

    final completer = Completer<Uint8List>();
    _registerPending(completer);

    try {
      if (fakePixels != null) {
        final flipped = flipRowsVertically(fakePixels, w, h);
        completer.complete(flipped);
      } else if (!world.hasNativeContext) {
        completer.completeError(StateError('Cannot capture real screenshot without native Filament context'));
      } else {
        final engine = world.filamentEngine;
        final renderer = FilamentRenderer.internal(engine.nativePointer, engine);
        final rawBytes = Uint8List(w * h * 4);
        renderer.readPixels(x: 0, y: 0, width: w, height: h, outPixels: rawBytes);

        final result = flipRowsVertically(rawBytes, w, h);
        completer.complete(result);
      }
    } catch (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
    }

    completer.future.whenComplete(() {
      _unregisterPending(completer);
    }).ignore();

    return completer.future;
  }
}
