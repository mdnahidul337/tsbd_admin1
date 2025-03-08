class AppSettings {
  final bool maintenanceMode;
  final String currentVersion;
  final bool updateRequired;
  final String updateMessage;
  final String updateLink;
  final bool forceUpdate;

  AppSettings({
    this.maintenanceMode = false,
    required this.currentVersion,
    this.updateRequired = false,
    this.updateMessage = '',
    this.updateLink = '',
    this.forceUpdate = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'maintenanceMode': maintenanceMode,
      'currentVersion': currentVersion,
      'updateRequired': updateRequired,
      'updateMessage': updateMessage,
      'updateLink': updateLink,
      'forceUpdate': forceUpdate,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      maintenanceMode: map['maintenanceMode'] ?? false,
      currentVersion: map['currentVersion'] ?? '1.0.0',
      updateRequired: map['updateRequired'] ?? false,
      updateMessage: map['updateMessage'] ?? '',
      updateLink: map['updateLink'] ?? '',
      forceUpdate: map['forceUpdate'] ?? false,
    );
  }

  AppSettings copyWith({
    bool? maintenanceMode,
    String? currentVersion,
    bool? updateRequired,
    String? updateMessage,
    String? updateLink,
    bool? forceUpdate,
  }) {
    return AppSettings(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      currentVersion: currentVersion ?? this.currentVersion,
      updateRequired: updateRequired ?? this.updateRequired,
      updateMessage: updateMessage ?? this.updateMessage,
      updateLink: updateLink ?? this.updateLink,
      forceUpdate: forceUpdate ?? this.forceUpdate,
    );
  }
}
