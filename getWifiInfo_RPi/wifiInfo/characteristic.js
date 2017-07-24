var util = require('util');
var fs = require('fs');

var bleno = require('bleno');

var wifi = require('node-wifi');

var BlenoCharacteristic = bleno.Characteristic;

var EchoCharacteristic = function () {
	EchoCharacteristic.super_.call(this, {
		uuid: 'ec0e',
		properties: ['read', 'write', 'notify'],
		value: null
	});

	this._value = new Buffer(0);
	this._updateValueCallback = null;
};

util.inherits(EchoCharacteristic, BlenoCharacteristic);

EchoCharacteristic.prototype.onReadRequest = function (offset, callback) {
	console.log('EchoCharacteristic - onReadRequest: value = ' + this._value.toString());

	callback(this.RESULT_SUCCESS, this._value);
};

EchoCharacteristic.prototype.onSubscribe = function (maxValueSize, updateValueCallback) {
	console.log('EchoCharacteristic - onSubscribe');

	console.log(maxValueSize);

	this._updateValueCallback = updateValueCallback;
};

EchoCharacteristic.prototype.onUnsubscribe = function () {
	console.log('EchoCharacteristic - onUnsubscribe');

	this._updateValueCallback = null;
};

EchoCharacteristic.prototype.onWriteRequest = function (data, offset, withoutResponse, callback) {

	var dataStr = data.toString();
	var wifiInfo = null;
	if (dataStr.length >= 2) {
		wifiInfo = JSON.parse(data.toString());
	}
	this._value = data;

	console.log('EchoCharacteristic - onWriteRequest-xxx: value = ' + this._value.toString());
	if (wifiInfo === undefined || wifiInfo === null) { return; }
	console.log('EchoCharacteristic - onWriteRequest-xxx: wifi.name = ' + wifiInfo['name']);
	console.log('EchoCharacteristic - onWriteRequest-xxx: wifi.passwd = ' + wifiInfo['passwd']);


	// wpaConfWithWifiInfo(wifiInfo);
	wifi.init({
		iface: "wlan0", // network interface, choose a random wifi interface if set to null
		debug: true
	});

	var that = this;
	wifi.getCurrentConnections(function (err, curConn) {

		if (err) {
			console.log("got err @ call getCurrentConnections. err: " + err);
		}

		if (curConn) {
			console.log("current wifi connections : " + JSON.stringify(curConn));
			console.log("starting disconnect wifi connections");

			wifi.disconnect(function (err) {
				if (err) {
					console.log(err);
				} else {
					console.log('Disconnected.');
				}


				wifi.connect({ ssid: wifiInfo['name'], password: wifiInfo['passwd'] }, function (err) {
					if (err) {
						var failMessage = "connect failed: " + err;
						console.log(failMessage);

						// send fail message to App
						that._value = new Buffer(failMessage);

					} else {

						var successMessage = "wifi connect success";
						console.log(successMessage);

						// send success message to app
						that._value = new Buffer(successMessage);
					}
					if (that._updateValueCallback) {
						console.log('onWriteRequest: notifying: ' + that._value);
						that._updateValueCallback(that._value);
					}
					callback(that.RESULT_SUCCESS);
				});

			});
		}

	});

	if (this._updateValueCallback) {

		console.log("_updateValueCallback: ");
		console.log(this._updateValueCallback);
	}

	callback(this.RESULT_SUCCESS);
};

var wpaConfWithWifiInfo = function (wifiInfo) {

	var wifiData = '\nnetwork={\n        ssid="' + wifiInfo['name'] +
		'"\n        psk="' + wifiInfo['passwd'] + '"\n        key_mgmt=WPA-PSK\n}';

	confPath = '/etc/wpa_supplicant/wpa_supplicant.conf';

	fs.readFile(confPath, function (err, data) {
		if (err) {
			console.log('\nread conf file err: ' + err);
		} else {
			console.log('\ncur conf file content: \n' + data);


			var checkStr = 'ssid="' + wifiInfo['name'] + '"';
			if (data.indexOf(checkStr) != -1) {

				console.log('\nwifi info already exist.');
				return;
			}

			fs.appendFile(confPath, wifiData, 'utf8', function (err) {
				if (err) {
					console.log('\nwrite wifiInfo to conf err: ' + err);
				} else {
					console.log('\nwrite finish.');
					var curData = fs.readFileSync(confPath);
					if (curData) {
						console.log('\nconf file content after write: \n' + curData);

						// reboot

						var exec = require('child_process').exec;
						setTimeout(function () {
							exec('sudo ifdown wlan0');
							setTimeout(function () {
								exec('sudo ifup wlan0');
							}, 1000);
						}, 2000);

					}
				}
			});
		}
	});
};


module.exports = EchoCharacteristic;
