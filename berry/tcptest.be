class TCPTest

    static flash_url = "http://172.17.20.5:8080/static/chunks/nxpanel.tft"

    var flash_size
    var tcp

    def openUrl()

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
                return self.tcp.readbytes()
            end
            tasmota.delay(100)
        end
        return nil

    end

    def send_parts()

        self.openUrl()

        var max = 4096
        var buff = bytes()
        var w_buff
        var complete = false
        var count = 0
        while !complete
            while size(buff)<max && !complete
                var b = self.readbytes()
                if b!=nil
                    buff += b
                else
                    complete = true
                end
            end
            if size(buff)>max
                w_buff = buff[0..max-1]
                buff = buff[max..]
            else 
                w_buff = buff
                buff = bytes()
            end
            if size(w_buff)>0
                print("part",size(w_buff))
                count += size(w_buff)
            end
        end

        print("count",count)

        self.tcp.close()

    end
                
    def check_int(max)

        self.openUrl()
        
        var count=0
        var b = bytes()
        while b!=nil
            b = self.readbytes()
            if (b!=nil)
                count+=size(b)
            end
        end
        print("size",count)

        self.tcp.close()

    end

    def check(max)

        var i = max
        tasmota.set_timer(0, self.check_int(i))

    end


end
 
tcptest = TCPTest()
tcptest.send_parts()



