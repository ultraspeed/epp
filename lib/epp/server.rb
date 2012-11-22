module Epp #:nodoc:
  class Server
    include LibXML::XML
    include RequiresParameters
        
    attr_accessor :tag, :password, :server, :port, :lang, :services, :extensions, :version
    
    # ==== Required Attrbiutes
    # 
    # * <tt>:server</tt> - The EPP server to connect to
    # * <tt>:tag</tt> - The tag or username used with <tt><login></tt> requests.
    # * <tt>:password</tt> - The password used with <tt><login></tt> requests.
    # 
    # ==== Optional Attributes
    #
    # * <tt>:port</tt> - The EPP standard port is 700. However, you can choose a different port to use.
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

      @sslcert    = attributes[:sslcert]
      @sslkey     = attributes[:sslkey]
      if @sslcert then requires!(attributes, :sslkey) end
      if @sslkey then requires!(attributes, :sslcert) end
      
      @logged_in  = false
    end
    
    def new_epp_request
      xml = Document.new
      xml.root = Node.new("epp")
      
      xml.root["xmlns"] = "urn:ietf:params:xml:ns:epp-1.0"
      xml.root["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
      xml.root["xsi:schemaLocation"] = "urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"
      
      return xml
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
        @logged_in = false if @logged_in && logout
                
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
      @connection = TCPSocket.new(server, port)
      if @sslcert and @sslkey then
          sslcontext = OpenSSL::SSL::SSLContext.new
          sslcontext.cert = OpenSSL::X509::Certificate.new( File.open( @sslcert ) );
          sslcontext.key = OpenSSL::PKey::RSA.new( File.open( @sslkey ) );
          @socket = OpenSSL::SSL::SSLSocket.new(@connection,sslcontext) if @connection
      else
        @socket = OpenSSL::SSL::SSLSocket.new(@connection) if @connection
      end
      
      @socket.sync_close = true
      @socket.connect

      get_frame
    end
    
    # Closes the connection to the EPP server.
    def close_connection
      @socket.close     if @socket and not @socket.closed?
      @connection.close if @connection and not @connection.closed?
      
      @socket = @connection = nil

      return true
    end
    
    # Receive an EPP frame from the server. Since the connection is blocking,
    # this method will wait until the connection becomes available for use. If
    # the connection is broken, a SocketError will be raised. Otherwise,
    # it will return a string containing the XML from the server.
    def get_frame
      raise SocketError.new("Connection closed by remote server") if !@socket or @socket.eof?

      header = @socket.read(4)
    
      raise SocketError.new("Error reading frame from remote server") if header.nil?
    
      length = header_size(header)
    
      raise SocketError.new("Got bad frame header length of #{length} bytes from the server") if length < 5
    
      return @socket.read(length - 4)
    end

    # Send an XML frame to the server. Should return the total byte
    # size of the frame sent to the server. If the socket returns EOF,
    # the connection has closed and a SocketError is raised.
    def send_frame(xml)
      @socket.write(packed(xml) + xml)
    end
    
    # Pack the XML as a header for the EPP server.
    def packed(xml)
      [xml.size + 4].pack("N")
    end
    
    # Returns size of header of response from the EPP server.
    def header_size(header)
      header.unpack("N").first
    end
    
    private 
    
    # Sends a standard login request to the EPP server.
    def login
      raise SocketError, "Socket must be opened before logging in" if !@socket or @socket.closed?
      
      xml = new_epp_request
      
      xml.root << command = Node.new("command")
      command << login = Node.new("login")
      
      login << Node.new("clID", tag)
      login << Node.new("pw", password)
      
      login << options = Node.new("options")
      
      options << Node.new("version", version)
      options << Node.new("lang", lang)
      
      login << services = Node.new("svcs")
      
      services << Node.new("objURI", "urn:ietf:params:xml:ns:domain-1.0")
      services << Node.new("objURI", "urn:ietf:params:xml:ns:contact-1.0")
      services << Node.new("objURI", "urn:ietf:params:xml:ns:host-1.0")
      
      services << extensions_container = Node.new("svcExtension") unless extensions.empty?
      
      for uri in extensions
        extensions_container << Node.new("extURI", uri)
      end
      
      command << Node.new("clTRID", UUIDTools::UUID.timestamp_create.to_s)

      response = Hpricot::XML(send_request(xml.to_s))

      handle_response(response)
    end
    
    # Sends a standard logout request to the EPP server.
    def logout
      raise SocketError, "Socket must be opened before logging out" if !@socket or @socket.closed?
      
      xml = new_epp_request
      
      xml.root << command = Node.new("command")
      
      command << login = Node.new("logout")
      command << Node.new("clTRID", UUIDTools::UUID.timestamp_create.to_s)
      
      response = Hpricot::XML(send_request(xml.to_s))
      
      handle_response(response, 1500)
    end
    
    def handle_response(response, acceptable_response = 1000)
      result_code = (response/"epp"/"response"/"result").attr("code").to_i
      
      if result_code == acceptable_response
        return true
      else
        result_message  = (response/"epp"/"response"/"result"/"msg").text.strip
        
        raise EppErrorResponse.new(:xml => response, :code => result_code, :message => result_message)
      end
    end
  end
end
