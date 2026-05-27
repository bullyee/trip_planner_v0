import '../../../core/database/database.dart';
import '../models/vlog_frame_source.dart';

class VlogRepository {
  final AppDatabase db;

  VlogRepository(this.db);

  // get vlog frame data by RoI
  Future<List<VlogFrameSource>> getVlogFramesByRoi(String roiId) async {
    final pois = await db.getPoisByRoi(roiId);
    final frames = <VlogFrameSource>[];

    for (final poi in pois) {
      final assets = await db.getMediaAssetsByPoi(poi.id);
      final referenceImages = await db.getReferenceImagesByPoi(poi.id);

      final userPhotos = assets.where((assets) {
        return assets.type == 'user_photo';
      });

      for (final photo in userPhotos) {
        final linkedReference = photo.referenceImageId == null
            ? null
            : referenceImages
                .where((image) => image.id == photo.referenceImageId)
                .firstOrNull;
        final referenceImagePath = linkedReference?.localUri ??
            (referenceImages.isNotEmpty ? referenceImages.first.localUri : null) ??
            poi.coverImageUri;

        frames.add(
          VlogFrameSource(
            poiName: poi.name,
            userImagePath: photo.localUri,
            referenceImagePath: referenceImagePath,
          ),
        );
      }
    }

    return frames;
  }

  String formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
           "${date.month.toString().padLeft(2, '0')}-"
           "${date.day.toString().padLeft(2, '0')}";
  }
}
