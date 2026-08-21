enum BubbleWidthTier { normal, wide, full }

BubbleWidthTier bubbleWidthTierFor(String text) {
  if (text.contains('```mermaid') || text.contains('```svg')) {
    return BubbleWidthTier.full;
  }

  final lines = text.split('\n');
  final hasVeryLongLine = lines.any((line) => line.length > 120);
  if (hasVeryLongLine) return BubbleWidthTier.full;

  final hasTable = text.contains('|') && text.contains('---');
  final hasCodeBlock = text.contains('```');
  final hasLongLine = lines.any((line) => line.length > 80);
  if (hasTable || hasCodeBlock || hasLongLine) return BubbleWidthTier.wide;

  return BubbleWidthTier.normal;
}

double bubbleMaxWidthFor(BubbleWidthTier tier, double availableWidth) {
  return switch (tier) {
    BubbleWidthTier.normal => 560,
    BubbleWidthTier.wide => 760,
    BubbleWidthTier.full => availableWidth * 0.94,
  };
}
