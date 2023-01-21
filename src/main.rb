$:.unshift File.join(File.dirname(__FILE__))
require "json"
require "Transpiler"


file = File.read(File.join(File.join(File.dirname(__FILE__), ".."), "rogems.json"))
config = JSON.parse(file)
cwd = config["compilationDir"]
transpiler = Transpiler.new(File.join(cwd, "src"), File.join(cwd, "out"))
transpiler.transpile
