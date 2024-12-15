import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

import 'examples/localandwebobjectsexample.dart'; // Importar permission_handler

class RouteController {
  static final RouteController _instance = RouteController._internal();

  factory RouteController() => _instance;

  RouteController._internal();

  final ValueNotifier<List<LatLng>> routeNotifier = ValueNotifier([]);
  final ValueNotifier<LatLng?> startNotifier = ValueNotifier(null);
  final ValueNotifier<LatLng?> endNotifier = ValueNotifier(null);

  void updateRoute(LatLng start, LatLng end) {
    startNotifier.value = start;
    endNotifier.value = end;
    routeNotifier.value = [start, end];
    print(start);
    print(end);
  }
}

class MapScreen extends StatefulWidget {
  final double latitudDestino;
  final double longitudDestino;

  const MapScreen(this.latitudDestino, this.longitudDestino, {super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController _mapController;
  LatLng? pointA;
  LatLng? pointB;
  LatLng? userLocation;
  List<LatLng> routePoints = [];
  late Future<Position> _currentLocation;
  late Timer _timer; // Para actualizar la posición cada 4 segundos

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Obtener la ubicación actual y asignarla a pointA
    _getCurrentLocation().then((currentLocation) {
      setState(() {
        pointA = LatLng(currentLocation.latitude, currentLocation.longitude);
        pointB = LatLng(widget.latitudDestino, widget.longitudDestino);

        // Obtener la ruta inicial si ambas coordenadas están disponibles
        if (pointA != null && pointB != null) {
          getRoute(pointA!, pointB!);
        }
      });
    });

    // Escuchar cambios del RouteController
    RouteController().routeNotifier.addListener(() {
      final route = RouteController().routeNotifier.value;
      if (route.isNotEmpty) {
        drawRoute(route.first, route.last);
      }
    });

    // Actualizar la posición del usuario cada 2 segundos
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      _updateUserLocation();
    });
  }

  // Método para obtener la ubicación actual
  Future<Position> _getCurrentLocation() async {
    // Solicitar permisos de ubicación y cámara
    await _requestPermissions();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled) {
      throw Exception("Los servicios de ubicación están desactivados.");
    }

    // Si los permisos están denegados, solicita permisos
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Permisos de ubicación denegados.");
      }
    }

    // Si los permisos son permanentemente denegados
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Permisos de ubicación permanentemente denegados.");
    }

    // Obtener la ubicación
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // Método para solicitar permisos de ubicación y cámara
  Future<void> _requestPermissions() async {
    // Solicitar permisos de ubicación y cámara
    PermissionStatus locationPermission = await Permission.location.request();
    PermissionStatus cameraPermission = await Permission.camera.request();

    if (!locationPermission.isGranted) {
      throw Exception("Permiso de ubicación no concedido.");
    }

    if (!cameraPermission.isGranted) {
      throw Exception("Permiso de cámara no concedido.");
    }
  }

  // Método para actualizar la ubicación del usuario
  Future<void> _updateUserLocation() async {
    try {
      Position currentLocation = await _getCurrentLocation();
      setState(() {
        userLocation =
            LatLng(currentLocation.latitude, currentLocation.longitude);
      });
    } catch (e) {
      print("Error al obtener la ubicación del usuario: $e");
    }
  }

  /// Dibuja la ruta entre dos coordenadas.
  Future<void> getRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
          'https://routing.openstreetmap.de/routed-foot/route/v1/foot/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=polyline');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<dynamic> coordinates =
              _decodePolyline(data['routes'][0]['geometry']);

          setState(() {
            routePoints =
                coordinates.map((coord) => LatLng(coord[0], coord[1])).toList();
          });
        }
      } else {
        print('Error en la respuesta de la API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener la ruta: $e');
    }
  }

  /// Decodifica la ruta en formato Polyline.
  List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add([lat / 1E5, lng / 1E5]);
    }

    return poly;
  }

  /// Función para dibujar una nueva ruta entre dos puntos.
  void drawRoute(LatLng start, LatLng end) {
    setState(() {
      pointA = start;
      pointB = end;
      routePoints.clear(); // Limpia la ruta anterior
    });
    getRoute(start, end); // Obtén la nueva ruta
  }

  @override
  void dispose() {
    // Cancelar el temporizador cuando el widget sea destruido
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Facultad Ingeniería Mochis'),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter:
              LatLng(25.814667, -108.980793), // Coordenadas iniciales
          minZoom: 8.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: Colors.blue,
                strokeWidth: 4.0,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              if (pointA != null)
                Marker(
                  point: pointA!,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.green,
                    size: 30,
                  ),
                ),
              if (pointB != null)
                Marker(
                  point: pointB!,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
              if (userLocation != null)
                Marker(
                  point: userLocation!,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.blue,
                    size: 30,
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LocalAndWebObjectsWidget()),
      );
      },
        backgroundColor: Colors.blue,
        child: const Icon(
          Icons.view_in_ar,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _launchARView,
              icon: const Icon(Icons.view_in_ar, color: Colors.blue),
              label: const Text("Realidad Aumentada"),
            ),
          ],
        ),
      ),
    );
  }

  /// Método para abrir la vista de realidad aumentada.
  void _launchARView() {
    builder: (context) => LocalAndWebObjectsWidget();
  }
}
