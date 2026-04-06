import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';

class CameraState {
  final bool isInitialized;
  final File? referenceImage;
  final File? capturedPhoto;
  final double opacity;
  final bool showOverlay;
  final String? poiId;
  final String? error;

  const CameraState({
    this.isInitialized = false,
    this.referenceImage,
    this.capturedPhoto,
    this.opacity = 0.5,
    this.showOverlay = true,
    this.poiId,
    this.error,
  });

  CameraState copyWith({
    bool? isInitialized,
    File? referenceImage,
    File? capturedPhoto,
    double? opacity,
    bool? showOverlay,
    String? poiId,
    String? error,
    bool clearCapturedPhoto = false,
    bool clearError = false,
  }) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      referenceImage: referenceImage ?? this.referenceImage,
      capturedPhoto:
          clearCapturedPhoto ? null : (capturedPhoto ?? this.capturedPhoto),
      opacity: opacity ?? this.opacity,
      showOverlay: showOverlay ?? this.showOverlay,
      poiId: poiId ?? this.poiId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

  void initialize(String? poiId) {
    state = state.copyWith(poiId: poiId, isInitialized: true, clearError: true);
  }

  void setReferenceImage(File file) {
    state = state.copyWith(referenceImage: file);
  }

  void setOpacity(double value) {
    state = state.copyWith(opacity: value);
  }

  void setShowOverlay(bool value) {
    state = state.copyWith(showOverlay: value);
  }

  void clearCapture() {
    state = state.copyWith(clearCapturedPhoto: true);
  }

  Future<void> capturePhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        state = state.copyWith(capturedPhoto: File(picked.path));
      }
    } catch (e) {
      state = state.copyWith(error: 'Capture failed: $e');
    }
  }

  void setCapturedPhoto(File file) {
    state = state.copyWith(capturedPhoto: file);
  }

  Future<bool> savePhoto(AppDatabase db) async {
    if (state.capturedPhoto == null) return false;
    if (state.poiId == null) return false;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'camera_photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = p.join(photosDir.path, 'photo_$timestamp.jpg');
      await state.capturedPhoto!.copy(savedPath);

      await db.insertMediaAsset(MediaAssetsCompanion.insert(
        id: const Uuid().v4(),
        poiId: state.poiId!,
        type: 'user_photo',
        localUri: savedPath,
        remoteUrl: const Value(null),
        metadata: const Value(null),
      ));

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Save failed: $e');
      return false;
    }
  }

  void setPoiId(String id) {
    state = state.copyWith(poiId: id);
  }
}

final cameraProvider =
    StateNotifierProvider.autoDispose<CameraNotifier, CameraState>(
  (ref) => CameraNotifier(),
);
