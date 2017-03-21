# MagicLightBulbLEX
MagicLightBulb with MacBook Pro Touch Bar control

Using the MacBook Pro Touch Bar to control the color of the LED Lightbulb over Bluetooth Low Energy (BLE).

Since LED lightbulbs on the market use different protocols to operate the light, it is unlikely at this moment to have a universal app that can work for all these lightbulbs. Therefore, this app is the same, it is customized only for a few specific LED lightbulbs and I am pretty sure it will NOT work with yours.

However, this serve as an example, together with MagicLightLEX, how one can use the Apple MacBook Pro's TouchBar to control some BLE device.

The application is pretty basic, following the simplest rule to build a BLE application on the OSX. The color is written to the LED lightbulb via a BLE Write operation to a specific characteristic UUID. In order to improve the responsiveness when writing continuously in a very quick manner, like when your finger is sweeping across the colorful spectrum or the color pallet, the BLE Write does not request for any reply (acknowledgement that the data is successfully written to the device) and thus may not be 100% reliable under all conditions.

The application when started, does not currently remember the last setting (color, brightness whatever) since the LED lightbulb may be operated via some other means. It does not request the current setting from the lightbulb either, purely because I am lazy. So, may be later.

If you find this useful, I am glad I can help. If not, feel free to move on.


//Ed 2017/03
