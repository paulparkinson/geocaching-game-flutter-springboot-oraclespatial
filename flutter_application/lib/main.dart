import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:provider/provider.dart';

import 'geocachejson.dart' as geocachejson;
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'GeoCaching App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeoCacheTopScoresWidget();
        break;
      case 1:
        page = GeoCacheFormWidget();
        break;
      case 2:
        page = MapWidget();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    var mainArea = ColoredBox(
      color: colorScheme.surfaceVariant,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            // Use a more mobile-friendly layout with BottomNavigationBar on narrow screens.
            return Column(
              children: [
                Expanded(child: mainArea),
                SafeArea(
                  child: BottomNavigationBar(
                    items: [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.favorite),
                        label: 'Top Caches',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Add GeoCache',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.favorite),
                        label: 'Map (Spatial)',
                      ),
                    ],
                    currentIndex: selectedIndex,
                    onTap: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                )
              ],
            );
          } else {
            return Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 600,
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.favorite),
                        label: Text('Top Caches'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.javascript_outlined),
                        label: Text('Add GeoCache'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.map_outlined),
                        label: Text('Map (Spatial)'),
                      ),
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                ),
                Expanded(child: mainArea),
              ],
            );
          }
        },
      ),
    );
  }
}


class GeoCacheTopScoresWidget extends StatefulWidget {
  const GeoCacheTopScoresWidget({super.key});

  @override
  State<GeoCacheTopScoresWidget> createState() => _GeoCacheTopScoresWidgetState();
}

class _GeoCacheTopScoresWidgetState extends State<GeoCacheTopScoresWidget> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Top Ten Geocaches',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Top Ten Geocaches'),
        ),
        body: Center(
          child: FutureBuilder<geocachejson.FeatureCollection>(
            future: geocachejson.fetchFeatureCollectionTopTenFromJournals(),
            builder: (context, featurecollection) {
              if (featurecollection.hasData) {
                return ListView.builder(
                  itemCount: featurecollection.data!.features.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                            featurecollection.data!.features[index].properties.image),
                      ),
                      title: Text(
                          '${featurecollection.data!.features[index].properties.name}  '),
                      subtitle: Text(
                          '  ${featurecollection.data!.features[index].geometry.coordinates[0]},${featurecollection.data!.features[index].geometry.coordinates[1]} '),
                    );
                  },
                );
              } else if (featurecollection.hasError) {
                return Text('${featurecollection.error}');
              }
              // By default, show a loading spinner.
              return const CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }
}

class GeoCacheFormWidget extends StatefulWidget {
  @override
  _GeoCacheFormWidgetState createState() => _GeoCacheFormWidgetState();
}

class _GeoCacheFormWidgetState extends State<GeoCacheFormWidget> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _image = '';
  double _latitude = 0;
  double _longitude = 0;

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      geocachejson.FeatureCollection featureCollection = geocachejson.FeatureCollection(
        type: 'FeatureCollection',
        features: [
          geocachejson.Feature(
            type: 'Feature',
            geometry: geocachejson.Geometry(
              type: 'Point',
              coordinates: [_longitude, _latitude],
            ),
            properties: geocachejson.Properties(
              name: _name,
              image: _image,
            ),
          ),
        ],
      );

      var url = Uri.parse('http://localhost:8080/geocache/addGeoCache');
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(featureCollection.toJson()),
      );

      if (response.statusCode == 200) {
        print('Successful POST request');
      } else {
        print('Failed POST request');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add A Geocache'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(labelText: 'Enter your name'),
                onSaved: (value) {
                  _name = value!;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Enter latitude'),
                keyboardType: TextInputType.number,
                onSaved: (value) {
                  _latitude = double.parse(value!);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a number';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Enter longitude'),
                keyboardType: TextInputType.number,
                onSaved: (value) {
                  _longitude = double.parse(value!);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a number';
                  }
                  return null;
                },
              ),
              TextFormField(
                initialValue:
                    'https://somefile.png',
                decoration:
                    InputDecoration(labelText: 'Enter geocache image URL'),
                onSaved: (value) {
                  _image = value!;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text(
                    'Click Here To Add And Then Check The Map For Your Geocache!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class MapWidget extends StatefulWidget {
  @override
  State<MapWidget> createState() => _MapState();
}

class _MapState extends State<MapWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          child: Column(
            children: [
              Flexible(
                  child: FlutterMap(
                options: MapOptions(
                  center: LatLng( 29.9575, -90.0618),
                  zoom: 9.2,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  FutureBuilder<geocachejson.FeatureCollection>(
                    future: geocachejson.fetchFeatureCollection(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                            child:
                                CircularProgressIndicator()); // Show a loading spinner while waiting
                      } else if (snapshot.hasError) {
                        return Text(
                            'Error: ${snapshot.error}'); // Show an error message if something went wrong
                      } else {
                        // Create the MarkerLayer only when the data is available
                        geocachejson.FeatureCollection featureCollection = snapshot.data!;
                        return MarkerLayer(
                          markers: featureCollection.features.map((feature) {
                            return Marker(
                              point: LatLng(feature.geometry.coordinates[1],
                                  feature.geometry.coordinates[0]),
                              width: 30,
                              height: 30,
                              builder: (ctx) => Container(
                                child: IconButton(
                                  icon: Icon(Icons.location_on),
                                  color: Colors.blue,
                                  onPressed: () async {
                                    var url = Uri.http('localhost:8080',
                                        '/geocache/addGeoCacheJournalEntry', {
                                      'creatorname': feature.properties.name,
                                      //currently just using "somevisitor" but logged in username could be used for track/follow backs, etc.
                                      'visitorname': 'somevisitor',
                                      'imageurl': feature.properties.image,
                                      'longitude': feature
                                          .geometry.coordinates[1]
                                          .toString(),
                                      'latitude': feature
                                          .geometry.coordinates[0]
                                          .toString(),
                                    });
                                    var response = await http.post(url);
                                    String message;
                                    if (response.statusCode == 200) {
                                      message = 'HTTP request was successful!';
                                    } else {
                                      message =
                                          'HTTP request failed with status: ${response.statusCode}';
                                    }
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: Text(
                                              'Great! You\'ve signed a geocache placed by ' +
                                                  feature.properties
                                                      .name), // this is the added message
                                          content: Image.network(
                                              feature.properties.image),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }
                    },
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}
