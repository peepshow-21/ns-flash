# HowTo set up a IIS Webserver under Windows

## Why I need a webserver?
To upload the tft file to your NS-Panel display you need a webserver who provides the needed files.
Under Windows you con use the integrated IIS Webserver but the setup has some pitfalls.
This tutorial is a step by step walk through so you have it easy to set it up.

## Aktivate the IIS Webserver
Go to the search bar beside the Windows Startbutton and type "windows-feature" and choose Windows-features aktivation:
![Windows-Features](https://github.com/peepshow-21/ns-flash/pictures/Windows_feature.jpg)
Now you choose "Internetinformationservice and "Ok" to install the IIS Webserver.
![Activate Internetinformationservice](https://github.com/peepshow-21/ns-flash/pictures/internetinformationsdienste.jpg)


## Configure the IIS Webserver
You have to config the webservice so that it works with the NS-Panel upload routine.:
First you have to open the IIS Manager, for that type in the search field beside the Windows Start Button "IIS" and choose IIS Manager.
![Open ISS Manager](https://github.com/peepshow-21/ns-flash/pictures/ISS-Manager.jpg)

![ISS Manager](https://github.com/peepshow-21/ns-flash/pictures/iis_manager.jpg)

1. choose "browse directories" and then klick on "activate" and on the Arrow top left to get back.

![Activate browsing](https://github.com/peepshow-21/ns-flash/pictures/iis_verzeichnis.jpg)

2. We have to registry the .hex type what the ns-flash tool use. For that choose "MIME-Typ".
![Registry HEX](https://github.com/peepshow-21/ns-flash/pictures/iis_mime_hinzu.jpg)

You Type on 1 .hex and on 2 what ever you like I used "hex/file".
![Registry HEX](https://github.com/peepshow-21/ns-flash/pictures/iis_mime.jpg)

Now the webserer is ready.

## Configure the webserver folder
The NS-Flash tool needs access to the folder "c:\inetpub" so use the Explorer to open the "propertys" of the inetpub folder.
Go to the tab security, click on user and then "full access".
![Registry HEX](https://github.com/peepshow-21/ns-flash/pictures/zugriff.jpg)

## Use the NS-Flash Tool to update your display
First I made a subfolder named "nexion" under "C:\inetpub\wwwroot\" the I opened the ns.flash.jar and under 1 you choose the tft file what you want to flash and under 2 the directory in the "c:\inetpub\wwwroot" folder, in my case "c:\inetpub\wwwroot\nexion".
![NS.Flash Tool](https://github.com/peepshow-21/ns-flash/pictures/ns_flash.jpg)

After the tool is ready you go to the ns-panel Tasmota site and under the console you type the command: "FlashNextion http://192.168.178.110/nexion" where "192.168.178.110" is the IP of your windows pc where the IIS Webserver runs.
Now you have to wait some time till the flashing is ready.
![NS-Panel Console](https://github.com/peepshow-21/ns-flash/wiki/pitures/ns_console.jpg)