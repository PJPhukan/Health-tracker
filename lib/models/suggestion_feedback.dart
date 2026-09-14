class SuggestionFeedback {
  final int? id;
  final String suggestionId;
  final String rating; // 'positive' or 'negative'
  final String? reason;
  final String? comment;
  final String timestamp;
  final String? syncId;

  const SuggestionFeedback({
    this.id,
    required this.suggestionId,
    required this.rating,
    this.reason,
    this.comment,
    required this.timestamp,
    this.syncId,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'suggestionId': suggestionId,
        'rating': rating,
        if (reason != null && reason!.isNotEmpty) 'reason': reason,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
        'timestamp': timestamp,
        if (syncId != null) 'syncId': syncId,
      };

  factory SuggestionFeedback.fromMap(Map<String, Object?> map) =>
      SuggestionFeedback(
        id: map['id'] as int?,
        suggestionId: map['suggestionId'] as String? ?? '',
        rating: map['rating'] as String? ?? 'positive',
        reason: map['reason'] as String?,
        comment: map['comment'] as String?,
        timestamp: map['timestamp'] as String? ?? '',
        syncId: map['syncId'] as String?,
      );
}
