class EppErrorResponse < StandardError #:nodoc:
  attr_accessor :response_xml, :response_code, :message
  
  # Generic EPP exception. Accepts a response code and a message
  def initialize(attributes = {})
    @response_xml = attributes[:xml]
    @response_code = attributes[:code]
    @message = attributes[:message]
  end
  
  def to_s
    "#{@message} (code #{@response_code})"
  end
end