class TCPTest

    #static flash_url = "http://demo-hadinger.s3.eu-west-3.amazonaws.com:80/nxpanel.tft"
    static flash_url = "http://172.17.20.5:8080/static/chunks/nxpanel.tft"
    static max_block = 4096

    var flash_size
    var flash_count
    var flash_mode
    var flash_complete
    var flash_buff

    var really_read    
    var tcp
    var loop_max

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
        print("connected:", tcp.connected())
        var get_req = "GET "+self.flash_url+" HTTP/1.0\r\n\r\n"
        self.tcp.write(get_req)
        var a = self.tcp.available()
        i = 0
        while a==0 && i<3
          tasmota.delay(100)
          i += 1
          print ("retry", i)
          a = self.tcp.available()
        end
        if a==0
            print("no data!")
            return
        end
        var b = self.tcp.readbytes()
        print("read",size(b))
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
        #print("headers", headers)
        var tag = "Content-Length: "
        i = string.find(headers,tag)
        if (i>0) 
            var i2 = string.find(headers,"\r\n",i)
            var s = headers[i+size(tag)..i2-1]
            self.flash_count=int(s)
        end
        if self.flash_count==0
            print("counting ...")
            self.flash_count = size(self.flash_buff)
            while self.tcp.connected()
                while self.tcp.available()>0
                    self.flash_count += size(self.tcp.readbytes())
                end
                tasmota.delay(50)
            end
            self.tcp.close()
            self.open_url()
        end
        print("file size", self.flash_count)

    end

    def proc_block(b)
    
        self.flash_count += size(b)
        print("read", size(b), self.flash_count)

    end
                    
    def loop_till_done()

        while self.tcp.available()>0
            var b = self.tcp.readbytes();
            self.flash_buff += b
            while size(self.flash_buff)>self.max_block
                self.proc_block(self.flash_buff[1..self.max_block])
                self.flash_buff = self.flash_buff[self.max_block..]
            end
        end
        if self.tcp.connected()
            tasmota.set_timer(50,self.loop_till_done)
        else
            if size(self.flash_buff)>0
                self.proc_block(self.flash_buff)
            end
            print("complete")
        end

    end

    def start_flash()

        self.flash_count = 0
        self.flash_buff = bytes()
        self.open_url()
        print("url opened")
        #self.loop_till_done()
        print("done", self.flash_url)

    end
                        
end
 
tcptest = TCPTest()

tcptest.start_flash()



