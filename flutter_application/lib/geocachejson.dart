import 'package:http/http.dart' as http;
import 'dart:convert';

class FeatureCollection {
  String type;
  List<Feature> features;

  FeatureCollection({
    required this.type,
    required this.features,
  });

  factory FeatureCollection.fromJson(Map<String, dynamic> jsonData) {
    return FeatureCollection(
      type: jsonData['type'],
      features: (jsonData['features'] as List).map((item) => Feature.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'features': features.map((feature) => feature.toJson()).toList(),
      };
}

class Feature {
  String type;
  Geometry geometry;
  Properties properties;

  Feature({
    required this.type,
    required this.geometry,
    required this.properties,
  });

  factory Feature.fromJson(Map<String, dynamic> jsonData) {
    return Feature(
      type: jsonData['type'],
      geometry: Geometry.fromJson(jsonData['geometry']),
      properties: Properties.fromJson(jsonData['properties']),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'geometry': geometry.toJson(),
        'properties': properties.toJson(),
      };
}

class Geometry {
  String type;
  List<double> coordinates;

  Geometry({
    required this.type,
    required this.coordinates,
  });
    
  factory Geometry.fromJson(Map<String, dynamic> jsonData) {
    return Geometry(
      type: jsonData['type'],
      coordinates: (jsonData['coordinates'] as List).map((item) => item as double).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'coordinates': coordinates,
      };
}

/**
 * Two constructors and two "fromJson" methods two purposes: 
 *  geoCache for map, where 'visitorname' is not applicable
 *  and 
 *  geoCache for journal, where 'visitorname' is applicable
 */
class Properties {
  String name;
  String image;
  String visitorname = ''; 

  Properties({
    required this.name,
    required this.image,
  });

  Properties.forqueries({
    required this.name,
    required this.image,
    required this.visitorname,
  });

  factory Properties.fromJson(Map<String, dynamic> jsonData) {
    return Properties(
      name: jsonData['name'],
      image: jsonData['image'],
    );
  }

  factory Properties.fromJsonFromJournalQuery(Map<String, dynamic> jsonData) {
    return Properties.forqueries(
      name: jsonData['name'],
      image: jsonData['image'],
      visitorname: jsonData['visitorname'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'image': image,
        'visitorname': visitorname,
      };
}







Future<FeatureCollection> fetchFeatureCollection() async {
  final response =
      await http.get(Uri.parse('http://localhost:8080/geocache/getGeoCaches'));

  if (response.statusCode == 200) {
    Map<String, dynamic> jsonData = json.decode(response.body);
    FeatureCollection featureCollection = FeatureCollection.fromJson(jsonData);

    for (var feature in featureCollection.features) {
      print('Name: ${feature.properties.name}');
      print('Longitude: ${feature.geometry.coordinates[0]}');
      print('Latitude: ${feature.geometry.coordinates[1]}');
    }
    return featureCollection;
  } else {
    throw Exception('Failed to load album');
  }
}


Future<FeatureCollection> fetchFeatureCollectionTopTenFromJournals() async {
  final response =
      await http.get(Uri.parse('http://localhost:8080/geocache/getGeoCacheTop10'));

  if (response.statusCode == 200) {
    Map<String, dynamic> jsonData = json.decode(response.body);
    FeatureCollection featureCollection = FeatureCollection.fromJson(jsonData);

    for (var feature in featureCollection.features) {
      print('Name: ${feature.properties.name}');
      print('Longitude: ${feature.geometry.coordinates[0]}');
      print('Latitude: ${feature.geometry.coordinates[1]}');
    }
    return featureCollection;
  } else {
    throw Exception('Failed to load album');
  }
}

