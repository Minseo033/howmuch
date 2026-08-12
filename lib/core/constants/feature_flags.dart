class FeatureFlags {
  FeatureFlags._();

  static const bool reportImageUploadEnabled = bool.fromEnvironment(
    'REPORT_IMAGE_UPLOAD_ENABLED',
    defaultValue: true,
  );
}
