class AppointmentModel {
  final String id;
  final String userId;
  final String serviceId;
  final DateTime date;

  AppointmentModel({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.date,
  });
}
