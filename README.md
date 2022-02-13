## Tasmota and Sonoff NSPanel

Once you have installed Tasmota using the guide here;

https://templates.blakadder.com/sonoff_NSPanel.html

Copy `nxpanel.be` file to to device;

https://github.com/peepshow-21/ns-flash/blob/master/berry/nxpanel.be

Change the autoexec.be file to load `nxpanel.be` instead.

Copy your tft to a place accessable via http.

In tasmota console type;
```
flashnextion http://www.whatever.com/nspanel.tft
```

That should be all you need.

## NxPanel Firmware ##

If you prefer to use `NxPanel` instead of stock, it's even easy
```
installnxpanel
```

That's it. If you turn on auto updates in the setup, you don't even need to reflash again. it will it all for you.


