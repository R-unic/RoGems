require "CodeGenerator"
require "Exceptions"

class Transpiler
	def initialize(input_dir, output_dir)
		@input_dir = input_dir
		@output_dir = output_dir
		if !Dir.exist?(@input_dir) then
			raise Exceptions::NoInputDirError.new(@input_dir)
		end
		if !Dir.exist?(@output_dir) then
			raise Exceptions::NoOutputDirError.new(@output_dir)
		end
	end

	def transpile
		Dir.foreach(@input_dir) do |file_name|
			next if file_name == '.' or file_name == '..'

			input_file = File.join(@input_dir, file_name)
			output_file = File.join(@output_dir, file_name.gsub(/\.[^.]+$/, '.lua'))

			code_generator = CodeGenerator.new(File.read(input_file))
			output_code = code_generator.generate
			File.write(output_file, output_code.gsub("", ""))
		end
	end
end
