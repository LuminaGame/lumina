part of '../blueprint_function_library.dart';

// --- Audio ----------------------------------------------------------

LuminaAudioSubsystem? _audio(LuminaActor self) {
  final w = self.world;
  if (w == null) return null;
  return w.getSubsystem<LuminaAudioSubsystem>() ?? w.registerSubsystem(LuminaAudioSubsystem());
}

LuminaAudioComponent? _voice(LuminaActor self, String sound, double volume, double pitch, double startTime,
    {Vector3? location, LuminaSceneComponent? parent, bool spatialized = false, bool autoDestroy = false}) {
  if (sound.isEmpty || _audio(self) == null) return null;
  final component = LuminaAudioComponent(
    sound: LuminaSoundWave(assetPath: sound),
    spatialized: spatialized,
    volumeMultiplier: volume,
    pitchMultiplier: pitch,
    location: location == null ? null : LuminaBlueprintFunctionLibrary.toRuntime(location),
  );
  final owner = parent?.owner ?? self;
  owner.addComponent(component);
  if (parent != null) component.attachToComponent(parent);
  if (autoDestroy) {
    component.onAudioFinished = () => owner.removeComponent(component);
  }
  component.play();
  return component;
}

void _playSound2D(LuminaActor self, String sound, [double volume = 1.0, double pitch = 1.0, double startTime = 0.0]) =>
    _voice(self, sound, volume, pitch, startTime, autoDestroy: true);

void _playSoundAtLocation(LuminaActor self, String sound, Vector3 location, [double volume = 1.0, double pitch = 1.0, double startTime = 0.0]) {
  // World-space: the voice sits on its own actor at the location.
  if (sound.isEmpty || _audio(self) == null) return;
  final world = self.world;
  if (world == null) return;
  final holder = LuminaActor(location: LuminaBlueprintFunctionLibrary.toRuntime(location));
  final component = LuminaAudioComponent(sound: LuminaSoundWave(assetPath: sound), spatialized: true, volumeMultiplier: volume, pitchMultiplier: pitch);
  holder.addComponent(component);
  component.onAudioFinished = holder.destroy;
  world.spawnActorImmediately(holder);
  component.play();
}

Object? _spawnSound2D(LuminaActor self, String sound, [double volume = 1.0, double pitch = 1.0, double startTime = 0.0, bool autoDestroy = false]) =>
    _voice(self, sound, volume, pitch, startTime, autoDestroy: autoDestroy);

Object? _spawnSoundAttached(LuminaActor self, String sound, Object? attachTo, [String socketName = '', double volume = 1.0, double pitch = 1.0]) =>
    _voice(self, sound, volume, pitch, 0.0, parent: attachTo is LuminaSceneComponent ? attachTo : self.rootComponent, spatialized: true);

void _stopSound(LuminaActor self, Object? target) {
  if (target is LuminaAudioComponent) target.stop();
}

void _fadeOutSound(LuminaActor self, Object? target, [double fadeOutDuration = 1.0]) {
  if (target is LuminaAudioComponent) target.fadeOut(fadeOutDuration, stopWhenDone: true);
}

void _setSoundVolume(LuminaActor self, Object? target, [double volume = 1.0]) {
  if (target is LuminaAudioComponent) target.volumeMultiplier = volume;
}

void _setSoundPitch(LuminaActor self, Object? target, [double pitch = 1.0]) {
  if (target is LuminaAudioComponent) target.pitchMultiplier = pitch;
}

bool _isSoundPlaying(LuminaActor self, Object? target) => target is LuminaAudioComponent && target.isPlaying;

void _setSoundClassVolume(LuminaActor self, [String soundClass = 'Master', double volume = 1.0]) =>
    _audio(self)?.setClassVolume(soundClass, volume);

// --- Video ----------------------------------------------------------

Object? _openVideo(LuminaActor self, String source, [bool autoPlay = false, bool loop = false, double volume = 1.0]) {
  if (source.isEmpty) return null;
  final controller = LuminaVideoController(
    source: source,
    autoPlay: autoPlay,
    loop: loop,
    initialVolume: volume,
  );
  unawaited(controller.initialize());
  return controller;
}

void _playVideo(LuminaActor self, Object? target) {
  if (target is LuminaVideoController) target.play();
}

void _pauseVideo(LuminaActor self, Object? target) {
  if (target is LuminaVideoController) target.pause();
}

void _stopVideo(LuminaActor self, Object? target) {
  if (target is LuminaVideoController) target.stop();
}

