enum LoadingBehavior {
  /// Show empty SizedBox while loading, fallback to control after timeout.
  /// This prevents flickering but may show empty space briefly.
  placeholder,

  /// Show control variant (0) immediately while loading.
  /// Content appears faster but may flicker if user is assigned to a different variant.
  control,
}
