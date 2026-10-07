import 'package:lumina_editor_data/lumina_editor.dart';

class QuickOpenMatch {
  final RealAssetInfo asset;
  final List<int> matchIndices;
  final int score;

  QuickOpenMatch(this.asset, this.matchIndices, this.score);
}

List<QuickOpenMatch> fuzzyMatchAssets(String query, List<RealAssetInfo> assets) {
  if (query.isEmpty) return [];

  final queryLower = query.toLowerCase();
  final results = <QuickOpenMatch>[];

  for (final asset in assets) {
    final String targetStr = asset.relativePath;
    final targetLower = targetStr.toLowerCase();

    int qIdx = 0;
    final matchIndices = <int>[];
    for (int tIdx = 0; tIdx < targetLower.length; tIdx++) {
      if (qIdx < queryLower.length && targetLower[tIdx] == queryLower[qIdx]) {
        matchIndices.add(tIdx);
        qIdx++;
      }
    }

    if (qIdx == queryLower.length) {
      int score = targetLower.length - matchIndices.length;
      if (targetLower.startsWith(queryLower)) score -= 1000;
      results.add(QuickOpenMatch(asset, matchIndices, score));
    }
  }

  results.sort((a, b) => a.score.compareTo(b.score));
  return results;
}
