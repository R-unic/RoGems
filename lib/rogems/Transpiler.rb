require "fileutils"
require "CodeGenerator"

module RoGems
    class Transpiler
        def initialize(config, base_dir = nil)
            cwd = File.join(base_dir || Dir.pwd, config["rootDir"])
            @input_dir = File.join(cwd, config["sourceDir"])
            @output_dir = File.join(cwd, config["outDir"])
            @config = config

            raise Exceptions::NoInputDirError.new(@input_dir) unless Dir.exist?(@input_dir)
            raise Exceptions::NoOutputDirError.new(@output_dir) unless Dir.exist?(@output_dir)
        end

        def transpile
            transpile_dir(@input_dir)
        end

        def transpile_dir(dir, output_subdir = "")
            Dir.foreach(dir) do |file_name|
                next if file_name == "." or file_name == ".."
                input_path = File.join(dir, file_name)

                if File.directory?(input_path)
                    output_path = File.join(@output_dir, output_subdir)
                    Dir.mkdir(output_path) unless Dir.exist?(output_path)
                    transpile_dir(input_path, File.join(output_subdir, file_name))
                else
                    next if !input_path.end_with?(".rb")
                    output_path = File.join(@output_dir.gsub("./", "").gsub(".\\", ""), output_subdir, file_name.gsub(/\.[^.]+$/, ".lua"))
                    code_generator = CodeGenerator.new(@config, File.read(input_path))
                    output_code = code_generator.generate
                    unless File.exist?(output_path)
                        o = File.new(output_path, "w")
                        o.write(output_code)
                    end
                    File.write(output_path, output_code)
                end
            end
        end
    end
end
