class MedicalInfo {
  final String bloodGroup;
  final String allergies;
  final String conditions;

  MedicalInfo({
    required this.bloodGroup,
    required this.allergies,
    required this.conditions,
  });

  bool get isEmpty =>
      bloodGroup.isEmpty && allergies.isEmpty && conditions.isEmpty;

  Map<String, dynamic> toJson() => {
        "bloodGroup": bloodGroup,
        "allergies": allergies,
        "conditions": conditions,
      };

  factory MedicalInfo.fromJson(Map<String, dynamic> json) => MedicalInfo(
        bloodGroup: json['bloodGroup'] ?? '',
        allergies: json['allergies'] ?? '',
        conditions: json['conditions'] ?? '',
      );

  @override
  String toString() {
    return '''🩺 Medical Information:
Blood Group: ${bloodGroup.isNotEmpty ? bloodGroup : 'Not set'}
Allergies: ${allergies.isNotEmpty ? allergies : 'None'}
Medical Conditions: ${conditions.isNotEmpty ? conditions : 'None'}''';
  }
}
