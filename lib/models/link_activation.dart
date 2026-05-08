enum LinkStatus { success, invalid, expired, networkError }

class LinkActivation {
  final LinkStatus status;
  final String? childId;
  final String? parentId;
  final DateTime? expiresAt;
  final String? errorMessage;

  const LinkActivation({
    required this.status,
    this.childId,
    this.parentId,
    this.expiresAt,
    this.errorMessage,
  });
}
