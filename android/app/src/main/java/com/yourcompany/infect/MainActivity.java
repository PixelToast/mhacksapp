package com.yourcompany.infect;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Intent;
import android.os.Bundle;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);

    new MethodChannel(getFlutterView(), "realism.io/bt").setMethodCallHandler(
      new MethodChannel.MethodCallHandler() {
        @Override
        public void onMethodCall(MethodCall call, MethodChannel.Result result) {
          switch (call.method) {
            case "list": {
              BluetoothAdapter mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
              Set<BluetoothDevice> pairedDevices = mBluetoothAdapter.getBondedDevices();
              List<String> s = new ArrayList<String>();
              List<String> mac = new ArrayList<String>();
              for (BluetoothDevice bt : pairedDevices) {
                s.add(bt.getName());
                mac.add(bt.getAddress());
              }
              result.success(new ArrayList<Object>(Arrays.asList(s, mac)));
              break;
            }
            case "turnon": {
              BluetoothAdapter mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
              if (!mBluetoothAdapter.isEnabled())
                mBluetoothAdapter.enable();
              break;
            }
            case "turnoff":
              BluetoothAdapter.getDefaultAdapter().disable();
              break;
          }
        }
      }
    );
  }
}
