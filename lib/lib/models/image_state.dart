import 'dart:io';
import 'package:flutter/foundation.dart';

class ImageState extends ChangeNotifier {
  File? _imageFile;
  String _imageStatus = 'Picture Empty';

  File? get imageFile => _imageFile;
  String get imageStatus => _imageStatus;

  void setImage(File? file) {
    _imageFile = file;
    _imageStatus = file != null ? 'Picture Loaded' : 'Picture Empty';
    notifyListeners();
  }
}