void _seekVideo(LuminaActor self, Object? target, [double seconds = 0.0]) {
  if (target is LuminaVideoController) target.seekToSeconds(seconds);
}

void _setVideoVolume(LuminaActor self, Object? target, [double volume = 1.0]) {
  if (target is LuminaVideoController) target.setVolume(volume);
}

void _setVideoRate(LuminaActor self, Object? target, [double rate = 1.0]) {
  if (target is LuminaVideoController) target.setPlaybackSpeed(rate);
}

void _setVideoLooping(LuminaActor self, Object? target, [bool loop = false]) {
  if (target is LuminaVideoController) target.setLooping(loop);
}

bool _isVideoPlaying(LuminaActor self, Object? target) =>
    target is LuminaVideoController && target.value.isPlaying;

double _getVideoPosition(LuminaActor self, Object? target) =>
    target is LuminaVideoController ? target.value.position.inMilliseconds / 1000.0 : 0.0;

double _getVideoDuration(LuminaActor self, Object? target) =>
    target is LuminaVideoController ? target.value.duration.inMilliseconds / 1000.0 : 0.0;

// --- Animation ------------------------------------------------------

LuminaAnimatedMeshComponent? _skeletalMesh(LuminaActor self) {
  LuminaAnimatedMeshComponent? first;
  for (final c in self.components) {
    if (c is LuminaAnimBlueprintInstance) return c.mesh;
    if (c is LuminaAnimatedMeshComponent) first ??= c;
  }
  return first;
}

LuminaAnimBlueprintInstance? _animInstance(LuminaActor self) {
  for (final c in self.components) {
    if (c is LuminaAnimBlueprintInstance) return c;
  }
  return null;
}

double _playAnimMontage(LuminaActor self, String montage, [double playRate = 1.0, String startSection = '']) {
  final doc = LuminaBlueprintMontages.lookup(montage);
  final runtime = _runtime(self);
  final mesh = _skeletalMesh(self);
  if (doc == null || runtime == null) {
    developer.log("Play Anim Montage: '$montage' is not a registered montage.", name: 'Blueprint', level: 900);
    return 0.0;
  }
  if (runtime.blueprintMontage != null) runtime.endBlueprintMontage(interrupted: true);
  final length = mesh != null && mesh.hasClip(doc.clip) ? mesh.clipDuration(doc.clip) : doc.length;
  final rate = playRate == 0.0 ? 1.0 : playRate.abs();
  final playback = LuminaBlueprintMontagePlayback(doc, playRate: rate);
  final section = doc.section(startSection);
  if (section != null) playback.position = section.startTime;
  runtime.blueprintMontage = playback;
  runtime.blueprintMontageMesh = mesh;
  if (mesh != null) {
    final anim = _animInstance(self);
    if (anim != null && identical(anim.mesh, mesh)) anim.montagePlaying = true;
    if (mesh.hasClip(doc.clip)) {
      mesh.play(doc.clip, startTime: playback.position, loop: false);
      mesh.playRate = rate;
    }
  }
  return length / rate;
}

void _stopAnimMontage(LuminaActor self, [double blendOutTime = 0.25]) => _runtime(self)?.endBlueprintMontage(interrupted: true);

void _montageJumpToSection(LuminaActor self, String sectionName) => _runtime(self)?.blueprintMontage?.jumpToSection(sectionName);

void _montageSetNextSection(LuminaActor self, String sectionName, String nextSection) {
  final playback = _runtime(self)?.blueprintMontage;
  if (playback != null && playback.montage.section(sectionName) != null) playback.nextSections[sectionName] = nextSection;
}

bool _isPlayingMontage(LuminaActor self) => _runtime(self)?.blueprintMontage != null;

String _getCurrentMontage(LuminaActor self) => _runtime(self)?.blueprintMontage?.montage.name ?? '';

Object? _getAnimInstance(LuminaActor self) => _animInstance(self);

void _setAnimVariable(LuminaActor self, String name, Object? value) {
  for (final c in self.components) {
    if (c is LuminaAnimBlueprintInstance) c.variables[name] = value;
  }
}

Object? _getAnimVariable(LuminaActor self, String name) => _animInstance(self)?.variables[name];

// --- Effects --------------------------------------------------------

LuminaParticleEmitterConfig _particleTemplate(String asset) {
  final config = LuminaBlueprintParticleTemplates.lookup(asset);
  if (config != null) return config;
  developer.log("Spawn Emitter: '$asset' is not a registered particle asset; the default emitter plays.", name: 'Blueprint', level: 900);
  return LuminaParticleEmitterConfig();
}

