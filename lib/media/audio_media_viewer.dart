import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound_lite/flutter_sound.dart';

class AudioMediaViewer extends StatefulWidget {
  final MimePart mimePart;
  final MediaType mediaType;
  final bool autoPlay;
  AudioMediaViewer(
      {Key key,
      @required this.mimePart,
      @required this.mediaType,
      this.autoPlay = true})
      : super(key: key);

  @override
  _AudioMediaViewerState createState() => _AudioMediaViewerState();
}

class _AudioMediaViewerState extends State<AudioMediaViewer> {
  String name;
  Uint8List audioData;
  FlutterSoundPlayer audioPlayer;
  Track track;

  @override
  void initState() {
    audioData = widget.mimePart.decodeContentBinary();
    name = widget.mimePart.decodeFileName() ?? '<unknown>';
    track = Track(dataBuffer: audioData, trackTitle: name);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(name),
          ),
          SoundPlayerUI.fromTrack(track),
        ],
      ),
    );
  }
}
