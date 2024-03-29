require "json"
require "listen"
require "optparse"
require "open3"
require "benchmark"
require "Transpiler"

module RoGems
    module CLI
        class InitCommand
            attr_reader :options

            def parse_options
                OptionParser.new do |opts|
                    opts.banner = @usage
                    opts.on("-m", "--mode [MODE]") { |init_mode| @options[:mode] = init_mode }
                end.parse!
            end

            def initialize(parent)
                @parent = parent
                @usage = "Usage: rogems init [options]"
                @options = {}
                self.parse_options

                check_installed("rojo")
                enumeration = validate_init_mode(@options[:mode] || "game")
                init_command = get_init_cmd(enumeration)
                success = system(init_command)
                return unless success

                default_rojo = File.read(path_from_lib("default_rojo.json")).gsub!("PROJECT_NAME", File.dirname("./"))
                File.open("default.project.json", "w") { |f| f.write(default_rojo) }

                default_rogems_json = File.read(path_from_lib("default_rogems.json"))
                File.open("rogems.json", "w") { |f| f.write(default_rogems_json) }

                FileUtils.mv("src", "out") # rename
                Dir.glob("./out/**/*").filter { |f| File.file?(f) }.each { |f| File.delete(f) } # get rid of all the default crap
                FileUtils.cp_r("out/.", "src", :remove_destination => true) # copy directories over

                FileUtils.mkdir("rb_include")
                FileUtils.cp_r(path_from_lib("rb_include"), "rb_include", :remove_destination => false)

                @config = JSON.parse(default_rogems_json)
                @parent.transpiler = Transpiler.new(@config)
                FileUtils.touch("./src/shared/helloWorld.rb") # create example files
                File.open("./src/shared/helloWorld.rb", "w") do |f|
                    f.write("def helloWorld\n    puts \"hello world\"\nend")
                end
                FileUtils.touch("./src/client/main.client.rb")
                File.open("./src/client/main.client.rb", "w") do |f|
                    f.write("require \"shared/helloWorld\"\n\nhelloWorld()")
                end
                @parent.run_transpiler
            end

            def path_from_lib(path)
                File.join(File.dirname(__FILE__), path)
            end

            def validate_init_mode(mode = "game")
                case mode.downcase
                when "none"
                    CLI::InitMode::NONE
                when "game"
                    CLI::InitMode::GAME
                when "gem"
                    CLI::InitMode::GEM
                else
                    raise Exceptions::InvalidInitModeError.new(mode, @usage)
                end
            end

            def get_init_cmd(init_mode)
                case init_mode
                when CLI::InitMode::NONE, CLI::InitMode::GEM
                    "rojo init"
                when CLI::InitMode::GAME
                    "rojo init --kind place"
                end
            end

            def is_installed?(cmd)
                installed = false
                begin
                    stderr, stdout, status = Open3.capture3("#{cmd} -v")
                    installed = stderr.nil? || stderr == "" || status.success?
                rescue Exception => e
                    installed = false
                end
                installed
            end

            def check_installed(cmd)
                installed = is_installed?(cmd)
                raise Exceptions::NotFoundError.new(cmd) unless installed
            end
        end

        module InitMode
            NONE = 0
            GAME = 1
            GEM = 2
        end

        class MainCommand
            attr_reader :options
            attr_accessor :transpiler

            def parse_options
                OptionParser.new do |opts|
                    opts.banner = @usage
                    opts.on("-t", "--test", "Run RSpec for RoGems.") do
                        @options[:testing] = true
                        if @options[:verbose] then
                            puts "Running unit tests"
                        end
                        system("rspec --format doc")
                    end
                    opts.on("-w", "--watch", "Watch for changes in directory.") { |watch| @options[:watch] = watch }
                    opts.on("-v", "--verbose", "Be verbose and print extra messages to the console.") { |verbose| @options[:verbose] = verbose }
                    opts.on("--noTs", "Compile without running rbxtsc.") { |no_ts| @options[:no_ts] = no_ts }
                    opts.order!(ARGV) do |arg|
                        sub_command = arg
                        options[:sub_command] = sub_command
                    end
                end.parse!
            end

            def initialize
                @usage = "Usage: rogems [options] [SUBCOMMAND? | DIRECTORY?]"
                @options = {}
                self.parse_options

                case @options[:sub_command]
                when "init"
                    @options[:init] = true
                    CLI::InitCommand.new(self)
                else
                    @options[:dir] = @options[:sub_command]
                end

                if @options[:init] || @options[:testing] then return end
                @config = get_config(@options[:dir])
                @transpiler = Transpiler.new(@config, @options[:dir])
                if @options[:watch]
                    puts "=== Compiling in watch mode ==="
                    listener = Listen.to(@config["sourceDir"]) do
                        puts "Detected file change, compiling..."
                        self.run_transpiler
                    end
                    listener.start
                end

                self.run_transpiler
                if @options[:watch] then sleep end
            end

            def get_config(base_dir = nil)
                config_name = File.join(base_dir || Dir.pwd, "rogems.json")
                if !File.exist?(config_name)
                    raise Exceptions::MissingConfigError.new(base_dir || Dir.pwd)
                end

                file = File.read(config_name)
                if @options[:verbose] then
                    puts "Found rogems.json config at '#{config_name}'"
                end
                JSON.parse(file)
            end

            def run_transpiler
                elapsed = Benchmark.realtime do
                    project_dir = @options[:sub_command]
                    system("rbxtsc --project #{project_dir} --includePath #{File.join(project_dir, "ts_include")}") unless @options[:no_ts] || ROGEMS_CONFIG["UseTypeScript"] == false
                    @transpiler.transpile
                end
                if @options[:verbose] then
                    puts "Deleting excess files from rbxtsc"
                end
                Dir.glob("./out/**/*.rb").filter { |f| File.file?(f) }.each { |f| File.delete(f) }
                puts "Compiled files successfully. (#{(elapsed < 1 ? elapsed * 1000 : elapsed).floor}#{elapsed < 1 ? "ms" : "s"})"
            end
        end
    end
end
