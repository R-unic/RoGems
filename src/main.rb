$:.unshift File.join(File.dirname(__FILE__))
require "json"
require "Transpiler"

file = File.read(File.join(Dir.pwd, "rogems.json"))
config = JSON.parse(file)

transpiler = Transpiler.new(config)
transpiler.transpile
