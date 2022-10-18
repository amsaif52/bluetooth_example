import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static BluetoothConnection? connection;
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  Timer? _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;
  int _counter = 0;
  int _count = 0;
  bool _bConnectionSuccess = false;
  var random = Random();
  TextEditingController macAdressController = TextEditingController();
  String macAddress = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    // Listen for futher state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        _discoverableTimeoutTimer = null;
        _discoverableTimeoutSecondsLeft = 0;
      });
    });

    Timer.periodic(const Duration(seconds: 20), (timer) {
      if (macAddress.isNotEmpty && _bConnectionSuccess) {
        sendMessageByBluetooth("$_count");
        _count = random.nextInt(2);
      }
    });
  }

  void dispose() {
    _discoverableTimeoutTimer?.cancel();
    setState(() {
      _bConnectionSuccess = false;
    });
    super.dispose();
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  void sendMessageByBluetooth(String data) async {
    connection!.output.add(ascii.encode(data));
    final snackBar = SnackBar(
      content: Text('$data'),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    await connection!.output.allSent;
  }

  void connect(result) async {
    print('result: ' + result);
    var conn = await BluetoothConnection.toAddress(result.toUpperCase());
    connection = conn;
    connection!.output.add(ascii.encode("0"));
    await connection!.output.allSent;
    setState(() {
      _bConnectionSuccess = true;
    });
    connection!.input!.listen((data) {
      print('x:');
      String s = String.fromCharCodes(data);
      // print('x:' + s);
      // Allocate buffer for parsed data
      int backspacesCounter = 0;
      data.forEach((byte) {
        if (byte == 8 || byte == 127) {
          backspacesCounter++;
        }
      });
      Uint8List buffer = Uint8List(data.length - backspacesCounter);
      int bufferIndex = buffer.length;

      // Apply backspace control character
      backspacesCounter = 0;
      for (int i = data.length - 1; i >= 0; i--) {
        if (data[i] == 8 || data[i] == 127) {
          backspacesCounter++;
        } else {
          if (backspacesCounter > 0) {
            backspacesCounter--;
          } else {
            buffer[--bufferIndex] = data[i];
          }
        }
      }

      // Create message if there is new line character
      String dataString = String.fromCharCodes(buffer);
      int index = buffer.indexOf(13);
      final snackBar = SnackBar(
        content: Text('x:$dataString'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: const Text('Bluetooth Serial'),
        ),
        body: Container(
            margin: const EdgeInsets.all(20),
            child: ListView(
              children: [
                const Divider(),
                SwitchListTile(
                    title: const Text('Enable Bluetooth'),
                    value: _bluetoothState.isEnabled,
                    onChanged: (bool value) {
                      future() async {
                        if (value) {
                          await FlutterBluetoothSerial.instance.requestEnable();
                        } else {
                          await FlutterBluetoothSerial.instance
                              .requestDisable();
                        }
                      }

                      future().then((_) {
                        setState(() {});
                      });
                    }),
                TextField(
                  controller: macAdressController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Mac Address: B8:27:EB:2C:E4:7D'),
                  onChanged: (text) {
                    setState(() {
                      macAddress = text;
                    });
                  },
                ),
                ElevatedButton(
                    onPressed: () {
                      connect(macAddress);
                    },
                    child: const Text('Submit'))
              ],
            )));
  }
}
