import 'package:flutter/services.dart';

void enterFullscreenImpl() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
}

void exitFullscreenImpl() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}
