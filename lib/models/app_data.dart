import 'package:firebase_database/firebase_database.dart';

class AppData {
  final String id;
  final String title;
  final String downloadLink;
  final String releaseDate;
  final String size;
  final String thumbnail;
  final String whatsNew;

  AppData({
    required this.id,
    required this.title,
    required this.downloadLink,
    required this.releaseDate,
    required this.size,
    required this.thumbnail,
    required this.whatsNew,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'downloadLink': downloadLink,
      'releaseDate': releaseDate,
      'size': size,
      'thumbnail': thumbnail,
      'whatsNew': whatsNew,
    };
  }

  factory AppData.fromMap(Map<String, dynamic> map, String documentId) {
    return AppData(
      id: documentId,
      title: map['title'] ?? '',
      downloadLink: map['downloadLink'] ?? '',
      releaseDate: map['releaseDate'] ?? '',
      size: map['size'] ?? '',
      thumbnail: map['thumbnail'] ?? '',
      whatsNew: map['whatsNew'] ?? '',
    );
  }

  AppData copyWith({
    String? title,
    String? downloadLink,
    String? releaseDate,
    String? size,
    String? thumbnail,
    String? whatsNew,
  }) {
    return AppData(
      id: this.id,
      title: title ?? this.title,
      downloadLink: downloadLink ?? this.downloadLink,
      releaseDate: releaseDate ?? this.releaseDate,
      size: size ?? this.size,
      thumbnail: thumbnail ?? this.thumbnail,
      whatsNew: whatsNew ?? this.whatsNew,
    );
  }
}
