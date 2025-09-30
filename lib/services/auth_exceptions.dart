class DeviceBannedException implements Exception {
  final String message = 'This device has been banned from accessing the service.';
  @override
  String toString() => message;
}

class DeviceInUseException implements Exception {
  final String message = 'This device is already registered to another user account.';
  @override
  String toString() => message;
}
