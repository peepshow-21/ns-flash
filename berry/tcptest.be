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

    def check_int(max)

        self.openUrl()

        var tot = 0;
        for i: 1..max
            var a = self.tcp.available()
            if a>0
                var b = self.tcp.readbytes()
                print ("read", b.size())
                tot += b.size()
                tasmota.yield()
            else
                print ("not available: ", a)
                tasmota.delay(100)
            end
        end
        print("done: ", tot)

        self.tcp.close()

    end

    def check(max)

        var i = max
        tasmota.set_timer(0, self.check_int(i))

    end


end
 
tcptest = TCPTest()
tcptest.check(100)



