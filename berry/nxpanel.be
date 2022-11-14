
# Sonoff NSPanel Tasmota (Nextion with Flashing) driver | code by peepshow-21
# based on;
# Sonoff NSPanel Tasmota driver v0.47 | code by blakadder and s-hadinger

# Example Flash
# FlashNextion http://172.17.20.5:8080/static/chunks/nxpanel.tft
# FlashNextion http://proto.systems/nxpanel/nxpanel-1.0.0.tft

class Nextion : Driver

    static VERSION = "1.1.4"
    static header = bytes().fromstring("PS")

    static flash_block_size = 4096

    var flash_mode
    var flash_size
    var flash_written
    var flash_buff
    var flash_offset
    var awaiting_offset
    var tcp
    var ser
    var last_per
    var auto_update_flag

    def split_msg(b)   
        import string
        var ret = []
        var i = 0
        while i < size(b)-1
            if b[i] == 0x55 && b[i+1] == 0xAA
                if i > 0
                    var nb = b[0..i-1];
                    ret.push(nb)
                end
                b = b[i+2..]
                i = 0
            else
                i+=1
            end
        end
        if size(b) > 0
            ret.push(b)
        end
        return ret
    end

    def crc16(data, poly)
      if !poly  poly = 0xA001 end
      # CRC-16 MODBUS HASHING ALGORITHM
      var crc = 0xFFFF
      for i:0..size(data)-1
        crc = crc ^ data[i]
        for j:0..7
          if crc & 1
            crc = (crc >> 1) ^ poly
          else
            crc = crc >> 1
          end
        end
      end
      return crc
    end

    def encode(payload)
      var b = bytes()
      b += self.header
      var nsp_type = 0 # not used
      b.add(nsp_type)       # add a single byte
      var b1 = bytes().fromstring(payload)
      var b2 = bytes()
      for i: 0..size(b1)-1
        if (b1[i]!=0xC2)
            b2.add(b1[i])
        end
      end
      b.add(size(b2), 2)   # add size as 2 bytes, little endian
      b += b2
      var msg_crc = self.crc16(b)
      b.add(msg_crc, 2)       # crc 2 bytes, little endian
      return b
    end

    def encodenx(payload)
        var b = bytes().fromstring(payload)
        b += bytes('FFFFFF')
        return b
    end

    def sendnx(payload)
        import string
        var payload_bin = self.encodenx(payload)
        self.ser.write(payload_bin)
        log(string.format("NXP: Nextion command sent = %s",str(payload_bin)), 3)       
    end

    def send(payload)
        var payload_bin = self.encode(payload)
        if self.flash_mode==1
            log("NXP: skipped command becuase still flashing", 3)
        else 
            self.ser.write(payload_bin)
            log("NXP: payload sent = " + str(payload_bin), 3)
        end
    end

    def write_to_nextion(b)
        self.ser.write(b)
    end

    def screeninit()
        log("NXP: Screen Initialized") 
        self.sendnx("berry.txt=\""+self.VERSION+"\"")
        self.sendnx("click init_bn,1")
        self.sendnx("recmod=1")
        tasmota.delay(50)
        self.set_power()
        import persist
        if persist.has("config")
            var m = map()
            m.setitem("config",persist.config)
            var s = m.tostring()
            var json = ""
            for i: 0..size(s)-1
                if s[i]=="'"
                    json += '"'
                else
                    json += s[i]
                end
            end
            log("NXP: Restoring: "+json)
            self.send(json)
        end
        self.check_for_updates()
    end

    def write_block()
        
        import string
        log("FLH: Read block",3)
        while size(self.flash_buff)<self.flash_block_size && self.tcp.connected()
            if self.tcp.available()>0
                self.flash_buff += self.tcp.readbytes()
            else
                tasmota.delay(50)
                log("FLH: Wait for available...",3)
            end
        end
        log("FLH: Buff size "+str(size(self.flash_buff)),3)
        var to_write
        if size(self.flash_buff)>self.flash_block_size
            to_write = self.flash_buff[0..self.flash_block_size-1]
            self.flash_buff = self.flash_buff[self.flash_block_size..]
        else
            to_write = self.flash_buff
            self.flash_buff = bytes()
        end
        log("FLH: Writing "+str(size(to_write)),3)
        var per = (self.flash_written*100)/self.flash_size
        if (self.last_per!=per) 
            self.last_per = per
            tasmota.publish_result(string.format("{\"Flashing\":{\"complete\": %d}}",per), "RESULT") 
        end
        if size(to_write)>0
            self.flash_written += size(to_write)
            if self.flash_offset==0 || self.flash_written>self.flash_offset
                self.ser.write(to_write)
                self.flash_offset = 0
            else
                tasmota.set_timer(10,/->self.write_block())
            end
        end
        log("FLH: Total "+str(self.flash_written),3)
        if (self.flash_written==self.flash_size)
            log("FLH: Flashing complete")
            self.flash_mode = 0
        end

    end

    def every_100ms()
        import string
        if self.ser.available() > 0
            var msg = self.ser.read()
            if size(msg) > 0
                log(string.format("NXP: Received Raw = %s",str(msg)), 3)
                if (self.flash_mode==1)
                    var strv = msg[0..-4].asstring()
                    if string.find(strv,"comok 2")>=0
                        log("FLH: Send (High Speed) flash start")
                        self.sendnx(string.format("whmi-wris %d,115200,res0",self.flash_size))
                    elif size(msg)==1 && msg[0]==0x08
                        log("FLH: Waiting offset...",3)
                        self.awaiting_offset = 1
                    elif size(msg)==4 && self.awaiting_offset==1
                        self.awaiting_offset = 0
                        self.flash_offset = msg.get(0,4)
                        log("FLH: Flash offset marker "+str(self.flash_offset),3)
                        self.write_block()
                    elif size(msg)==1 && msg[0]==0x05
                        self.write_block()
                    else
                        log("FLH: Something has gone wrong flashing nxpanel ["+str(msg)+"]",2)
                    end
                else
                    var msg_list = self.split_msg(msg)
                    for i:0..size(msg_list)-1
                        msg = msg_list[i]
                        if size(msg) > 0
                            if msg == bytes('000000FFFFFF88FFFFFF')
                                self.screeninit()
                            elif msg[0]==0x7B # JSON, starting with "{"
                                var jm = string.format("%s",msg[0..-1].asstring())
                                tasmota.publish_result(jm, "RESULT")        
                            elif msg[0]==0x07 && size(msg)==1 # BELL/Buzzer
                                tasmota.cmd("buzzer 1,1")
                            else
                                var jm = string.format("{\"nextion\":\"%s\"}",str(msg[0..-4]))
                                tasmota.publish_result(jm, "RESULT")        
                            end
                        end       
                    end
                end
            end
        end
    end      

    def begin_nextion_flash()
        self.flash_written = 0
        self.awaiting_offset = 0
        self.flash_offset = 0
        self.sendnx('DRAKJHSUYDGBNCJHGJKSHBDN')
        self.sendnx('recmod=0')
        self.sendnx('recmod=0')
        self.flash_mode = 1
        self.sendnx("connect")        
    end
    
    def set_power()
      var ps = tasmota.get_power()
      for i:0..1
        if ps[i] == true
          ps[i] = "1"
        else 
          ps[i] = "0"
        end
      end
      var json_payload = '{ "switches": { "switch1": ' + ps[0] + ' , "switch2": ' + ps[1] +  ' } }'
      log('NXP: Switch state updated with ' + json_payload)
      self.send(json_payload)
    end

    def set_clock()
      var now = tasmota.rtc()
      var time_raw = now['local']
      var nsp_time = tasmota.time_dump(time_raw)
      var time_payload = '{ "clock": { "date":' + str(nsp_time['day']) + ',"month":' + str(nsp_time['month']) + ',"year":' + str(nsp_time['year']) + ',"weekday":' + str(nsp_time['weekday']) + ',"hour":' + str(nsp_time['hour']) + ',"min":' + str(nsp_time['min']) + ' } }'
      log('NXP: Time and date synced with ' + time_payload, 3)
      self.send(time_payload)
    end

    def open_url(url)

        import string
        var host
        var port
        var s1 = string.split(url,7)[1]
        var i = string.find(s1,":")
        var sa
        if i<0
            port = 80
            i = string.find(s1,"/")
            sa = string.split(s1,i)
            host = sa[0]
        else
            sa = string.split(s1,i)
            host = sa[0]
            s1 = string.split(sa[1],1)[1]
            i = string.find(s1,"/")
            sa = string.split(s1,i)
            port = int(sa[0])
        end
        var get = sa[1]
        log(string.format("FLH: host: %s, port: %s, get: %s",host,port,get))
        self.tcp = tcpclient()
        self.tcp.connect(host,port)
        log("FLH: Connected:"+str(self.tcp.connected()),3)
        var get_req = "GET "+get+" HTTP/1.0\r\n"
	get_req += string.format("HOST: %s:%s\r\n\r\n",host,port)
        self.tcp.write(get_req)
        var a = self.tcp.available()
        i = 1
        while a==0 && i<5
          tasmota.delay(100*i)
          tasmota.yield() 
          i += 1
          log("FLH: Retry "+str(i),3)
          a = self.tcp.available()
        end
        if a==0
            log("FLH: Nothing available to read!",3)
            return
        end
        var b = self.tcp.readbytes()
        i = 0
        var end_headers = false;
        var headers
        while i<size(b) && headers==nil
            if b[i..(i+3)]==bytes().fromstring("\r\n\r\n") 
                headers = b[0..(i+3)].asstring()
                self.flash_buff = b[(i+4)..]
            else
                i += 1
            end
        end
        #print(headers)
		# check http respose for code 200
		var tag = "200 OK"
        i = string.find(headers,tag)
        if (i>0) 
            log("FLH: HTTP Respose is 200 OK",3)
		else
            log("FLH: HTTP Respose is not 200 OK",3)
			print(headers)
			return
        end
		# check http respose for content-length
        tag = "Content-Length: "
        i = string.find(headers,tag)
        if (i>0) 
            var i2 = string.find(headers,"\r\n",i)
            var s = headers[i+size(tag)..i2-1]
            self.flash_size=int(s)
        end
        if self.flash_size==0
            log("FLH: No size header, counting ...",3)
            self.flash_size = size(self.flash_buff)
            #print("counting start ...")
            while self.tcp.connected()
                while self.tcp.available()>0
                    self.flash_size += size(self.tcp.readbytes())
                end
                tasmota.delay(50)
            end
            #print("counting end ...",self.flash_size)
            self.tcp.close()
            self.open_url(url)
        else
            log("FLH: Size found in header, skip count",3)
        end
        log("FLH: Flash file size: "+str(self.flash_size),3)

    end

    def flash_nextion(url)

        self.flash_size = 0
        self.open_url(url)
        self.begin_nextion_flash()

    end

    def version_number(sval)
        import string
        var i1 = string.find(sval,".",0)
        var i2 = string.find(sval,".",i1+1)
        var num = int(sval[0..i1-1])*10000+int(sval[i1+1..i2-1])*100+int(sval[i2+1..])
        return num
    end

    def auto_update()

        log("NXP: Triggering update check");
        self.auto_update_flag = 1
        var json = '{"config": ""}'
        self.send(json)

    end

    def update_trigger (value, trigger, msg)
        log("NXP: persist msg: "+str(msg),3)
        import persist
        persist.config = msg.item("config")
        persist.save()
        log("NXP: persist saved",3)
        if self.auto_update_flag==0
            return
        end
        self.auto_update_flag = 0
        import string
        var url = nil
        if msg.item("config").item("at")==1
            log("NXP: Update check for 'testing'")
            url = "http://proto.systems/nxpanel/version-testing.txt"
        elif msg.item("config").item("au")==1
            log("NXP: Update check for 'release'")
            url = "http://proto.systems/nxpanel/version-release.txt"
        else
            log("NXP: No auto update active")
        end
        if url!=nil
            var web = webclient()
            log("FLH: Open: "+url,3)
            web.begin(url)
            log("FLH: GET ...",3)
            var r = web.GET()
            log("FLH: STAT "+str(r),3)
            var ver = web.get_string()
            var i=string.find(ver,"\n")
            if i>0
                ver = ver[0..i-1]
            end
            if self.version_number(ver)>self.version_number(value)
                log("NXP: Newer version available - "+ver)
                url = "http://proto.systems/nxpanel/nxpanel-"+ver+".tft"
                tasmota.set_timer(100,/->self.flash_nextion(url))
            else
                log("NXP: Current version "+value+" is latest")
            end
            web.close()
        end
    end

    def check_for_updates()
        
        self.auto_update()
        tasmota.set_timer(1000*60*60*24,/->self.check_for_updates()) # daily

    end

    def init()
        log("NXP: Initializing Driver")
        self.ser = serial(17, 16, 115200, serial.SERIAL_8N1)
        self.sendnx('DRAKJHSUYDGBNCJHGJKSHBDN')
        self.sendnx('rest')
        self.flash_mode = 0
    end

    def install()

        self.flash_nextion("http://proto.systems/nxpanel/nxpanel-latest.tft")

    end

