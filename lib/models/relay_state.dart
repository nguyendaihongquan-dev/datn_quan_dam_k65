class RelayStateModel {
  final bool isOn;
  final int updatedAt;
  final String updatedBy;

  const RelayStateModel({
    required this.isOn,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory RelayStateModel.fromMap(Map<dynamic, dynamic> map) {
    return RelayStateModel(
      isOn: map['state'] == true || map['state'] == 1,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      updatedBy: map['updatedBy'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() => {
        'state': isOn,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };

  static RelayStateModel initial({required bool isOn, required String source}) {
    return RelayStateModel(
      isOn: isOn,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      updatedBy: source,
    );
  }
}
