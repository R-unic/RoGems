require "benchmark"
require "CodeGenerator"

class Transpiler
  	def initialize(config)
    	cwd = File.join(Dir.pwd, config["rootDir"])
    	@input_dir = File.join(cwd, config["sourceDir"])
    	@output_dir = File.join(cwd, config["outDir"])
    	@config = config

    	if !Dir.exist?(@input_dir) then
      		raise Exceptions::NoInputDirError.new(@input_dir)
    	end
    	if !Dir.exist?(@output_dir) then
      		raise Exceptions::NoOutputDirError.new(@output_dir)
    	end
  	end

  	def transpile
		elapsed = Benchmark.realtime { transpile_dir(@input_dir) }
		puts "Compiled files successfully. (#{(elapsed * 1000).floor} ms)"
  	end

  	def transpile_dir(dir, output_subdir = "")
		Dir.foreach(dir) do |file_name|
		  next if file_name == '.' or file_name == '..'

		  input_path = File.join(dir, file_name)
		  if File.directory?(input_path)
			# output_subdir = File.join(output_subdir, file_name)
			output_path = File.join(@output_dir, output_subdir)
			Dir.mkdir(output_path) unless Dir.exist?(output_path)
			transpile_dir(input_path, File.join(output_subdir, file_name))
		  else
			output_file = File.join(@output_dir, output_subdir, file_name.gsub(/\.[^.]+$/, '.lua'))
			code_generator = CodeGenerator.new(@config, File.read(input_path))
			output_code = code_generator.generate
			File.write(output_file, output_code) #.gsub("", "").gsub("", "").gsub("", "")
		  end
		end
	  end

end
