import 'dart:html' as html;

void enterFullscreenImpl() {
  html.document.documentElement?.requestFullscreen();
}

void exitFullscreenImpl() {
  html.document.exitFullscreen();
}
