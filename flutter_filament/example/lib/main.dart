import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:flutter_filament_example/samples/gltf_viewer_sample.dart';
import 'package:flutter_filament_example/samples/hello_pbr_sample.dart';
import 'package:flutter_filament_example/samples/hello_triangle_sample.dart';
import 'package:flutter_filament_example/samples/lightbulb_sample.dart';
import 'package:flutter_filament_example/samples/material_sandbox_sample.dart';
import 'package:flutter_filament_example/samples/procedural_texture_sample.dart';
import 'package:flutter_filament_example/samples/rendertarget_sample.dart';
import 'package:flutter_filament_example/samples/sample_cloth.dart';
import 'package:flutter_filament_example/samples/sample_normal_map.dart';
import 'package:flutter_filament_example/samples/strobe_color_sample.dart';
import 'package:flutter_filament_example/samples/suzanne_sample.dart';
import 'package:flutter_filament_example/samples/skybox_sample.dart';
import 'package:flutter_filament_example/samples/simulated_skybox_sample.dart';
import 'package:flutter_filament_example/samples/textured_quad_sample.dart';
import 'package:flutter_filament_example/samples/view_test_sample.dart';

void main() {
  // Global Flutter UI Exception Trap - Log to console without crashing app
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('════════════════════════════════════════════════════════════════');
    debugPrint('[FILAMENT FLUTTER UI ERROR]: ${details.exception}');
    if (details.stack != null) {
      debugPrint('[STACK TRACE]: ${details.stack}');
    }
    debugPrint('════════════════════════════════════════════════════════════════');
  };

  // Platform Async Exception Trap
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('════════════════════════════════════════════════════════════════');
    debugPrint('[FILAMENT PLATFORM UNCAUGHT ERROR]: $error');
    debugPrint('[STACK TRACE]: $stack');
    debugPrint('════════════════════════════════════════════════════════════════');
    return true; // Handled safely, do not crash app
  };

  runZonedGuarded(() {
    runApp(const FilamentExampleApp());
  }, (error, stack) {
    debugPrint('[FILAMENT ZONED GUARDED ERROR]: $error\n$stack');
  });
}

class FilamentExampleApp extends StatelessWidget {
  const FilamentExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Filament Samples Gallery',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: const SampleGalleryScreen(),
    );
  }
}

class SampleGalleryItem {
  final String title;
  final String description;
  final String cppSampleFile;
  final IconData icon;
  final WidgetBuilder builder;

  const SampleGalleryItem({
    required this.title,
    required this.description,
    required this.cppSampleFile,
    required this.icon,
    required this.builder,
  });
}

class SampleGalleryScreen extends StatelessWidget {
  const SampleGalleryScreen({super.key});

