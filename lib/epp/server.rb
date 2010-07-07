module Epp #:nodoc:
  class Server
    include REXML
    include RequiresParameters
        
    attr_accessor :tag, :password, :server, :port, :services, :lang, :extensions, :version
    
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
      @lang       = attributes[:lang]       || "en"
      @services   = attributes[:services]   || ["urn:ietf:params:xml:ns:domain-1.0", "urn:ietf:params:xml:ns:contact-1.0", "urn:ietf:params:xml:ns:host-1.0"]
      @extensions = attributes[:extensions] || []
      @version    = attributes[:version]    || "1.0"
      
      @logged_in  = false
    end
    
    # Sends a standard login request to the EPP server.
    def login      
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
      
      extensions_container = services.add_element("svcExtension") unless extensions.empty?
      
      for uri in extensions
        extensions_container.add_element("extURI").text = uri
      end
      
      command.add_element("clTRID").text = "ABC-12345"

      response = Hpricot.XML(send_request(xml.to_s))

      result_message  = (response/"epp"/"response"/"result"/"msg").text.strip
      result_code     = (response/"epp"/"response"/"result").attr("code").to_i
   
      if result_code == 1000
        return true
      else
        raise EppErrorResponse.new(:xml => response, :code => result_code, :message => result_message)
      end
    end
    
    # Sends a standard logout request to the EPP server.
    def logout      
      xml = new_epp_request
      
      command = xml.root.add_element("command")
      login = command.add_element("logout")
      
      response = Hpricot.XML(send_request(xml.to_s))
      
      result_message  = (response/"epp"/"response"/"result"/"msg").text.strip
      result_code     = (response/"epp"/"response"/"result").attr("code").to_i
      
      if result_code == 1500
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
    
    def connection
      @connection ||= TCPSocket.new(server, port)
    end
    
    def socket
      @socket ||= OpenSSL::SSL::SSLSocket.new(connection) if connection
    end
    
    # Sends an XML request to the EPP server, and receives an XML response. 
    # <tt><login></tt> and <tt><logout></tt> requests are also wrapped
    # around the request, so we can close the socket immediately after
    # the request is made.
    def request(xml)
      open_connection
      
      @logged_in = true if login
      
      begin
        @response = send_request(xml)
      ensure
        if @logged_in
          @logged_in = false if logout
        end
        
        close_connection
      end
      
      return @response
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
      socket.sync_close
      socket.connect

      get_frame
    end
    
    # Closes the connection to the EPP server.
    def close_connection
      socket.close
      connection.close
      
      connection.closed? and socket.closed?
    end
    
    # Receive an EPP frame from the server. Since the connection is blocking,
    # this method will wait until the connection becomes available for use. If
    # the connection is broken, a SocketError will be raised. Otherwise,
    # it will return a string containing the XML from the server.
    def get_frame
      header = socket.read(4)
      
      raise SocketError.new("Connection closed by remote server") if header.nil? and socket.eof?
      raise SocketError.new("Error reading frame from remote server") if header.nil?
      
      length = header_size(header)
      
      raise SocketError.new("Got bad frame header length of #{length} bytes from the server") if length < 5
      
      response = socket.read(length - 4)
    end

    # Send an XML frame to the server. Should return the total byte
    # size of the frame sent to the server. If the socket returns EOF,
    # the connection has closed and a SocketError is raised.
    def send_frame(xml)
      socket.write(packed(xml) + xml)
    end
    
    # Pack the XML as a header for the EPP server.
    def packed(xml)
      [xml.size + 4].pack("N")
    end
    
    # Returns size of header of response from the EPP server.
    def header_size(header)
      unpacked_header = header.unpack("N")
      unpacked_header[0]
    end
  end
end