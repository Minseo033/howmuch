class FeatureFlags {
  FeatureFlags._();

  static const bool reportImageUploadEnabled = bool.fromEnvironment(
    'REPORT_IMAGE_UPLOAD_ENABLED',
    defaultValue: true,
  );

  // The review API currently has no image upload or imageUrls field. Keep the
  // picker hidden until a real review upload endpoint is wired end to end so
  // selected photos cannot be silently discarded on submit.
  static const bool reviewImageUploadEnabled = bool.fromEnvironment(
    'REVIEW_IMAGE_UPLOAD_ENABLED',
    defaultValue: false,
  );
}
