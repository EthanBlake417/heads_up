class GameConstants {
  static const double correctTriggerThreshold = -9.0;
  static const double correctResetThreshold = -5.0;
  static const double passTriggerThreshold = 9.0;
  static const double passResetThreshold = 5.0;
  static const double neutralThreshold = 4.0;

  static const Duration positionConfirmTime = Duration(milliseconds: 150);
  static const Duration wordChangeDelay = Duration(milliseconds: 250);
  static const int defaultGameDuration = 60;
}
