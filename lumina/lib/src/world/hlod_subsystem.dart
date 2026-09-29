import 'package:vector_math/vector_math_64.dart';
import 'subsystem/world_subsystem.dart';
import 'world_partition.dart';

/// Runtime visibility and cross-fade states for HLOD proxy meshes.
enum HlodProxyState {
  hidden,
  fadingIn,
  shown,
  fadingOut,
}

/// Authored or baked metadata associating a spatial grid cell with a merged proxy mesh.
class LuminaHlodProxyDescriptor {
  final int cellX;
  final int cellY;
  final String proxyMeshAsset;
  final Aabb3? bounds;

  LuminaHlodProxyDescriptor({
    required this.cellX,
    required this.cellY,
    required this.proxyMeshAsset,
    this.bounds,
  });
}

/// Runtime instance wrapping an HLOD proxy mesh with continuous opacity for cross-fading.
class LuminaHlodProxy {
  final LuminaHlodProxyDescriptor descriptor;
  HlodProxyState _state;
  double _opacity;

  LuminaHlodProxy({
    required this.descriptor,
    HlodProxyState initialState = HlodProxyState.hidden,
    double initialOpacity = 0.0,
  })  : _state = initialState,
        _opacity = initialOpacity;

  /// Current proxy visibility state.
  HlodProxyState get state => _state;

  /// Current normalized opacity [0.0, 1.0] driving the material fade parameter.
  double get opacity => _opacity;
}

/// Manages distant proxy meshes (HLOD) and handles cross-fading between proxy and real actors.
class LuminaHlodSubsystem extends LuminaWorldSubsystem {
  final Duration crossFadeDuration;
  final int proxyPoolSize;

  final Map<int, LuminaHlodProxyDescriptor> _descriptors = {};
  final Map<int, LuminaHlodProxy> _proxies = {};

  LuminaHlodSubsystem({
    this.crossFadeDuration = const Duration(milliseconds: 500),
    this.proxyPoolSize = 64,
  });

  /// Total number of proxies actively rendering (not hidden).
  int get liveProxyCount => _proxies.values.where((p) => p.state != HlodProxyState.hidden).length;

  /// Available entity slots remaining in the fixed proxy pool.
  int get availablePoolCount => (proxyPoolSize - liveProxyCount).clamp(0, proxyPoolSize);

  static int _cellKey(int x, int y) {
    return (x & 0xFFFFFFFF) | ((y & 0xFFFFFFFF) << 32);
  }

  /// Registers an authored/baked HLOD proxy mesh descriptor for a grid cell.
  void registerProxyDescriptor(LuminaHlodProxyDescriptor d) {
    final key = _cellKey(d.cellX, d.cellY);
    _descriptors[key] = d;
  }

  /// Returns the runtime proxy instance for a cell, if present.
  LuminaHlodProxy? proxyForCell(int x, int y) {
    return _proxies[_cellKey(x, y)];
  }

  /// Reacts to cell state changes from World Partition.
  void onCellStateChanged(int x, int y, CellState oldState, CellState newState) {
    final key = _cellKey(x, y);
    final descriptor = _descriptors[key];
    if (descriptor == null) return;

    var proxy = _proxies[key];
    if (proxy == null) {
      if (liveProxyCount >= proxyPoolSize) {
        return; // Pool budget exceeded
      }
      proxy = LuminaHlodProxy(
        descriptor: descriptor,
        initialState: HlodProxyState.shown,
        initialOpacity: 1.0,
      );
      _proxies[key] = proxy;
    }

    if (newState == CellState.activated || newState == CellState.loaded) {
      if (proxy._state == HlodProxyState.shown || proxy._state == HlodProxyState.fadingIn) {
        proxy._state = HlodProxyState.fadingOut;
      }
    } else if (newState == CellState.unloaded ||
        newState == CellState.unloading ||
        newState == CellState.deactivated) {
      if (proxy._state == HlodProxyState.hidden || proxy._state == HlodProxyState.fadingOut) {
        proxy._state = HlodProxyState.fadingIn;
      }
    }
  }

  @override
  void onWorldTick(double deltaTime) {
    super.onWorldTick(deltaTime);

    // Instantiate distant proxies if below pool size
    for (final entry in _descriptors.entries) {
      final key = entry.key;
      final desc = entry.value;

      if (!_proxies.containsKey(key)) {
        if (liveProxyCount < proxyPoolSize) {
          _proxies[key] = LuminaHlodProxy(
            descriptor: desc,
            initialState: HlodProxyState.shown,
            initialOpacity: 1.0,
          );
        }
      }
    }

    final fadeRate = crossFadeDuration.inMicroseconds > 0
        ? (deltaTime / (crossFadeDuration.inMicroseconds / 1000000.0))
        : 1.0;

    for (final proxy in _proxies.values) {
      if (proxy._state == HlodProxyState.fadingOut) {
        proxy._opacity = (proxy._opacity - fadeRate).clamp(0.0, 1.0);
        if (proxy._opacity <= 0.0) {
          proxy._opacity = 0.0;
          proxy._state = HlodProxyState.hidden;
        }
      } else if (proxy._state == HlodProxyState.fadingIn) {
        proxy._opacity = (proxy._opacity + fadeRate).clamp(0.0, 1.0);
        if (proxy._opacity >= 1.0) {
          proxy._opacity = 1.0;
          proxy._state = HlodProxyState.shown;
        }
      }
    }
  }
}
