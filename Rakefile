require 'rubygems'
require 'rake'
require 'rake/clean'
require 'hanna/rdoctask'
require 'fileutils'

require File.dirname(__FILE__) + '/lib/epp'

Dir['tasks/**/*.rake'].each { |t| load t }

# Rdoc
Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
end