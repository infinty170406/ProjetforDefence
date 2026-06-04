import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<bool> requestService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      // We don't await the result immediately as openLocationSettings is async but doesn't wait for user action
      return false;
    }
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }
}
