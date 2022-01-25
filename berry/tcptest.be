class TCPTest

    static flash_url = "http://172.17.20.5:8080/static/chunks/nxpanel.tft"
    static max_block = 4096

    var flash_size
    var flash_count
    var flash_mode
    var flash_complete
    var flash_buff
    var really_read
    var tcp

    def open_url()

        import string
        var host
        var port
        var s1 = string.split(self.flash_url,7)[1]
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
        print(host,port,get)
        self.tcp = tcpclient()
        self.tcp.connect(host,port)
        self.tcp.write("GET "+get+" HTTP/1.0\r\n\r\n")

    end

    def readbytes()

        for retry: 1..3
            if self.tcp.available()>0
                tasmota.gc()
                tasmota.yield()
                var b = self.tcp.readbytes()
                self.really_read+=size(b)
                return b
            end
            tasmota.delay(100*retry)
        end
        return nil

    end

    def get_next_block()

        var w_buff
        while size(self.flash_buff)<self.max_block && !self.flash_complete
            var b = self.readbytes()
            if b!=nil
                self.flash_buff += b
            else
                self.flash_complete = true
            end
        end
        if size(self.flash_buff)>self.max_block
            w_buff = self.flash_buff[0..self.max_block-1]
            self.flash_buff = self.flash_buff[self.max_block..]
        else 
            w_buff = self.flash_buff
            self.flash_buff = bytes()
        end
        return w_buff

    end

    def flash_loop()
        
        var loop = 0
        while self.flash_count<self.flash_size
            var b = self.get_next_block()
            if size(b)>0
                self.flash_count+=size(b)
                #print("written",size(b))
                #  write_block
                tasmota.delay(100)
                tasmota.gc()
                tasmota.yield()
            else 
                print("flash complete, wrote", self.flash_count)
                self.flash_count = self.flash_size
                print("zero bytes?")
            end
            loop += 1
            if self.flash_count>500000 #1332918
                print("flash complete, wrote", self.flash_count, self.really_read)
                self.flash_count = self.flash_size
            end
        end
        self.flash_mode = 0;
        print("flash complete, wrote", self.flash_count,tasmota.gc())

    end
                    
    def start_flash()

        self.really_read = 0
        tasmota.set_timer(0,self.flash_loop())

    end

        
    def flash()

        self.really_read = 0
        self.flash_mode = 1
        self.flash_complete = false
        self.flash_size = 0
        self.flash_count = 0
        self.flash_buff = bytes()
        self.open_url()
        var b = bytes()
        while b != nil
            b = self.readbytes()
            if (b!=nil)
                self.flash_size+=size(b)
            end
        end
        self.tcp.close()
        print("flash size",self.flash_size)
        self.open_url()
        self.start_flash()

    end
                
end
 
tcptest = TCPTest()
tcptest.flash()



