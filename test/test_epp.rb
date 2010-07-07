require 'test_helper'

class EppTest < Test::Unit::TestCase
  context "EPP" do
    context "server" do
      setup do
        @epp = Epp::Server.new(
          :server => "test-epp.nominet.org.uk",
          :tag => "TEST",
          :password => "test"
        )
        
        @tcp_sock = mock('TCPSocket')
        @ssl_sock = mock('OpenSSL::SSL::SSLSocket')
      end
      
      should "verify class name is Epp::Server" do
        assert @epp.is_a?(Epp::Server)
      end
      
      should "require server, tag and password attributes" do
        assert_raises ArgumentError do
          epp = Epp::Server.new(:tag => "a", :password => "a")
        end
        
        assert_raises ArgumentError do
          epp = Epp::Server.new(:server => "a", :password => "a")
        end
        
        assert_raises ArgumentError do
          epp = Epp::Server.new(:server => "a", :tag => "a")
        end
        
        assert_nothing_raised do
          epp = Epp::Server.new(:server => "a", :tag => "a", :password => "a")
        end
      end
      
      should "set instance variables for attributes" do
        epp = Epp::Server.new(
          :tag => "TAG",
          :password => "f00bar",
          :server => "nominet-epp.server.org.uk",
          :port => 8700,
          :lang => "es",
          :services => ["urn:ietf:params:xml:ns:domain-nom-ext-1.1.xsd"],
          :extensions => ["domain-nom-ext-1.1.xsd"],
          :version => "90.0"
        )
        
        assert_equal "TAG", epp.tag
        assert_equal "f00bar", epp.password
        assert_equal "nominet-epp.server.org.uk", epp.server
        assert_equal 8700, epp.port
        assert_equal "es", epp.lang
        assert_equal ["urn:ietf:params:xml:ns:domain-nom-ext-1.1.xsd"], epp.services
        assert_equal ["domain-nom-ext-1.1.xsd"], epp.extensions
        assert_equal "90.0", epp.version
      end
      
      should "build a new XML request" do
        xml = xml_file("new_request.xml")
        
        assert @epp.new_epp_request.is_a?(REXML::Document)
        assert_equal xml, @epp.new_epp_request.to_s
      end
      
      should "open connection and receive a greeting" do
        prepare_socket!
        
        assert @epp.open_connection
      end
      
      should "return true if connection closed" do
        prepare_socket!
        
        @epp.open_connection
        
        @tcp_sock.stubs(:close).returns(nil)
        @ssl_sock.stubs(:close).returns(nil)
        @tcp_sock.stubs(:closed?).returns(true)
        @ssl_sock.stubs(:closed?).returns(true)
        
        assert @epp.close_connection
      end
      
      should "get frame from new EPP servers with a header of four bytes" do
        prepare_socket!
        
        @epp.open_connection
      
        response = xml_file("test_response.xml")
        
        @ssl_sock.expects(:read).with(4).returns("\000\000\003\"")
        @ssl_sock.expects(:read).with(798).returns(response)
        
        assert response, @epp.get_frame
      end
      
      should "raise exception if socket closed unexpectedly while getting frame" do
        prepare_socket!
        simulate_close!
        
        @epp.open_connection
        @epp.close_connection
        
        assert_raises SocketError do
          @epp.get_frame
        end
      end
      
      should "raise exception if header cannot be read when getting frame" do
        prepare_socket!
        
        @epp.open_connection
        
        @ssl_sock.expects(:read).with(4).returns(nil)
        @ssl_sock.stubs(:eof?).returns(false)
        
        assert_raises SocketError do
          @epp.get_frame
        end
      end
      
      should "send frame to an EPP server" do
        prepare_socket!
        
        @epp.open_connection
        
        send = xml_file("test_request.xml")
        
        @ssl_sock.expects(:write).with(@epp.packed(send) + send).returns(121)
        
        assert_equal 121, @epp.send_frame(send)
      end
      
      should "create a packed header for EPP request" do
        xml_to_send = "<xml><test/></xml>"
        assert_equal "\000\000\000\026", @epp.packed(xml_to_send)
      end
      
      should "return size of header from EPP response" do
        assert_equal [22], "\000\000\000\026".unpack("N")
        assert_equal 22, @epp.header_size("\000\000\000\026")
      end
      
      should "send frame, and get response from server" do
        prepare_socket!
        
        @epp.open_connection
        
        send = xml_file("test_request.xml")
        receive = xml_file("test_response.xml")
        
        @ssl_sock.expects(:write).with(@epp.packed(send) + send).returns(121)
        @ssl_sock.expects(:read).with(4).returns("\000\000\003\"")
        @ssl_sock.expects(:read).with(798).returns(receive)
        
        assert receive, @epp.send_request(send)        
      end
      
      should "wrap a request around a logging in and logging out request" do
        prepare_socket!
        simulate_close!
        check_socket!
        
        test_request = xml_file("test_request.xml")
        test_response = xml_file("test_response.xml")
        
        @epp.expects(:login).returns(true)
        @epp.expects(:logout).returns(true)
        @epp.expects(:send_request).with(test_request).returns(test_response)
        
        @response = @epp.request(test_request)
        
        assert_equal test_response, @response
      end
    end
    
    context "exceptions" do
      should "require XML, code and message attributes" do
        assert_raises ArgumentError do
          e = EppErrorResponse.new(:code => "a", :message => "a")
        end
        
        assert_raises ArgumentError do
          e = EppErrorResponse.new(:xml => "a", :message => "a")
        end
        
        assert_raises ArgumentError do
          e = EppErrorResponse.new(:xml => "a", :code => "a")
        end
        
        assert_nothing_raised do
          e = EppErrorResponse.new(:xml => "a", :code => "a", :message => "a")
        end
      end
      
      should "print error message to string" do
        e = EppErrorResponse.new(
          :xml => "<xml></xml>", 
          :code => 400, 
          :message => "Test error message"
        )
        
        assert_equal "Test error message (code 400)", e.to_s
      end
    end
  end
  
  private
  
  def prepare_socket!
    @response = xml_file("test_request.xml")
    
    TCPSocket.expects(:new).returns(@tcp_sock)
    OpenSSL::SSL::SSLSocket.expects(:new).returns(@ssl_sock)
    
    @ssl_sock.expects(:sync_close=).with(true)
    @ssl_sock.expects(:connect).returns(@ssl_sock)
    @ssl_sock.expects(:read).with(4).returns("\000\000\003\r")
    @ssl_sock.expects(:read).with(777).returns(@response)
    @ssl_sock.stubs(:eof?)
    
  end
  
  def check_socket!
    @ssl_sock.stubs(:closed?)
  end
  
  def simulate_close!
    @ssl_sock.stubs(:close).returns(nil)
    @tcp_sock.stubs(:close).returns(nil)
    @ssl_sock.stubs(:closed?).returns(true)
    @tcp_sock.stubs(:closed?).returns(true)
  end
  
  def xml_file(name)
    File.read(File.dirname(__FILE__) + "/xml/#{name}")
  end
end