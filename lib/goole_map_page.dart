import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GGGG extends StatefulWidget {
  const GGGG({super.key});

  @override
  State<GGGG> createState() => _GGGGState();
}

class _GGGGState extends State<GGGG> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(11.003237, 76.975816),
    zoom: 11.5,
  );

  late GoogleMapController _googleMapController;
  Marker? _origin;
  Marker? _destination;
  Timer? _timer;
  bool _isSet = false; // State variable to track if SET button is pressed
  bool _hasNotified = false; // State variable to track if the notification has been sent
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void dispose() {
    _googleMapController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startLocationUpdates();
  }

  Future<void> _requestPermissions() async {
    await Permission.locationWhenInUse.request();
  }

  void _startLocationUpdates() {
    _timer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isSet) {
        _getCurrentLocation();
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServicesDialog();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _googleMapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14.5,
          ),
        ),
      );

      setState(() {
        _origin = Marker(
          markerId: MarkerId('current_location'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(title: 'Current Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      });

      if (_destination != null) {
        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          _destination!.position.latitude,
          _destination!.position.longitude,
        );

        if (distance <= 2000 && _isSet && !_hasNotified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You are within 2000 meters of your destination. Sending push notification.'),
              duration: Duration(seconds: 5),
            ),
          );
          _sendPushNotification();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e')),
      );
    }
  }

  Future<void> _sendPushNotification() async {
    const String serverToken = 'AAAAt7TeHk8:APA91bHPPj9-CTRWVvvg1J1839POU-FHfo6A9gPyiociM38GIqC65dBuZmdvqBlr4yf_JMbeqi7pD1LnBiF2bERvDUa5hlHjxwAB1SJQxRKp_OWaYEND8X6pOzBUqpWPsFaSNFkVvR59'; // Replace with your FCM server key
    final String fcmToken = 'el1K50Q3TjiyldQmaHF7Bl:APA91bEDaJFQPuPQglBa0lUJ3-qvxhjmWQ8sA6Fw1jtWfwbeDOD_HcBFOe8mChEaUUTNviExYBJBBVkQ4UZFpVd9L9pfPdM_jo5ibz8Np1jIt5zKl1t3v7i2FZTn_yPywnpxrHtgRO1W';

    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverToken',
      },
      body: constructFCMPayload(fcmToken),
    );

    setState(() {
      _hasNotified = true;
    });
  }

  String constructFCMPayload(String token) {
    return '''
    {
      "to": "$token",
      "notification": {
        "title": "Proximity Alert",
        "body": "You are within 2000 meters of your destination."
      }
    }
    ''';
  }

  void _showLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Services Disabled'),
          content: Text('Location services are disabled. Please enable the services.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _gotoGoogleMap() async {
    if (_origin != null && _destination != null) {
      final String googleMapsUrl = "https://www.google.com/maps/dir/?api=1&origin=${_origin!.position.latitude},${_origin!.position.longitude}&destination=${_destination!.position.latitude},${_destination!.position.longitude}&travelmode=driving";
      if (await canLaunch(googleMapsUrl)) {
        await launch(googleMapsUrl);
      } else {
        throw 'Could not launch $googleMapsUrl';
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Origin or destination is not set')),
      );
    }
  }

  Future<void> _updateDestination(LatLng newDestination) async {
    if (!_isSet) return;

    setState(() {
      _destination = Marker(
        markerId: const MarkerId('destination'),
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        position: newDestination,
      );
    });

    double distance = Geolocator.distanceBetween(
      _origin!.position.latitude,
      _origin!.position.longitude,
      newDestination.latitude,
      newDestination.longitude,
    );

    if (distance <= 2000 && _isSet && !_hasNotified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are within 2000 meters of your destination. Sending push notification.'),
          duration: Duration(seconds: 5),
        ),
      );
      _sendPushNotification();
    }
  }

  void _showUpdateDestinationDialog() {
    final TextEditingController latitudeController = TextEditingController();
    final TextEditingController longitudeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update Destination'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latitudeController,
                decoration: InputDecoration(
                  labelText: 'Latitude',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: longitudeController,
                decoration: InputDecoration(
                  labelText: 'Longitude',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final double? latitude = double.tryParse(latitudeController.text);
                final double? longitude = double.tryParse(longitudeController.text);

                if (latitude != null && longitude != null) {
                  _updateDestination(LatLng(latitude, longitude));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid coordinates')),
                  );
                }

                Navigator.of(context).pop();
              },
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Google Map"),
        actions: [
          if (_origin != null)
            TextButton(
              onPressed: () => _googleMapController.animateCamera(
                CameraUpdate.newCameraPosition(CameraPosition(
                  target: _origin!.position,
                  zoom: 14.5,
                  tilt: 50.0,
                )),
              ),
              child: Text("ORIGIN"),
            ),
          if (_destination != null)
            TextButton(
              onPressed: () => _googleMapController.animateCamera(
                CameraUpdate.newCameraPosition(CameraPosition(
                  target: _destination!.position,
                  zoom: 14.5,
                  tilt: 50.0,
                )),
              ),
              child: Text("DEST"),
            ),

          TextButton(
            onPressed: () {
              setState(() {
                _isSet = true;
                _hasNotified = false;
              });
            },
            child: Text("SET"),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            myLocationButtonEnabled: false,
            zoomGesturesEnabled: true,
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) => _googleMapController = controller,
            markers: {
              if (_origin != null) _origin!,
              if (_destination != null) _destination!,
            },
            onLongPress: _addMarker,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _getCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _gotoGoogleMap,
            child: const Icon(Icons.directions),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _showUpdateDestinationDialog,
            child: const Icon(Icons.edit_location),
          ),
        ],
      ),
    );
  }

  void _addMarker(LatLng pos) async {
    if (_origin == null || (_origin != null && _destination != null)) {
      setState(() {
        _origin = Marker(
          markerId: const MarkerId('origin'),
          infoWindow: const InfoWindow(title: 'Origin'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          position: pos,
        );
        _destination = null;
      });
    } else {
      setState(() {
        _destination = Marker(
          markerId: const MarkerId('destination'),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          position: pos,
        );
      });

      if (_origin != null) {
        double distance = Geolocator.distanceBetween(
          _origin!.position.latitude,
          _origin!.position.longitude,
          pos.latitude,
          pos.longitude,
        );

        if (distance <= 2000 && _isSet && !_hasNotified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You are within 2000 meters of your destination. Sending push notification.'),
              duration: Duration(seconds: 5),
            ),
          );
          _sendPushNotification();
        }
      }
    }
  }
}
