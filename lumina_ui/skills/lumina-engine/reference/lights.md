# Lights: level lights, sky and sun, the Blueprint Point Light

## Level lights

- `spawn_actor` with `type` `DirectionalLight`, `PointLight` or `SpotLight`, then `set_actor_property`:
  `light_intensity`, `light_color` (`#RRGGBB`), `cast_shadows`; other light properties as
  `"<component type>.<property>"`, e.g. `LuminaPointLightComponent.attenuationRadius`,
  `LuminaSpotLightComponent.innerConeAngle` / `outerConeAngle`.
- **Units**: directional light intensity in **lux** (a sun: about 100 000); point and spot lights in **lumens**
  (new ones: 50 000); `attenuationRadius` in cm (1000 by default: the light reaches 10 m); cone angles in
  degrees (inner 30, outer 45).
- A light shines along its forward axis (+Y at rotation 0). To aim a spot or directional light down, give it a
  negative pitch (rotation index 0; -90 is straight down, a sun about -50); yaw (index 2) turns it around Z.
- Point and spot lights cast no shadows unless `cast_shadows` is on (the directional light's is on).

## Sky, sun, fog, exposure

- `set_level_environment`: sky (`sky_mode` `color` / `environment`, `sky_color`, `sky_intensity`, `ibl_intensity`,
  `sky_environment_asset`), sun (`time_of_day` 0–24 h, `sun_intensity_lux`, `sun_kelvin`, `sun_color`,
  `cast_shadows`, `sun_disc_visible`), fog (`fog_enabled`, `fog_density`, `fog_color`) and post (`exposure`,
  `bloom_intensity`, `vignette`, `saturation`, `contrast`); it creates the Sun and sky actors when missing.
  `get_level_settings` reads them back; `reset_level_environment` restores the defaults.
- A dark scene in Play: check that the level has a directional light or an `Environment`, and the `exposure`.

## Lights in a Blueprint

- **Point Light component**: `add_blueprint_component` with `type` `LuminaPointLightComponent` (optionally
  `parent`: a scene component to follow), then `set_blueprint_component_property`: `intensity` (lumens, default
  10 000), `colorHex` (`#RRGGBB`), `attenuationRadius` (cm, default 1000), `castShadows` (default off). It moves
  with the actor: lamps, pickups, muzzle flashes.
- **Spot Light component**: `add_blueprint_component` with `type` `LuminaSpotLightComponent` (optionally
  `parent`: a scene component to follow), then `set_blueprint_component_property`: `intensity` (lumens, default
  10 000), `colorHex` (`#RRGGBB`), `attenuationRadius` (cm, default 1000), `innerConeAngle` (degrees, default 30),
  `outerConeAngle` (degrees, default 45), `castShadows` (default off). Shines along the component's forward axis (+Y).
- A glow without lighting anything: an emissive material (`filament-materials`), cheaper than a light.

## Checking

Lights show in the editor viewport (`viewport_screenshot`) and in Play; compare both after `start_pie` + 1.5 s.