Object? _spawnEmitterAtLocation(LuminaActor self, String emitterTemplate, Vector3 location,
    [LuminaRotator? rotation, Vector3? scale, bool autoDestroy = true]) {
  final world = self.world;
  if (world == null) return null;
  final component = LuminaParticleSystemComponent(config: _particleTemplate(emitterTemplate), autoActivate: true);
  final holder = LuminaActor(root: component, location: LuminaBlueprintFunctionLibrary.toRuntime(location), rotation: _quat(rotation ?? const LuminaRotator.zero()));
  if (scale != null) holder.actorScale = _scaleToRuntime(scale);
  if (autoDestroy) component.onSystemFinished = holder.destroy;
  world.spawnActorImmediately(holder);
  return component;
}

Object? _spawnEmitterAttached(LuminaActor self, String emitterTemplate, Object? attachToComponent,
    [String socketName = '', bool autoDestroy = true]) {
  final parent = attachToComponent is LuminaSceneComponent ? attachToComponent : self.rootComponent;
  final owner = parent.owner ?? self;
  final component = LuminaParticleSystemComponent(config: _particleTemplate(emitterTemplate), autoActivate: true);
  owner.addComponent(component);
  component.attachToComponent(parent);
  if (autoDestroy) component.onSystemFinished = () => owner.removeComponent(component);
  return component;
}

void _activateParticleSystem(LuminaActor self, Object? target, [bool reset = false]) {
  if (target is LuminaParticleSystemComponent) target.activate(reset: reset);
}

Object? _spawnDecalAtLocation(LuminaActor self, String decalMaterial, Vector3 decalSize, Vector3 location,
    [LuminaRotator? rotation, double lifeSpan = 0.0]) {
  developer.log("Spawn Decal at Location ('$decalMaterial'): not supported, no decal component.", name: 'Blueprint');
  return null;
}

void _deactivateParticleSystem(LuminaActor self, Object? target) {
  if (target is LuminaParticleSystemComponent) target.deactivate();
}

void _setParticleParameter(LuminaActor self, Object? target, String parameterName, Object? value) {
  if (target is LuminaParticleSystemComponent && parameterName.isNotEmpty) target.parameters[parameterName] = value is Vector3 ? _list3(value) : value;
}

// --- Material -------------------------------------------------------

Object? _createDynamicMaterialInstance(LuminaActor self, Object? target, [int elementIndex = 0]) {
  if (target is! LuminaStaticMeshComponent) return null;
  // At BeginPlay the Material Override asset is usually still loading: the
  // instance is made once it has, with the parameters set meanwhile.
  if (target.dynamicMaterialInstance(elementIndex) == null && target.isMaterialLoading(elementIndex)) {
    return LuminaPendingDynamicMaterialInstance(target.materialOverrideWhenLoaded(elementIndex).then((loaded) {
      if (loaded == null) {
        developer.log('Create Dynamic Material Instance: section $elementIndex of ${target.meshAssetPath} has no material',
            name: 'Blueprint', level: 900);
        return null;
      }
      return target.createDynamicMaterialInstance(primitiveIndex: elementIndex);
    }));
  }
  try {
    return target.createDynamicMaterialInstance(primitiveIndex: elementIndex);
  } catch (e) {
    developer.log('Create Dynamic Material Instance: $e', name: 'Blueprint', level: 900);
    return null;
  }
}

bool _hasParameter(Object? target, String name) {
  if (target is! LuminaDynamicMaterialInstance) return false;
  if (target.material.hasParameter(name)) return true;
  developer.log("Material parameter '$name' does not exist on ${target.material.assetPath}.", name: 'Blueprint', level: 900);
  return false;
}

void _setScalarParameterValue(LuminaActor self, Object? target, String parameterName, [double value = 0.0]) {
  if (target is LuminaPendingDynamicMaterialInstance) {
    target.parameterValues[parameterName] = value;
    return target.whenReady((d) => _setScalarParameterValue(self, d, parameterName, value));
  }
  if (_hasParameter(target, parameterName)) (target as LuminaDynamicMaterialInstance).setScalar(parameterName, value);
}

void _setVectorParameterValue(LuminaActor self, Object? target, String parameterName, List<double> value) {
  if (target is LuminaPendingDynamicMaterialInstance) {
    target.parameterValues[parameterName] = List<double>.of(value);
    return target.whenReady((d) => _setVectorParameterValue(self, d, parameterName, value));
  }
  if (_hasParameter(target, parameterName)) {
    (target as LuminaDynamicMaterialInstance).setVector(parameterName, Vector4(_at(value, 0), _at(value, 1), _at(value, 2), _at(value, 3)));
  }
}

