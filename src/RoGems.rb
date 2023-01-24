$:.unshift File.join(File.dirname(__FILE__))
require "json"
require "Exceptions"
require "Transpiler"

config_name = File.join(Dir.pwd, "rogems.json")
if !File.exist?(config_name) then
	raise Exceptions::MissingConfigError.new
end

file = File.read(config_name)
config = JSON.parse(file)

transpiler = Transpiler.new(config)
transpiler.transpile