end

var nextion = Nextion()

tasmota.add_driver(nextion)

def flash_nextion(cmd, idx, payload, payload_json)
    def task()
        nextion.flash_nextion(payload)
    end
    tasmota.set_timer(0,task)
    tasmota.resp_cmnd_done()
end

def send_cmd(cmd, idx, payload, payload_json)
    nextion.sendnx(payload)
    tasmota.resp_cmnd_done()
end

def send_cmd2(cmd, idx, payload, payload_json)
    nextion.send(payload)
    tasmota.resp_cmnd_done()
end

def auto_update(cmd, idx, payload, payload_json)
    nextion.auto_update()
    tasmota.resp_cmnd_done()
end

def install_nxpanel()
    tasmota.set_timer(50,/->nextion.install())
    tasmota.resp_cmnd_done()
end

tasmota.add_cmd('Nextion', send_cmd)
tasmota.add_cmd('Screen', send_cmd2)
tasmota.add_cmd('NxPanel', send_cmd2)
tasmota.add_cmd('FlashNextion', flash_nextion)
tasmota.add_cmd('AutoFlash', auto_update)
tasmota.add_cmd('InstallNxPanel', install_nxpanel)

tasmota.add_rule("power1#state", /-> nextion.set_power())
tasmota.add_rule("power2#state", /-> nextion.set_power())
tasmota.add_rule("Time#Minute", /-> nextion.set_clock())
tasmota.add_rule("alarm#update=1", /-> nextion.auto_update())
tasmota.add_rule("config#v", /a,b,c-> nextion.update_trigger(a,b,c))
tasmota.cmd("Rule3 1") # needed until Berry bug fixed
tasmota.cmd("State")

