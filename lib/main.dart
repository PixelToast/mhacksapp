import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';

import 'dart:math';
import 'package:vector_math/vector_math.dart' as vec;

void main() {
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'k1',
      home: new MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class RemoteDevice {
  RemoteDevice(this.id, this.name, this.sus, this.angle);
  String id;
  String name;
  double sus;
  double angle;
  double avel = 0.0;
  double top = -100.0;
  double left = -100.0;
  bool first = true;
  bool disabled = false;
}

vec.Vector2 rotateVec(vec.Vector2 v, double angle) {
  var ca = cos(angle);
  var sa = sin(angle);
  return new vec.Vector2(ca * v.x - sa * v.y, sa * v.x + ca * v.y);
}

class Packet {
  double x;
  double y;
  RemoteDevice from;
  RemoteDevice to;
  double sus = 0.5;
  double size = 20.0;
  double esize = 20.0;
  double progress = 0.0;
  void update() {
    var of = new FractionalOffsetTween(begin: new FractionalOffset(from.top, from.left), end: new FractionalOffset(to.top, to.left)).lerp(progress);
    var ang = atan2(from.top - to.top, from.left - to.left);
    esize = size * sin(progress * PI);
    var v = new vec.Vector2(sin(progress * 20) * ((20 - esize) / 1.2), 0.0);
    var nv = rotateVec(v, -ang);
    x = of.dx + (25 - (size / 2)) + nv.x;
    y = of.dy + (25 - (size / 2)) + nv.y;
  }
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  WebSocket connection;
  
  RemoteDevice me;
  String myMAC = "";
  
  int hcisize = 0;
  
  @override
  void dispose() {
    super.dispose();
    connection.close();
  }
  
  bool infected = false;
  List<String> infecting;
  
  Future connect() async {
    devices = [];
    packets = [];
    myPackets = [];
    setState(() {});
    connection = null;
    while (connection == null) {
      print("connecting...");
      connection = await WebSocket.connect('ws://succ.pxtst.com:80/ws').catchError((reason) => print(reason));
    }
    print("connected");
    connection.listen((raw) {
      print("got packet $raw");
      var data = JSON.decode(raw);
      switch (data["type"]) {
        case "init":
          devices = (data["devices"] as List<Map>).map((m) {
            var o = new RemoteDevice(m["id"], m["name"], m["sus"] + 0.0, 0.0);
            o.disabled = m["disabled"];
            return o;
          }).toList();
          myMAC = data["id"];
          print("MyMAC ${myMAC}");
        break;
        case "create":
          var dev = new RemoteDevice(data["id"], data["name"], data["sus"], 0.0);
          if (data["id"] == myMAC) {
            me = dev;
            me.left = 150.0;
            me.top = 150.0;
          } else {
            devices.add(dev);
          }
        break;
        case "kill":
          devices.removeWhere((rd) => rd.id == data["id"]);
        break;
        case "packet":
          var r = new Packet();
          r.sus = data["sus"] + 0.0;
          r.from = data["from"] == myMAC ? me : devices.firstWhere((dv) => dv.id == data["from"]);
          r.to = data["to"] == myMAC ? me : devices.firstWhere((dv) => dv.id == data["to"]);
          r.size = data["size"] + 0.0;
          if (data["from"] == myMAC || data["to"] == myMAC) {
            myPackets.add(r);
          } else {
            packets.add(r);
          }
        break;
        case "sus":
          (data["id"] == myMAC ? me : devices.firstWhere((rd) => rd.id == data["id"])).sus = data["sus"] + 0.0;
        break;
        case "infect":
          if (data["id"] == myMAC) {
            infected = true;
            infecting = data["infecting"];
          }
          if (infecting != null) infecting.removeWhere((id) => id == data["id"]);
        break;
        case "disable":
          if (data["id"] == myMAC) {
            me.disabled = true;
            platform.invokeMethod("turnoff");
          } else devices.firstWhere((dv) => dv.id == data["id"]).disabled = true;
        break;
        case "revert":
          [devices, [me]].expand((e) => e).forEach((dv) {
            dv.sus = 0.0;
            dv.disabled = false;
          });
          infecting = null;
          infected = false;
          platform.invokeMethod("turnon");
        break;
      }
      setState(() {});
    });
    connection.done.then((reason) {
      print("Disconnected! ${reason}");
      connect();
    });
  }

  static const platform = const MethodChannel('realism.io/bt');
  
  int totalBytes = 0;
  
  @override
  void initState() {
    super.initState();
    platform.invokeMethod("turnon");
    (() async {
      var f = new File("/sdcard/btsnoop_hci.log");
      while (mounted) {
        await new Future.delayed(const Duration(milliseconds: 1000));
        print("checking ${await f.exists() ? await f.length() : "doesn't exist"}");
        if (await f.exists() && await f.length() != totalBytes) {
          print("reqing");
          var data = await f.openRead().expand((e) => e).toList();
          var req = post("http://succ.pxtst.com/hci", body: data);
          /*var request = new MultipartRequest("POST", Uri.parse("http://succ.pxtst.com/hci"));
          totalBytes = data.length;
          setState(() {});
          request.files.add(new MultipartFile.fromBytes("file", data));*/
          var resp = await req;
          totalBytes = data.length;
          print("Status ${resp.statusCode}");
          print("Return ${resp.body}");
        }
      }
    })();
    var lastDur = new Duration();
    connect();
    createTicker((dur) {
      /*if (new Random().nextInt(10) == 0 && false) {
        var p = new Packet();
        p.from = devices[new Random().nextInt(devices.length)];
        p.to = devices[new Random().nextInt(devices.length)];
        p.size = new Random().nextDouble() * 15 + 5;
        packets.add(p);
      }*/
      
      setState(() {
        [packets, myPackets].expand((e) => e).toList().forEach((p) {
          p.progress = (p.progress + ((dur.inMilliseconds - lastDur.inMilliseconds) / 1000.0)).clamp(0.0, 1.0);
          if (p.progress == 1.0) {
            packets.remove(p);
            myPackets.remove(p);
          } else p.update();
        });
        
        var tgtOffset = (devices.length * PI) / 5.0;
        
        devices.forEach((dv) {
          dv.angle = dv.angle % (2 * PI);
          //var force = 0.0;
          var target = (((2 * PI) / devices.length) * devices.indexOf(dv)) + tgtOffset;
          if (dv.first) {
            dv.first = false;
            dv.angle = target;
          } else {
            var difl = (target - dv.angle) % (2 * PI);
            var difr = (-difl) % (2 * PI);
            var f = ((difl > difr) ? -difr : difl) / devices.length;
  
            var force = f * 5;
  
            dv.avel += (((force) / 1000) - ((dv.avel / 10) * (dur.inMilliseconds - lastDur.inMilliseconds) * 0.08));
            dv.angle += dv.avel * (dur.inMilliseconds - lastDur.inMilliseconds);
            dv.top = sin(dv.angle) * 150 + 150;
            dv.left = cos(dv.angle) * 150 + 150;
          }
        });
        //devices.forEach((rd) => rd.angle += ((dur.inMilliseconds - lastDur.inMilliseconds) / 1000));
      });
      lastDur = dur;
    }).start();
  }
  
  List<RemoteDevice> devices = [];
  
  List<Packet> packets = [];
  
  List<Packet> myPackets = [];
  
  @override
  Widget build(BuildContext context) {
    
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Security Demo"),
        actions: [
          new IconButton(icon: const Icon(Icons.bug_report), onPressed: () {
            connection.add(JSON.encode({
              "type": "attack",
            }));
          }),
          new IconButton(icon: const Icon(Icons.https), onPressed: () {
            connection.add(JSON.encode({
              "type": "secure1",
            }));
          }),
          new IconButton(icon: const Icon(Icons.phonelink_lock), onPressed: () {
            connection.add(JSON.encode({
              "type": "secure2",
            }));
          }),
          new IconButton(icon: const Icon(Icons.restore), onPressed: () {
            connection.add(JSON.encode({
              "type": "revert",
            }));
          }),
        ],
      ),
      body: new Container(child: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            infected ?
              new Column(children: [
                new Image.network("https://i.imgur.com/StU47Gd.png", width: 200.0),
                new Text(me.disabled ? "" : infecting.map((id) => "Infecting $id...").join("\n"), style: const TextStyle(color: Colors.white, fontSize: 35.0)),
              ]):
            new Stack(children: [new Padding(child: new ClipOval(child: new Container(child:
              new Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                new Text(
                  "${(me?.name).toString()}\n[${myMAC.toString()}]",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30.0,
                  )
                ),
              ]),
              color: ((me?.disabled ?? false) && me.sus != 1.0) ? Colors.grey : new ColorTween(begin: Colors.green, end: Colors.red).lerp(me?.sus ?? 0.0), width: 200.0, height: 200.0)), padding: const EdgeInsets.all(75.0))]..addAll(packets.map((p) {
                return new Positioned(child: new ClipOval(child: new Container(color: new ColorTween(begin: Colors.black, end: Colors.red).lerp(p.sus), width: p.esize, height: p.esize)), top: p.x, left: p.y);
              }))..addAll(myPackets.map((p) {
                return new Positioned(child: new ClipOval(child: new Container(color: new ColorTween(begin: Colors.black, end: Colors.red).lerp(p.sus), width: p.esize, height: p.esize)), top: p.x, left: p.y);
              }))..addAll(devices.map((r) { return new Positioned(
                child: new GestureDetector(child: new ClipOval(child: new Container(
                  child: new Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    new Text("[${r.id}]", style: const TextStyle(color: Colors.white, fontSize: 13.0)),
                  ]),
                  width: 50.0,
                  height: 50.0,
                  color: (r.sus != 1.0 && r.disabled) ? Colors.grey : Color.lerp(Colors.green, Colors.red, r.sus),
                )), onTap: () {
                  connection.add(JSON.encode({
                    "type": "pair",
                    "id": r.id,
                  }));
                }),
                top: r.top,
                left: r.left,
              ); })),
            )
          ]
        ),
      ), color: infected ? Colors.redAccent : Colors.blueGrey),
    );
  }
}
