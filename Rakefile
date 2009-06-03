require 'rubygems'
require 'rake'
require 'rake/clean'
require 'fileutils'
require 'hoe'
require File.dirname(__FILE__) + '/lib/epp'

$hoe = Hoe.new('epp', Epp::VERSION) do |p|
  p.developer('Josh Delsman', 'jdelsman@ultraspeed.com')
  p.summary = "Basic functionality for connection and making requests on EPP (Extensible Provisioning Protocol) servers"
  p.description = p.summary
  p.url = "http://github.com/ultraspeed/epp"
  p.rubyforge_name = p.name
  p.clean_globs |= %w[**/.DS_Store tmp *.log]
  path = (p.rubyforge_name == p.name) ? p.rubyforge_name : "\#{p.rubyforge_name}/\#{p.name}"
  p.remote_rdoc_dir = File.join(path.gsub(/^#{p.rubyforge_name}\/?/,''), 'rdoc')
  p.rsync_args = '-av --delete --ignore-errors'
end

Dir['tasks/**/*.rake'].each { |t| load t }