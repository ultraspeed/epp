class EppErrorResponse < StandardError #:nodoc:
  attr_accessor :response
  
  # Generic EPP exception. Accepts a response code and a message
  def initialize(attributes = {})
    @response_code = attributes[:code]
    @message = attributes[:message]
  end
  
  def to_s
    "#{@message} (code #{@response_code})"
  end
end