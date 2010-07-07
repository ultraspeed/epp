class EppErrorResponse < StandardError #:nodoc:
  include RequiresParameters
  
  attr_accessor :response_xml, :response_code, :message
  
  # Generic EPP exception. Accepts a response code and a message
  def initialize(attributes = {})
    requires!(attributes, :xml, :code, :message)
    
    @response_xml   = attributes[:xml]
    @response_code  = attributes[:code]
    @message        = attributes[:message]
  end
  
  def to_s
    "#{@message} (code #{@response_code})"
  end
end