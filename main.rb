require "./Transpiler"

transpiler = Transpiler.new("./src", "./out")
transpiler.transpile
