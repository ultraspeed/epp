$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'rubygems'
require 'openssl'
require 'socket'
require 'activesupport'
require 'require_parameters'
require 'rexml/document'

require 'epp/server.rb'

module Epp #:nodoc:
  VERSION = '1.0.2'
end