require 'openssl'
require 'socket'

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'require_parameters'
require 'epp/server.rb'

module Epp #:nodoc:
  VERSION = '1.0'
end