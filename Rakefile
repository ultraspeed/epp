require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  
  Jeweler::Tasks.new do |gem|
    gem.name = "epp"
    gem.summary = "EPP (Extensible Provisioning Protocol) for Ruby"
    gem.description = "Basic functionality for connecting and making requests on EPP (Extensible Provisioning Protocol) servers"
    gem.email = "jdelsman@ultraspeed.com"
    gem.homepage = "http://github.com/ultraspeed/epp"
    gem.authors = ["Josh Delsman"]
    
    # Dependencies
    gem.add_development_dependency "shoulda"
    gem.add_development_dependency "mocha"
    gem.add_dependency "hpricot"
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies
task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.options << '--fmt' << 'shtml'
  rdoc.template = 'direct'
  
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end