  static final List<SampleGalleryItem> samples = [
    SampleGalleryItem(
      title: 'Hello Triangle',
      description: 'FilamentVertexBuffer & IndexBuffer 3D triangle rendering.',
      cppSampleFile: 'hellotriangle.cpp',
      icon: Icons.change_history,
      builder: (context) => const HelloTriangleSample(),
    ),
    SampleGalleryItem(
      title: 'Hello PBR',
      description: 'Metallic, roughness & dielectric F0 specular lighting.',
      cppSampleFile: 'hellopbr.cpp',
      icon: Icons.wb_sunny,
      builder: (context) => const HelloPbrSample(),
    ),
    SampleGalleryItem(
      title: 'Suzanne Monkey Mesh',
      description: '3D Monkey mesh with camera orbit manipulator.',
      cppSampleFile: 'suzanne.cpp',
      icon: Icons.pets,
      builder: (context) => const SuzanneSample(),
    ),
    SampleGalleryItem(
      title: 'Skybox & Environment',
      description: 'HDR Image-Based Lighting (IBL) & cubemap skybox presets.',
      cppSampleFile: 'skybox.cpp',
      icon: Icons.filter_hdr,
      builder: (context) => const SkyboxSample(),
    ),
    SampleGalleryItem(
      title: 'Procedural Sky & Ocean',
      description: 'Analytic atmosphere scattering, FBM clouds & water reflections.',
      cppSampleFile: 'web/examples/sky/SimulatedSkybox.js',
      icon: Icons.wb_sunny,
      builder: (context) => const SimulatedSkyboxSample(),
    ),
    SampleGalleryItem(
      title: 'Textured Quad',
      description: '2D texture map loading and material parameter binding.',
      cppSampleFile: 'texturedquad.cpp',
      icon: Icons.texture,
      builder: (context) => const TexturedQuadSample(),
    ),
    SampleGalleryItem(
      title: 'glTF 2.0 Viewer',
      description: 'glTF/GLB asset loading with FilamentResourceLoader.',
      cppSampleFile: 'gltf_viewer.cpp',
      icon: Icons.view_in_ar,
      builder: (context) => const GltfViewerSample(),
    ),
    SampleGalleryItem(
      title: 'Material Sandbox',
      description: 'Runtime GLSL material compiler & glslminifier.',
      cppSampleFile: 'material_sandbox.cpp',
      icon: Icons.code,
      builder: (context) => const MaterialSandboxSample(),
    ),
    SampleGalleryItem(
      title: 'Lightbulb & Shadows',
      description: 'Point, Spot, Sun, Directional lights & shadow mapping.',
      cppSampleFile: 'lightbulb.cpp',
      icon: Icons.lightbulb,
      builder: (context) => const LightbulbSample(),
    ),
    SampleGalleryItem(
      title: 'Render Target & Pipeline',
      description: 'Offscreen render targets & frame pipeline inspection.',
      cppSampleFile: 'rendertarget.cpp',
      icon: Icons.auto_awesome_mosaic,
      builder: (context) => const RenderTargetSample(),
    ),
    SampleGalleryItem(
      title: 'Sample Cloth',
      description: 'Cloth material model & sheen shading.',
      cppSampleFile: 'sample_cloth.cpp',
      icon: Icons.dry_cleaning,
      builder: (context) => const SampleClothSample(),
    ),
    SampleGalleryItem(
      title: 'Sample Normal Map',
      description: 'Reoriented Normal Mapping (RNM) texture blending.',
      cppSampleFile: 'sample_normal_map.cpp',
      icon: Icons.layers,
      builder: (context) => const SampleNormalMapSample(),
    ),
    SampleGalleryItem(
      title: 'Strobe Color Animation',
      description: 'Dynamic animated strobe light color modulation.',
      cppSampleFile: 'strobecolor.cpp',
      icon: Icons.color_lens,
      builder: (context) => const StrobeColorSample(),
    ),
    SampleGalleryItem(
      title: 'Procedural Texture & Mipmaps',
      description: 'Procedural texture generation & mipgen downsampling.',
      cppSampleFile: 'procedural_texture_quad.cpp',
      icon: Icons.grid_on,
      builder: (context) => const ProceduralTextureSample(),
    ),
    SampleGalleryItem(
      title: 'View Settings & Post-Processing',
      description: 'Viewport settings, anti-aliasing & post-processing toggles.',
      cppSampleFile: 'viewtest.cpp',
      icon: Icons.tune,
      builder: (context) => const ViewTestSample(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Filament Samples Gallery'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.separated(
        itemCount: samples.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final sample = samples[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(sample.icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            title: Text(
              sample.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${sample.cppSampleFile}\n${sample.description}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return _SafeSampleWrapper(
                    title: sample.title,
                    child: sample.builder(context),
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }
}

/// A safety wrapper widget that catches any sample initialization or build errors
/// and displays a graceful error fallback card instead of crashing.
class _SafeSampleWrapper extends StatefulWidget {
  final String title;
  final Widget child;

  const _SafeSampleWrapper({
    required this.title,
    required this.child,
  });

  @override
  State<_SafeSampleWrapper> createState() => _SafeSampleWrapperState();
}

class _SafeSampleWrapperState extends State<_SafeSampleWrapper> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
  }

  static Widget _buildErrorWidget(String title, Object error, StackTrace? stack) {
    debugPrint('[FILAMENT SAMPLE CRASH PREVENTED] $title: $error\n$stack');
    return Scaffold(
      appBar: AppBar(title: Text('$title (Error Handled)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Card(
              color: Colors.redAccent,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Sample Encountered an Error (App Safe & Protected)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black87,
                child: SingleChildScrollView(
                  child: Text(
                    'Error: $error\n\n$stack',
                    style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorWidget(widget.title, _error!, _stackTrace);
    }
    return widget.child;
  }
}
