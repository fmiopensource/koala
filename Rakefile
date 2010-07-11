require "spec/rake/spectask"

task :default => :spec
task :test => :spec

Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_opts = ['--options', "\"spec/spec.opts\""]
  t.spec_files = FileList['spec/**/*_spec.rb']
end

# desc 'Default task: run all tests'
# task :default => [:test]
# 
# task :test do
#   exec "thor monk:test"
# end
