$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

# Gem and other dependencies
require 'rubygems'
require 'openssl'
require 'socket'
require 'activesupport'
require 'rexml/document'
require 'hpricot'

# Package files
require 'require_parameters.rb'
require 'epp/server.rb'
require 'epp/exceptions.rb'

module Epp #:nodoc:
  VERSION = '1.0.3'
end