class UserEntity {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? country;
  final String? stateRegion;
  final bool isPro;
  final bool isPublic;
  final int streakDays;
  final int totalPredictions;
  final int correctPredictions;

  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.country,
    this.stateRegion,
    required this.isPro,
    required this.isPublic,
    required this.streakDays,
    required this.totalPredictions,
    required this.correctPredictions,
  });

  double get predictionAccuracy =>
      totalPredictions > 0 ? correctPredictions / totalPredictions : 0.0;

  String get displayNameOrUsername => displayName ?? username;
}
