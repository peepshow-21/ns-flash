
# Sonoff NSPanel Tasmota (Nextion with Flashing) driver v0.02 | code by peepshow-21
# based on;
# Sonoff NSPanel Tasmota driver v0.47 | code by blakadder and s-hadinger
class Nextion : Driver

    static CHUNK_FILE = "nextion"

    var flash_mode
    var ser
    var chunk_url
    var flash_size
    var chunk
    var tot_read
    var last_per

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
                log("NSP: HTTP retry reuired")
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
                            tasmota.publish_result(string.format("{\"NSPanel\":{\"Flashing\":{\"complete\": %d}}}",per), "RESULT") 
                        end
                        if (self.tot_read==self.flash_size)
                            log("NSP: Flashing complete")
                            self.flash_mode = 0
                        end
                        tasmota.yield()
                    end
                else
                    if msg == bytes('000000FFFFFF88FFFFFF')
                        self.screeninit()
                    elif msg[0]==0x4A
                        var jm = string.format("{\"NSPanel\":{\"JSON\":\"%s\"}}",msg[1..-1].asstring())
                        tasmota.publish_result(jm, "RESULT")        
                    else
                        var jm = string.format("{\"NSPanel\":{\"Nextion\":\"%s\"}}",str(msg[0..-4]))
                        tasmota.publish_result(jm, "RESULT")        
                    end       
                end
            end
        end
    end      

    def begin_file_flash()
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
        self.sendnx("connect")        
    end
    
    def start_flash(url)
        self.last_per = -1
        self.flash_mode = 1
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

