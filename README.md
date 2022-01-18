## Tasmota and Sonoff NSPanel

### Quick early version of TFT custom screen firmware upload

Copy the `nextion.bs` file to your device with the File System Manager. Change the `autoexec.bs` to load that instead of the `nspanel.bs` if you were using that with the stock screen firmware.

https://github.com/peepshow-21/ns-flash/blob/master/berry/nextion.be

![image](https://user-images.githubusercontent.com/42150988/149680209-554a098b-6fa9-4ca2-be68-923ad94c47d9.png)

![image](https://user-images.githubusercontent.com/42150988/149680241-ddd5124a-ec0a-4389-99ed-cb70a89fb28b.png)


Download the jar file and run it with an installed java runtime on your windows or linux host. It should show a little app to convert the file.

![image](https://user-images.githubusercontent.com/42150988/149680122-1b876b0d-ac0a-40a3-bfda-714a1c7ce76d.png)

https://github.com/peepshow-21/ns-flash/releases/download/v.0.0.4-alpha/ns-flash.jar

Browse to the TFT file you want to upload.
Select the folder you want the chunk files to to. It's best to make this a folder that is seen by your local http server. But you can put them anyway and move the after.
Press 'Build'. It will split the TFT into files tamsota can load

Boot the NSPanel with the new nextion.bs loaded.
At the console, type;

![image](https://user-images.githubusercontent.com/42150988/149680300-aa0c5544-445c-4f18-b90a-5aaf2b601a51.png)

Where this is the place the chunk files live.

It shows progress in the console as MQT so you can monitor from Openhab or other Automation

![image](https://user-images.githubusercontent.com/42150988/149680389-0444e363-08be-4765-b83d-c505921e2614.png)

That's it. then just wait. The display should show install progress.

![image](https://user-images.githubusercontent.com/42150988/149680472-f2992fe2-c62e-40e7-99b6-4a8dd948551c.png)

When it's complete it will just reboot.



