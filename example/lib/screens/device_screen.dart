import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../widgets/service_tile.dart';
import '../snackbar.dart';
import '../extra.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  bool _isDiscoveringServices = false;
  bool _isConnectingOrDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingOrDisconnectingSubscription;
  late StreamSubscription<int> _rssiSubscription;
  late StreamSubscription<int> _mtuSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.device.connectionState.listen((state) {
      _connectionState = state;
      setState(() {});
    });

    _rssiSubscription = rssiStream(maxItems: 1).listen((value) {
      _rssi = value;
      setState(() {});
    });

    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      setState(() {});
    });

    _isConnectingOrDisconnectingSubscription = widget.device.isConnectingOrDisconnecting.listen((value) {
      print("isConnectingOrDisconnecting $value");
      _isConnectingOrDisconnecting = value;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _rssiSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingOrDisconnectingSubscription.cancel();
    super.dispose();
  }

  List<int> _getRandomBytes() {
    final math = Random();
    return [math.nextInt(255), math.nextInt(255), math.nextInt(255), math.nextInt(255)];
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectPressed() async {
    try {
      await widget.device.connectDevice();
      Snackbar.show(ABC.c, "Connect: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
    }
  }

  Future onDisconnectPressed() async {
    try {
      await widget.device.disconnectDevice();
      Snackbar.show(ABC.c, "Disconnect: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Disconnect Error:", e), success: false);
    }
  }

  Future onDiscoverServicesPressed() async {
    setState(() {
      _isDiscoveringServices = true;
    });
    try {
      await widget.device.discoverServices();
      Snackbar.show(ABC.c, "Discover Services: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Discover Services Error:", e), success: false);
    }
    setState(() {
      _isDiscoveringServices = false;
    });
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223);
      Snackbar.show(ABC.c, "Request Mtu: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Change Mtu Error:", e), success: false);
    }
  }

  Future onReadPressed(BluetoothCharacteristic c) async {
    try {
      await c.read();
      Snackbar.show(ABC.c, "Read: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Read Error:", e), success: false);
    }
  }

  Future onWritePressed(BluetoothCharacteristic c) async {
    try {
      await c.write(_getRandomBytes(), withoutResponse: c.properties.writeWithoutResponse);
      Snackbar.show(ABC.c, "Write: Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Write Error:", e), success: false);
    }
  }

  Future onSubscribePressed(BluetoothCharacteristic c) async {
    try {
      String op = c.isNotifying == false ? "Subscribe" : "Unubscribe";
      await c.setNotifyValue(c.isNotifying == false);
      Snackbar.show(ABC.c, "$op : Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Subscribe Error:", e), success: false);
    }
  }

  Future onReadDescriptorPressed(BluetoothDescriptor d) async {
    try {
      await d.read();
      Snackbar.show(ABC.c, "Descriptor Read : Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Descriptor Read Error:", e), success: false);
    }
  }

  Future onWriteDescriptorPressed(BluetoothDescriptor d) async {
    try {
      await d.write(_getRandomBytes());
      Snackbar.show(ABC.c, "Descriptor Write : Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Descriptor Write Error:", e), success: false);
    }
  }

  List<Widget> _buildServiceTiles(BuildContext context, BluetoothDevice d) {
    if (d.servicesList == null) {
      return [];
    }
    return d.servicesList!
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics.map((c) => _buildCharacteristicTile(c)).toList(),
          ),
        )
        .toList();
  }

  CharacteristicTile _buildCharacteristicTile(BluetoothCharacteristic c) {
    return CharacteristicTile(
      characteristic: c,
      onReadPressed: () => onReadPressed(c),
      onWritePressed: () => onWritePressed(c),
      onNotificationPressed: () => onSubscribePressed(c),
      descriptorTiles: c.descriptors
          .map(
            (d) => DescriptorTile(
              descriptor: d,
              onReadPressed: () => onReadDescriptorPressed(d),
              onWritePressed: () => onWriteDescriptorPressed(d),
            ),
          )
          .toList(),
    );
  }

  Widget buildSpinner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  Widget buildConnectOrDisconnectButton(BuildContext context) {
    return TextButton(
        onPressed: isConnected ? onDisconnectPressed : onConnectPressed,
        child: Text(
          isConnected ? "DISCONNECT" : "CONNECT",
          style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(color: Colors.white),
        ));
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('${widget.device.remoteId}'),
    );
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected ? const Icon(Icons.bluetooth_connected) : const Icon(Icons.bluetooth_disabled),
        Text(((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''), style: Theme.of(context).textTheme.bodySmall)
      ],
    );
  }

  Widget buildGetServices(BuildContext context) {
    return IndexedStack(
      index: (_isDiscoveringServices) ? 1 : 0,
      children: <Widget>[
        TextButton(
          child: const Text("Get Services"),
          onPressed: onDiscoverServicesPressed,
        ),
        const IconButton(
          icon: SizedBox(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.grey),
            ),
            width: 18.0,
            height: 18.0,
          ),
          onPressed: null,
        )
      ],
    );
  }

  Widget buildMtuTile(BuildContext context) {
    return ListTile(
        title: const Text('MTU Size'),
        subtitle: Text('$_mtuSize bytes'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onRequestMtuPressed,
        ));
  }

  Widget buildconnectDeviceutton(BuildContext context) {
    if (_isConnectingOrDisconnecting) {
      return buildSpinner(context);
    } else {
      return buildConnectOrDisconnectButton(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName),
          actions: [buildconnectDeviceutton(context)],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              buildRemoteId(context),
              ListTile(
                leading: buildRssiTile(context),
                title: Text('Device is ${_connectionState.toString().split('.')[1]}.'),
                trailing: buildGetServices(context),
              ),
              buildMtuTile(context),
              ..._buildServiceTiles(context, widget.device),
            ],
          ),
        ),
      ),
    );
  }

  Stream<int> rssiStream({Duration frequency = const Duration(seconds: 5), int? maxItems = null}) async* {
    var isConnected = true;
    final subscription = widget.device.connectionState.listen((v) {
      isConnected = v == BluetoothConnectionState.connected;
    });
    int i = 0;
    while (isConnected && (maxItems == null || i < maxItems)) {
      try {
        yield await widget.device.readRssi();
      } catch (e) {
        print("Error reading RSSI: $e");
        break;
      }
      await Future.delayed(frequency);
      i++;
    }
    // Device disconnected, stopping RSSI stream
    subscription.cancel();
  }
}
