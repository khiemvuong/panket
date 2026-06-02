// ignore_for_file: undefined_function, undefined_identifier, avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js' as js;

// Actual web implementation using dart:js.
void setupWebAudioListener(void Function(double progress, bool playing) onProgress) {
  try {
    js.context['onAudioProgress'] = js.allowInterop((double progress, bool playing) {
      onProgress(progress, playing);
    });
  } catch (e) {
    // Ignore or log in development
  }
}

void playWebAudio(String url) {
  try {
    js.context.callMethod('eval', [
      "if (!window.myAudio) window.myAudio = new Audio(); "
      "if (!window.myAudioListenersSet) { "
      "  window.myAudio.addEventListener('timeupdate', () => { "
      "    let maxDuration = 30; "
      "    let curTime = window.myAudio.currentTime; "
      "    let duration = Math.min(window.myAudio.duration || maxDuration, maxDuration); "
      "    if (curTime >= maxDuration) { "
      "      window.myAudio.pause(); "
      "      window.myAudio.currentTime = 0; "
      "      if (window.onAudioProgress) window.onAudioProgress(0.0, false); "
      "    } else if (window.onAudioProgress) { "
      "      let progress = curTime / duration; "
      "      window.onAudioProgress(progress > 1.0 ? 1.0 : progress, !window.myAudio.paused); "
      "    } "
      "  }); "
      "  window.myAudio.addEventListener('ended', () => { "
      "    if (window.onAudioProgress) window.onAudioProgress(0.0, false); "
      "  }); "
      "  window.myAudioListenersSet = true; "
      "} "
      "window.myAudio.src = '$url'; "
      "window.myAudio.play().catch(e => console.log('Audio autoplay error:', e));"
    ]);
  } catch (e) {
    // Ignore
  }
}

void pauseWebAudio() {
  try {
    js.context.callMethod('eval', [
      "if (window.myAudio) window.myAudio.pause();"
    ]);
  } catch (e) {
    // Ignore
  }
}

void stopWebAudio() {
  try {
    js.context.callMethod('eval', [
      "if (window.myAudio) { window.myAudio.pause(); window.myAudio.currentTime = 0; }"
    ]);
  } catch (e) {
    // Ignore
  }
}
