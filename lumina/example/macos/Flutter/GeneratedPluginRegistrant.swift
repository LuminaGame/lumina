//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import lumina_mouse_capture
import media_kit_libs_macos_video
import media_kit_video
import package_info_plus
import volume_controller
import wakelock_plus

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  LuminaMouseCapturePlugin.register(with: registry.registrar(forPlugin: "LuminaMouseCapturePlugin"))
  MediaKitLibsMacosVideoPlugin.register(with: registry.registrar(forPlugin: "MediaKitLibsMacosVideoPlugin"))
  MediaKitVideoPlugin.register(with: registry.registrar(forPlugin: "MediaKitVideoPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  VolumeControllerPlugin.register(with: registry.registrar(forPlugin: "VolumeControllerPlugin"))
  WakelockPlusMacosPlugin.register(with: registry.registrar(forPlugin: "WakelockPlusMacosPlugin"))
}