void _setTextureParameterValue(LuminaActor self, Object? target, String parameterName, String texture) {
  if (target is LuminaPendingDynamicMaterialInstance) {
    if (texture.isNotEmpty) target.parameterValues[parameterName] = texture;
    return target.whenReady((d) => _setTextureParameterValue(self, d, parameterName, texture));
  }
  if (!_hasParameter(target, parameterName) || texture.isEmpty) return;
  final instance = target as LuminaDynamicMaterialInstance;
  instance.parameterValues[parameterName] = texture;
  // A texture asset (`contents/…/T_x.lmas`) or an image file, loaded as a
  // material's own textures are; one that cannot be loaded is logged there.
  unawaited(instance.setTextureAsset(parameterName, texture).catchError((Object e) {
    developer.log("Set Texture Parameter Value: cannot bind '$texture': $e", name: 'Blueprint', level: 900);
    return false;
  }));
}

double _getScalarParameterValue(LuminaActor self, Object? target, String parameterName) {
  if (target is LuminaPendingDynamicMaterialInstance) {
    final remembered = target.parameterValues[parameterName];
    if (remembered is num) return remembered.toDouble();
    return target.instance == null ? 0.0 : _getScalarParameterValue(self, target.instance, parameterName);
  }
  if (target is! LuminaDynamicMaterialInstance) return 0.0;
  final remembered = target.parameterValues[parameterName];
  if (remembered is num) return remembered.toDouble();
  return target.material.hasParameter(parameterName) ? target.getFloat(parameterName) : 0.0;
}

void _setMaterialScalarParameterOnActor(LuminaActor self, Object? target, String parameterName, [double value = 0.0]) {
  for (final c in _target(self, target).components) {
    if (c is! LuminaStaticMeshComponent) continue;
    for (var i = 0; i < 8; i++) {
      if (c.materialOverride(i) == null) continue;
      final dyn = c.dynamicMaterialInstance(i) ?? LuminaBlueprintFunctionLibrary.createDynamicMaterialInstance(self, c, i);
      if (dyn is LuminaDynamicMaterialInstance && dyn.material.hasParameter(parameterName)) dyn.setScalar(parameterName, value);
    }
  }
}

// --- Light ----------------------------------------------------------

void _setLightIntensity(LuminaActor self, Object? target, [double newIntensity = 0.0]) {
  if (target is LuminaLightComponent) target.intensity = newIntensity;
}

double _getLightIntensity(LuminaActor self, Object? target) => target is LuminaLightComponent ? target.intensity : 0.0;

void _setLightColor(LuminaActor self, Object? target, List<double> newLightColor) {
  if (target is LuminaLightComponent) target.color = Vector3(_at(newLightColor, 0), _at(newLightColor, 1), _at(newLightColor, 2));
}

void _setLightVisibility(LuminaActor self, Object? target, [bool newVisibility = true]) {
  if (target is LuminaLightComponent) target.visible = newVisibility;
}

void _toggleLightVisibility(LuminaActor self, Object? target) {
  if (target is LuminaLightComponent) target.visible = !target.visible;
}

void _setLightRadius(LuminaActor self, Object? target, [double newRadius = 1000.0]) {
  if (target is LuminaPointLightComponent) target.falloffRadius = newRadius;
  if (target is LuminaSpotLightComponent) target.falloffRadius = newRadius;
}

void _setSpotLightAngles(LuminaActor self, Object? target, [double innerConeAngle = 0.0, double outerConeAngle = 44.0]) {
  if (target is LuminaSpotLightComponent) {
    final outer = outerConeAngle.clamp(0.0, 90.0);
    target.setConeAngles(innerDegrees: innerConeAngle.clamp(0.0, outer), outerDegrees: outer);
  }
}

void _log2(LuminaActor self, String message, int level) {
  LuminaBlueprintFunctionLibrary.onLog?.call(self, message, level);
  developer.log('${self is LuminaBlueprintRuntime ? self.blueprintClassName : self.runtimeType}: $message', name: 'Blueprint', level: level);
}

void _logWarning(LuminaActor self, String inString) => _log2(self, inString, 900);

void _logError(LuminaActor self, String inString) => _log2(self, inString, 1000);

void _breakpoint(LuminaActor self) {}

