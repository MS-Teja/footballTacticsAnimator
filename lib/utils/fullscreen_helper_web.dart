import 'package:web/web.dart' as web;

void enterFullscreenImpl() {
  web.document.documentElement?.requestFullscreen();
}

void exitFullscreenImpl() {
  web.document.exitFullscreen();
}
