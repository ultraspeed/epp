Gem::Specification.new do |s|
  s.name = "epp"
  s.version = "1.0.2"
  
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Josh Delsman"]
  s.date = %q{2009-06-04}
  s.description = %q{Basic functionality for connecting and making requests on EPP (Extensible Provisioning Protocol) servers.}
  s.email = %q{jdelsman@ultraspeed.com}
  s.files = ["lib/epp/server.rb", "lib/epp.rb", "lib/require_parameters.rb", "Rakefile", "README.rdoc", "test/test_epp.rb", "test/test_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/ultraspeed/epp}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{epp}
  s.rubygems_version = %q{1.3.2}
  s.summary = %q{Basic functionality for connecting and making requests on EPP (Extensible Provisioning Protocol) servers.}
  
  # Dependencies
  s.add_dependency("activesupport", ">= 2.3.2")
  s.add_dependency("hpricot", ">= 0.8.1")
end