void _printText(LuminaActor self, String inText,
        [bool printToScreen = true, bool printToLog = true, List<double>? textColor, double duration = 2.0, String key = '']) =>
    LuminaBlueprintFunctionLibrary.printString(self, inText, printToScreen, printToLog, textColor, duration, key);

void _debug(LuminaActor self, LuminaDebugShape Function(double now) make) {
  final world = self.world;
  if (world == null) return;
  final shape = make(world.realTimeSeconds);
  world.addDebugShape(shape);
  _runtime(self)?.debugShapes.add(shape);
}

void _drawDebugLine(LuminaActor self, Vector3 lineStart, Vector3 lineEnd, [List<double>? lineColor, double duration = 0.0, double thickness = 0.0]) =>
    _debug(self, (now) => LuminaDebugShape(kind: LuminaDebugShapeKind.line, points: [LuminaBlueprintFunctionLibrary.toRuntime(lineStart), LuminaBlueprintFunctionLibrary.toRuntime(lineEnd)], color: LuminaBlueprintFunctionLibrary._c(lineColor), thickness: thickness, duration: duration, expiresAt: now + duration));

void _drawDebugSphere(LuminaActor self, Vector3 center, [double radius = 100.0, int segments = 12, List<double>? lineColor, double duration = 0.0, double thickness = 0.0]) =>
    _debug(self, (now) => LuminaDebugShape(kind: LuminaDebugShapeKind.sphere, points: [LuminaBlueprintFunctionLibrary.toRuntime(center)], radius: radius, color: LuminaBlueprintFunctionLibrary._c(lineColor), thickness: thickness, duration: duration, expiresAt: now + duration));

void _drawDebugBox(LuminaActor self, Vector3 center, Vector3 extent, [LuminaRotator? rotation, List<double>? lineColor, double duration = 0.0, double thickness = 0.0]) =>
    _debug(self, (now) => LuminaDebugShape(kind: LuminaDebugShapeKind.box, points: [LuminaBlueprintFunctionLibrary.toRuntime(center)], extent: _scaleToRuntime(extent), rotation: _quat(rotation ?? const LuminaRotator.zero()), color: LuminaBlueprintFunctionLibrary._c(lineColor), thickness: thickness, duration: duration, expiresAt: now + duration));

void _drawDebugPoint(LuminaActor self, Vector3 position, [double size = 4.0, List<double>? pointColor, double duration = 0.0]) =>
    _debug(self, (now) => LuminaDebugShape(kind: LuminaDebugShapeKind.point, points: [LuminaBlueprintFunctionLibrary.toRuntime(position)], radius: size, color: LuminaBlueprintFunctionLibrary._c(pointColor), duration: duration, expiresAt: now + duration));

void _drawDebugArrow(LuminaActor self, Vector3 lineStart, Vector3 lineEnd, [double arrowSize = 10.0, List<double>? lineColor, double duration = 0.0, double thickness = 0.0]) =>
    _debug(self, (now) => LuminaDebugShape(kind: LuminaDebugShapeKind.arrow, points: [LuminaBlueprintFunctionLibrary.toRuntime(lineStart), LuminaBlueprintFunctionLibrary.toRuntime(lineEnd)], radius: arrowSize, color: LuminaBlueprintFunctionLibrary._c(lineColor), thickness: thickness, duration: duration, expiresAt: now + duration));

void _drawDebugString(LuminaActor self, Vector3 textLocation, [String text = '', List<double>? textColor, double duration = 0.0]) =>
    _debug(self, (now) => LuminaDebugShape(kind: LuminaDebugShapeKind.string, points: [LuminaBlueprintFunctionLibrary.toRuntime(textLocation)], text: text, color: LuminaBlueprintFunctionLibrary._c(textColor), duration: duration, expiresAt: now + duration));

void _drawDebugCapsule(LuminaActor self, Vector3 center, [double halfHeight = 80.0, double radius = 40.0, LuminaRotator? rotation, List<double>? lineColor, double duration = 0.0, double thickness = 0.0]) =>
    _debug(self, (now) => LuminaDebugShape(kind: LuminaDebugShapeKind.capsule, points: [LuminaBlueprintFunctionLibrary.toRuntime(center)], radius: radius, extent: Vector3(0, halfHeight, 0), rotation: _quat(rotation ?? const LuminaRotator.zero()), color: LuminaBlueprintFunctionLibrary._c(lineColor), thickness: thickness, duration: duration, expiresAt: now + duration));

void _flushDebugShapes(LuminaActor self) {
  self.world?.flushDebugShapes();
  _runtime(self)?.debugShapes.clear();
}
