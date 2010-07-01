module Epp #:nodoc:
  class Server
    include REXML
    include RequiresParameters
        
    attr_accessor :tag, :password, :server, :port, :old_server, :services, :lang, :extensions, :version
    
    # ==== Required Attrbiutes
    # 
    # * <tt>:server</tt> - The EPP server to connect to
    # * <tt>:tag</tt> - The tag or username used with <tt><login></tt> requests.
    # * <tt>:password</tt> - The password used with <tt><login></tt> requests.
    # 
    # ==== Optional Attributes
    #
    # * <tt>:port</tt> - The EPP standard port is 700. However, you can choose a different port to use.
    # * <tt>:clTRID</tt> - The client transaction identifier is an element that EPP specifies MAY be used to uniquely identify the command to the server. You are responsible for maintaining your own transaction identifier space to ensure uniqueness. Defaults to "ABC-12345"
    # * <tt>:old_server</tt> - Set to true to read and write frames in a way that is compatible with older EPP servers. Default is false.
    # * <tt>:lang</tt> - Set custom language attribute. Default is 'en'.
    # * <tt>:services</tt> - Use custom EPP services in the <login> frame. The defaults use the EPP standard domain, contact and host 1.0 services.
    # * <tt>:extensions</tt> - URLs to custom extensions to standard EPP. Use these to extend the standard EPP (e.g., Nominet uses extensions). Defaults to none.
    # * <tt>:version</tt> - Set the EPP version. Defaults to "1.0".
    def initialize(attributes = {})
      requires!(attributes, :tag, :password, :server)
      
      @tag        = attributes[:tag]
      @password   = attributes[:password]
      @server     = attributes[:server]
      @port       = attributes[:port]       || 700
      @old_server = attributes[:old_server] || false
      @lang       = attributes[:lang]       || "en"
      @services   = attributes[:services]   || ["urn:ietf:params:xml:ns:domain-1.0", "urn:ietf:params:xml:ns:contact-1.0", "urn:ietf:params:xml:ns:host-1.0"]
      @extensions = attributes[:extensions] || []
      @version    = attributes[:verison]    || "1.0"
      @debug_log  = attributes[:debug_log]  || false
      
      @logged_in  = false
    end
    
    # Sends an XML request to the EPP server, and receives an XML response. 
    # <tt><login></tt> and <tt><logout></tt> requests are also wrapped
    # around the request, so we can close the socket immediately after
    # the request is made.
    def request(xml)
      open_connection
      
      @logged_in = true if login
      
      begin
        puts "** EPP - Sending frame..." if @debug_log
        @response = send_request(xml)
      ensure
        if @logged_in && !old_server
          @logged_in = false if logout
        end
        
        close_connection
      end
      
      return @response
    end
    
    private
    
    # Sends a standard login request to the EPP server.
    def login
      puts "** EPP - Attempting login..." if @debug_log
      
      xml = new_epp_request
      
      command = xml.root.add_element("command")
      login = command.add_element("login")
      
      login.add_element("clID").text = tag
      login.add_element("pw").text = password
      
      options = login.add_element("options")
      options.add_element("version").text = version
      options.add_element("lang").text = lang
      
      services = login.add_element("svcs")
      services.add_element("objURI").text = "urn:ietf:params:xml:ns:domain-1.0"
      services.add_element("objURI").text = "urn:ietf:params:xml:ns:contact-1.0"
      services.add_element("objURI").text = "urn:ietf:params:xml:ns:host-1.0"
      
      # Include schema extensions for registrars which require it
      extensions_container = services.add_element("svcExtension") unless extensions.empty?
      
      for uri in extensions
        extensions_container.add_element("extURI").text = uri
      end
      
      command.add_element("clTRID").text = "ABC-12345"

      # Receive the login response
      response = Hpricot.XML(send_request(xml.to_s))

      result_message  = (response/"epp"/"response"/"result"/"msg").text.strip
      result_code     = (response/"epp"/"response"/"result").attr("code").to_i
   
      if result_code == 1000
        puts "** EPP - Successfully logged in." if @debug_log
        return true
      else
        raise EppErrorResponse.new(:xml => response, :code => result_code, :message => result_message)
      end
    end
    
    # Sends a standard logout request to the EPP server.
    def logout
      puts "** EPP - Attempting logout..." if @debug_log
      
      xml = new_epp_request
      
      command = xml.root.add_element("command")
      login = command.add_element("logout")
      
      # Receive the logout response
      response = Hpricot.XML(send_request(xml.to_s))
      
      result_message  = (response/"epp"/"response"/"result"/"msg").text.strip
      result_code     = (response/"epp"/"response"/"result").attr("code").to_i
      
      if result_code == 1500
        puts "** EPP - Successfully logged out." if @debug_log
        return true
      else
        raise EppErrorResponse.new(:xml => response, :code => result_code, :message => result_message)
      end
    end
    
    def new_epp_request
      xml = Document.new
      xml << XMLDecl.new("1.0", "UTF-8", "no")
      
      xml.add_element("epp", {
        "xmlns" => "urn:ietf:params:xml:ns:epp-1.0",
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:schemaLocation" => "urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"
      })
      
      return xml
    end
    
    # Wrapper which sends an XML frame to the server, and receives 
    # the response frame in return.
    def send_request(xml)
      send_frame(xml)
      get_frame
    end
    
    # Establishes the connection to the server. If the connection is
		# established, then this method will call get_frame and return 
		# the EPP <tt><greeting></tt> frame which is sent by the 
		# server upon connection.
    def open_connection
      @connection = TCPSocket.new(server, port)
      @socket     = OpenSSL::SSL::SSLSocket.new(@connection)
      
      # Synchronously close the connection & socket
      @socket.sync_close
      
      # Connect
      @socket.connect
      
      # Get the initial frame
      frame = get_frame
      
      if frame
        puts "EPP - Connection opened." if @debug_log
        return frame
      end
    end
    
    # Closes the connection to the EPP server.
    def close_connection
      if defined?(@socket) and @socket.is_a?(OpenSSL::SSL::SSLSocket)
        @socket.close
        @socket = nil
      end
      
      if defined?(@connection) and @connection.is_a?(TCPSocket)
        @connection.close
        @connection = nil
      end
      
      if @connection.nil? and @socket.nil?
        puts "EPP - Connection closed." if @debug_log
        return true
      end
    end
    
    # Receive an EPP frame from the server. Since the connection is blocking,
    # this method will wait until the connection becomes available for use. If
    # the connection is broken, a SocketError will be raised. Otherwise,
    # it will return a string containing the XML from the server.
    def get_frame
       if old_server
          data = ""
          first_char = @socket.read(1)
          
          if first_char.nil? and @socket.eof?
            raise SocketError.new("Connection closed by remote server")
          elsif first_char.nil?
            raise SocketError.new("Error reading frame from remote server")
          else
             data << first_char
             
             while char = @socket.read(1)
                data << char
                
                return data if data =~ %r|<\/epp>\n$|mi # at end
             end
          end
       else
          header = @socket.read(4)

          if header.nil? and @socket.eof?
            raise SocketError.new("Connection closed by remote server")
          elsif header.nil?
            raise SocketError.new("Error reading frame from remote server")
          else
            unpacked_header = header.unpack("N")
            length = unpacked_header[0]

            if length < 5
              raise SocketError.new("Got bad frame header length of #{length} bytes from the server")
            else
              response = @socket.read(length - 4)   
            end
          end
       end      
    end

    # Send an XML frame to the server. Should return the total byte
    # size of the frame sent to the server. If the socket returns EOF,
    # the connection has closed and a SocketError is raised.
    def send_frame(xml)
      @socket.write(old_server ? (xml + "\r\n") : ([xml.size + 4].pack("N") + xml))
    end
  end
end