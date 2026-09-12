import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';

/// Extra styling knobs not covered by [ThemeData] — board look, radii, and
/// whether the "playful" (kids) presentation is active. Read by widgets via
/// `Theme.of(context).extension<BoardTheme>()!` so the same screens render
/// both the classic and kids skins.
class BoardTheme extends ThemeExtension<BoardTheme> {
  const BoardTheme({
    required this.colorScheme,
    required this.pieceAssets,
    required this.cardRadius,
    required this.playful,
    required this.accentGradient,
  });

  final ChessboardColorScheme colorScheme;
  final PieceAssets pieceAssets;
  final double cardRadius;
  final bool playful;
  final List<Color> accentGradient;

  static final classic = BoardTheme(
    colorScheme: ChessboardColorScheme.brown,
    pieceAssets: PieceSet.cburnett.assets,
    cardRadius: 12,
    playful: false,
    accentGradient: const [Color(0xFF2E3A46), Color(0xFF445566)],
  );

  static final kids = BoardTheme(
    colorScheme: ChessboardColorScheme.blue,
    pieceAssets: PieceSet.merida.assets,
    cardRadius: 24,
    playful: true,
    accentGradient: const [Color(0xFFFF8A65), Color(0xFFFFC947)],
  );

  @override
  BoardTheme copyWith({
    ChessboardColorScheme? colorScheme,
    PieceAssets? pieceAssets,
    double? cardRadius,
    bool? playful,
    List<Color>? accentGradient,
  }) {
    return BoardTheme(
      colorScheme: colorScheme ?? this.colorScheme,
      pieceAssets: pieceAssets ?? this.pieceAssets,
      cardRadius: cardRadius ?? this.cardRadius,
      playful: playful ?? this.playful,
      accentGradient: accentGradient ?? this.accentGradient,
    );
  }

  @override
  BoardTheme lerp(ThemeExtension<BoardTheme>? other, double t) {
    if (other is! BoardTheme) return this;
    return t < 0.5 ? this : other;
  }
}
