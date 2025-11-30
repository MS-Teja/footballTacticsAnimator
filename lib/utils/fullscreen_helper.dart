import 'fullscreen_helper_stub.dart'
    if (dart.library.html) 'fullscreen_helper_web.dart'
    if (dart.library.io) 'fullscreen_helper_io.dart';

void enterFullscreen() => enterFullscreenImpl();
void exitFullscreen() => exitFullscreenImpl();
