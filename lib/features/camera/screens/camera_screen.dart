import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../poi/providers/poi_provider.dart';
import '../providers/camera_provider.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final String? poiId;

  const CameraScreen({super.key, this.poiId});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  static const _cameraChannel =
      MethodChannel('com.example.trip_planner/camera');

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Future.microtask(() {
      ref.read(cameraProvider.notifier).initialize(widget.poiId);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // --- Camera launch ---
  Future<void> _launchCamera() async {
    final camState = ref.read(cameraProvider);

    // Android: native overlay (foreground service) + system camera
    if (Platform.isAndroid && camState.referenceImage != null) {
      try {
        // Check overlay permission
        final hasPermission = await _cameraChannel
            .invokeMethod<bool>('hasOverlayPermission');

        if (hasPermission != true) {
          // Ask user to grant permission
          if (!mounted) return;
          final shouldRequest = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Overlay Permission'),
              content: const Text(
                'To show the reference image over the camera, '
                'we need "Draw over other apps" permission. '
                'You\'ll be taken to Settings to enable it.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Open Settings')),
              ],
            ),
          );

          if (shouldRequest == true) {
            await _cameraChannel.invokeMethod('requestOverlayPermission');
          }
          return;
        }

        // Launch camera with floating overlay
        final photoPath = await _cameraChannel
            .invokeMethod<String>('launchCameraWithOverlay', {
          'imagePath': camState.referenceImage!.path,
        });

        if (photoPath != null && mounted) {
          ref.read(cameraProvider.notifier).setCapturedPhoto(File(photoPath));
        }
        return;
      } catch (e) {
        debugPrint('Overlay camera failed: $e');
      }
    }

    // image_picker fallback (iOS, desktop, or no reference image)
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );

    if (picked != null && mounted) {
      ref.read(cameraProvider.notifier).setCapturedPhoto(File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final camState = ref.watch(cameraProvider);

    if (camState.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(camState.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!camState.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Captured photo -> comparison view
    if (camState.capturedPhoto != null) {
      return _buildComparisonScreen(camState);
    }

    // Reference preview mode
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Reference image or empty state
          if (camState.referenceImage != null)
            Positioned.fill(
              child: Image.file(
                camState.referenceImage!,
                fit: BoxFit.contain,
              ),
            )
          else
            Container(
              color: Colors.grey[900],
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined,
                        size: 64, color: Colors.white24),
                    SizedBox(height: 12),
                    Text('Load a reference image',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Pick an anime screenshot to overlay',
                        style:
                            TextStyle(color: Colors.white24, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Layer 2: Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _FloatingIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Layer 3: Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Pick reference image
                    _FloatingIconButton(
                      icon: Icons.image,
                      size: 52,
                      onTap: _pickReferenceImage,
                    ),
                    // Shutter — launches system camera (with overlay on Android)
                    _ShutterButton(
                      onTap: _launchCamera,
                    ),
                    // Placeholder for symmetry
                    const SizedBox(width: 52),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonScreen(CameraState camState) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              if (camState.referenceImage != null)
                Expanded(
                  child: Column(
                    children: [
                      const SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Reference',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ),
                      ),
                      Expanded(
                        child: Image.file(camState.referenceImage!,
                            fit: BoxFit.contain),
                      ),
                    ],
                  ),
                ),
              if (camState.referenceImage != null)
                Container(width: 1, color: Colors.white24),
              Expanded(
                child: Column(
                  children: [
                    const SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Your Shot',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ),
                    ),
                    Expanded(
                      child: Image.file(camState.capturedPhoto!,
                          fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _FloatingIconButton(
                      icon: Icons.refresh,
                      size: 52,
                      onTap: () =>
                          ref.read(cameraProvider.notifier).clearCapture(),
                    ),
                    FilledButton.icon(
                      onPressed: () => _savePhoto(camState),
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                      ),
                    ),
                    _FloatingIconButton(
                      icon: Icons.close,
                      size: 52,
                      onTap: () =>
                          ref.read(cameraProvider.notifier).clearCapture(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReferenceImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      ref.read(cameraProvider.notifier).setReferenceImage(File(picked.path));
    }
  }

  Future<void> _savePhoto(CameraState camState) async {
    if (camState.poiId == null) {
      await _showPoiPicker();
      return;
    }

    final db = ref.read(databaseProvider);
    final success = await ref.read(cameraProvider.notifier).savePhoto(db);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Photo saved!' : 'Save failed')),
      );
      if (success) {
        ref.read(cameraProvider.notifier).clearCapture();
      }
    }
  }

  Future<void> _showPoiPicker() async {
    final poisMap = await ref.read(allPoisProvider.future);
    final pois = poisMap.values.toList();

    if (!mounted) return;
    if (pois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No POIs yet. Create one first.')),
      );
      return;
    }

    final picked = await showModalBottomSheet<Poi>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: pois.length,
        itemBuilder: (ctx, i) => ListTile(
          leading:
              const Icon(Icons.location_on, color: Colors.white70),
          title: Text(pois[i].name,
              style: const TextStyle(color: Colors.white)),
          subtitle: pois[i].animeSeriesRef != null
              ? Text(pois[i].animeSeriesRef!,
                  style: const TextStyle(color: Colors.white54))
              : null,
          onTap: () => Navigator.pop(ctx, pois[i]),
        ),
      ),
    );

    if (picked != null) {
      ref.read(cameraProvider.notifier).setPoiId(picked.id);
      final db = ref.read(databaseProvider);
      final success =
          await ref.read(cameraProvider.notifier).savePhoto(db);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                success ? 'Photo saved to ${picked.name}!' : 'Save failed'),
          ),
        );
        if (success) {
          ref.read(cameraProvider.notifier).clearCapture();
        }
      }
    }
  }
}

// --- Floating UI components ---

class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _FloatingIconButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ShutterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
