class AiInsightEntity {
  final String id;
  final String category;
  final String severity;
  final String title;
  final String body;
  final List<String> actionItems;
  final bool isRead;
  final bool isDismissed;
  final DateTime createdAt;

  const AiInsightEntity({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.body,
    required this.actionItems,
    required this.isRead,
    required this.isDismissed,
    required this.createdAt,
  });

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
}

class WhyLosingIssue {
  final String issue;
  final String severity;
  final String evidence;
  final double? impactUsd;
  final String explanation;

  const WhyLosingIssue({
    required this.issue,
    required this.severity,
    required this.evidence,
    this.impactUsd,
    required this.explanation,
  });
}

class BehavioralMistake {
  final String mistake;
  final int count;
  final double? estimatedLossUsd;
  final String howToFix;

  const BehavioralMistake({
    required this.mistake,
    required this.count,
    this.estimatedLossUsd,
    required this.howToFix,
  });
}

class WhyLosingReport {
  final String overallAssessment;
  final List<WhyLosingIssue> primaryIssues;
  final List<BehavioralMistake> behavioralMistakes;
  final List<String> actionableSteps;
  final double? estimatedRecoverableLoss;
  final DateTime generatedAt;

  const WhyLosingReport({
    required this.overallAssessment,
    required this.primaryIssues,
    required this.behavioralMistakes,
    required this.actionableSteps,
    this.estimatedRecoverableLoss,
    required this.generatedAt,
  });
}
