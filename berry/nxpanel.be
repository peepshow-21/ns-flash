
# Sonoff NSPanel Tasmota (Nextion with Flashing) driver | code by peepshow-21
# based on;
# Sonoff NSPanel Tasmota driver v0.47 | code by blakadder and s-hadinger

class Nextion : Driver

    static VERSION = "v1.0.0-beta1"
    static CHUNK_FILE = "nextion"
    static header = bytes().fromstring("PS")

    var flash_mode
    var ser
    var chunk_url
    var flash_size
    var chunk
    var tot_read
    var last_per

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
        log(string.format("NSP: Nextion command sent = %s",str(payload_bin)), 3)       
    end

    def send(payload)
        var payload_bin = self.encode(payload)
        if self.flash_mode==1
            log("NSP: skipped command becuase still flashing", 3)
        else 
            self.ser.write(payload_bin)
            log("NSP: payload sent = " + str(payload_bin), 3)
        end
    end

    def getPage(url)
        var s
        var retry = 0
        while (retry>=0 && retry<5)
            var wc = webclient()
            wc.begin(url)
            var r = wc.GET()
            if (r==200)
                s = wc.get_string()
                retry = -1
            else
                s = nil
                retry = retry + 1
                log("NSP: HTTP retry required")
            end
            wc.close()
        end
        if (s==nil) 
            log("NSP: Failed to load chunk over http")
        end
        return s    
    end

    def write_to_file(b)
        log("DBG: Write to file")
        var f = open("test.bin","a")
        f.write(b)
        f.close()
    end

    def write_to_nextion(b)
        self.ser.write(b)
    end

    def write_chunk()
        import string
        var name = string.format("%s/%s-%04d.hex",self.chunk_url,self.CHUNK_FILE,self.chunk)
        var s = self.getPage(name)
        var b = bytes(s)
        #self.write_to_file(b)
        self.write_to_nextion(b)
        return b.size()
    end

    def init()
        log("NSP: Initializing Driver")
        self.ser = serial(17, 16, 115200, serial.SERIAL_8N1)
        self.sendnx('DRAKJHSUYDGBNCJHGJKSHBDN')
        self.flash_mode = 0
    end

    def screeninit()
        log("NSP: Screen Initialized") 
        self.sendnx("berry_ver.txt=\"berry: "+self.VERSION+"\"")
    end

    def every_100ms()
        import string
        if self.ser.available() > 0
            var msg = self.ser.read()
            if size(msg) > 0
                log(string.format("NSP: Received Raw = %s",str(msg)), 3)
                if (self.flash_mode==1)
                    var str = msg[0..-4].asstring()
                    log(str, 3)
                    if (string.find(str,"comok 2")==0) 
                        self.sendnx(string.format("whmi-wri %d,115200,res0",self.flash_size))
                    elif (size(msg)==1 && msg[0]==0x05)
                        var x = self.write_chunk()
                        self.tot_read = self.tot_read + x
                        self.chunk = self.chunk + 1
                        var per = (self.tot_read*100)/self.flash_size
                        if (self.last_per!=per) 
                            self.last_per = per
                            tasmota.publish_result(string.format("{\"Flashing\":{\"complete\": %d}}",per), "RESULT") 
                        end
                        if (self.tot_read==self.flash_size)
                            log("NSP: Flashing complete")
                            self.flash_mode = 0
                        end
                        tasmota.yield()
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

    def begin_file_flash()
        self.flash_mode = 1
        var f = open("test.bin","w")
        f.close()
        while self.tot_read<self.flash_size
            var x = self.write_chunk()
            self.tot_read = self.tot_read + x
            self.chunk = self.chunk + 1
            tasmota.yield()
        end        
    end

    def begin_nextion_flash()
        self.sendnx('DRAKJHSUYDGBNCJHGJKSHBDN')
        self.sendnx('recmod=0')
        self.sendnx('recmod=0')
        self.sendnx("connect")        
        self.flash_mode = 1
    end
    
    def start_flash(url)
        self.last_per = -1
        self.chunk_url = url
        import string
        var file = (string.format("%s/%s.txt",self.chunk_url,self.CHUNK_FILE))
        var s = self.getPage(file)
        self.flash_size = int(s)
        self.tot_read = 0
        self.chunk = 0
        #self.begin_file_flash()
        self.begin_nextion_flash()
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
      log('NSP: Switch state updated with ' + json_payload)
      self.send(json_payload)
    end

    def set_clock()
      var now = tasmota.rtc()
      var time_raw = now['local']
      var nsp_time = tasmota.time_dump(time_raw)
      var time_payload = '{ "clock": { "date":' + str(nsp_time['day']) + ',"month":' + str(nsp_time['month']) + ',"year":' + str(nsp_time['year']) + ',"weekday":' + str(nsp_time['weekday']) + ',"hour":' + str(nsp_time['hour']) + ',"min":' + str(nsp_time['min']) + ' } }'
      log('NSP: Time and date synced with ' + time_payload, 3)
      self.send(time_payload)
    end

end

var nextion = Nextion()

tasmota.add_driver(nextion)

def flash_nextion(cmd, idx, payload, payload_json)
    def task()
        nextion.start_flash(payload)
    end
    tasmota.set_timer(0,task)
    tasmota.resp_cmnd_done()
end

tasmota.add_cmd('FlashNextion', flash_nextion)

def send_cmd(cmd, idx, payload, payload_json)
    nextion.sendnx(payload)
    tasmota.resp_cmnd_done()
end

tasmota.add_cmd('Nextion', send_cmd)

def send_cmd2(cmd, idx, payload, payload_json)
    nextion.send(payload)
    tasmota.resp_cmnd_done()
end

tasmota.add_cmd('Screen', send_cmd2)
tasmota.add_cmd('NxPanel', send_cmd2)

tasmota.add_rule("power1#state", /-> nextion.set_power())
tasmota.add_rule("power2#state", /-> nextion.set_power())
tasmota.cmd("Rule3 1") # needed until Berry bug fixed
tasmota.add_rule("Time#Minute", /-> nextion.set_clock())
tasmota.cmd("State")


