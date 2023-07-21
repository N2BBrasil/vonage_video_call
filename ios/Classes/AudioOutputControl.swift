//
//  AudioOutputControl.swift
//  vonage_video_call
//
//  Created by Caciano Kroth on 21/07/23.
//

import Foundation
import AVFoundation

public class AudioOutputControl {
  private var audioSession: AVAudioSession
  
  init() {
    audioSession = AVAudioSession.sharedInstance()
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil);
  }
  
  func registerAudioRouteChangeBlock(onChange: @escaping (AudioOutputDeviceCallback) -> Void) {
    NotificationCenter.default.addObserver( forName:AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(), queue: nil) { notification in
      guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
        return
      }
      
      print("registerAudioRouteChangeBlock \(reason)");
      
      let currentOutput = self.getCurrentOutput();
      onChange(currentOutput);
    
    }
  }
  
  func getCurrentOutput() -> AudioOutputDeviceCallback {
    let currentRoute = AVAudioSession.sharedInstance().currentRoute
    
    for output in currentRoute.outputs {
      return getInfoByPort(output);
    }
    
    return AudioOutputDeviceCallback(type: AudioOutputDevice.speaker, name: "Speaker");
  }
  
  func getAvailableInputs() -> [AudioOutputDeviceCallback] {
    var arr = [AudioOutputDeviceCallback]()
    
    if let inputs = AVAudioSession.sharedInstance().availableInputs {
      for input in inputs {
        arr.append(getInfoByPort(input));
      }
    }
      
    if(!arr.contains(where: { device in device.type == AudioOutputDevice.speaker } )) {
        arr.append(AudioOutputDeviceCallback(type: AudioOutputDevice.speaker, name: "Speaker"));
    }
    
    if(arr.contains(where: { device in device.type == AudioOutputDevice.bluetooth || device.type == AudioOutputDevice.headphone } )) {
      arr.removeAll(where: { device in device.type == AudioOutputDevice.receiver })
    }
    
    return arr;
  }
  
  func setOutputDevice(deviceName: String) {
    let device = getAvailableInputs().first(where: { $0.name == deviceName })
  
    if(device == nil) {
      return;
    }
    
    switch(device!.type) {
    case AudioOutputDevice.receiver:
      try?AVAudioSession.sharedInstance().setMode(.voiceChat)
      try?AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
      return changeByPortType([AVAudioSession.Port.builtInMic, AVAudioSession.Port.builtInReceiver]);
    case AudioOutputDevice.bluetooth:
      let arr = [AVAudioSession.Port.bluetoothLE,AVAudioSession.Port.bluetoothHFP,AVAudioSession.Port.bluetoothA2DP];
      return changeByPortType(arr);
    case AudioOutputDevice.headphone:
      return changeByPortType([AVAudioSession.Port.headsetMic]);
    case AudioOutputDevice.speaker:
      try?AVAudioSession.sharedInstance().setMode(.videoChat)
      try?AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker);
      return;
    }
  }
  
  func getInfoByPort(_ input:AVAudioSessionPortDescription) -> AudioOutputDeviceCallback {
    var type = AudioOutputDevice.speaker;
    let port = AVAudioSession.Port.self;
    
    switch input.portType {
    case port.builtInReceiver,port.builtInMic:
      type = AudioOutputDevice.receiver;
      break;
    case port.builtInSpeaker:
      type = AudioOutputDevice.speaker;
      break;
    case port.headsetMic,port.headphones:
      type = AudioOutputDevice.headphone;
      break;
    case port.bluetoothA2DP,port.bluetoothLE,port.bluetoothHFP:
      type = AudioOutputDevice.bluetooth;
      break;
    default:
      type = AudioOutputDevice.speaker;
      break;
    }
    
    return AudioOutputDeviceCallback(type: type, name: input.portName);
  }
  
  func changeByPortType(_ ports:[AVAudioSession.Port]){
    let currentRoute = AVAudioSession.sharedInstance().currentRoute
    
    for output in currentRoute.outputs {
      if(ports.firstIndex(of: output.portType) != nil){
        return;
      }
    }
    if let inputs = AVAudioSession.sharedInstance().availableInputs {
      for input in inputs {
        if(ports.firstIndex(of: input.portType) != nil){
          try?AVAudioSession.sharedInstance().setPreferredInput(input);
          return;
        }
      }
    }
    
    return;
  }
}

