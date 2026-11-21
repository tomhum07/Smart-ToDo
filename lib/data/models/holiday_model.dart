/// Model Ngày nghỉ lễ Việt Nam tải từ Nager.Date Public API.
class HolidayModel {
  final DateTime date;
  final String localName;
  final String name;
  final String countryCode;

  const HolidayModel({
    required this.date,
    required this.localName,
    required this.name,
    required this.countryCode,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    return HolidayModel(
      date: DateTime.parse(json['date'] as String),
      localName: (json['localName'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      countryCode: (json['countryCode'] as String?) ?? 'VN',
    );
  }
}
