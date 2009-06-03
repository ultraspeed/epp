module Epp #:nodoc:
  class Server
    include RequiresParameters
    
    def initialize(attributes = {})
      requires!(attributes, :server, :port)

      @connection = TCPSocket.new(attributes[:server], attributes[:port])
      @socket     = OpenSSL::SSL::SSLSocket.new(@connection)
      
      # Initiate the connection to the server through the SSL socket
      @socket.connect
      
      # Receive the EPP <greeting> frame which is sent by the server
      # upon initial connection
      get_frame
    end

    # Sends an XML request to the EPP server, and receives an XML response
    def request(xml)
      send_frame(xml)
      get_frame
    end
    
    # Closes the connection to the EPP server. It should be noted
    # that the EPP specification indicates that clients should send
    # a <logout> command before ending the session, so it is recommended
    # that you do so.
    def close_connection
      @socket.close if defined?(@socket) && !@socket.closed?
      @connection.close if defined?(@connection) && !@connection.closed?
    end
    
    private
    
    # Receive an EPP frame from the server. Since the connection is blocking,
    # this method will wait until the connection becomes available for use. If
    # the connection is broken, a SocketError will be raised. Otherwise,
    # it will return a string containing the XML from the server.
    def get_frame
      header = @socket.read(4)

      if header.nil? and @socket.closed?
        raise SocketError.new("Connection closed by remote server")
      elsif header.nil?
        raise SocketError.new("Error reading frame from remote server")
      else
        unpacked_header = header.unpack("N")
        length = unpacked_header[0]

        if length < 5
          raise SocketError.new("Got bad frame header length of #{length} bytes from the server")
        else
          @socket.read(length - 4)
        end
      end
    end
    
    # Send an XML frame to the server. Should return the total byte
    # size of the frame sent to the server.
    def send_frame(xml)
      @socket.write([xml.length].pack("N") + xml)
    end
  end
end