require "json"
require "listen"
require "optparse"
require "open3"
require "benchmark"
require "Transpiler"

module RoGems
    class CLI
        module InitMode
            NONE = 0
            GAME = 1
            GEM = 2
        end

        def get_config(base_dir = nil)
            config_name = File.join(base_dir || Dir.pwd, "rogems.json")
            if !File.exist?(config_name) then
                raise Exceptions::MissingConfigError.new(base_dir)
            end

            file = File.read(config_name)
            JSON.parse(file)
        end

        def initialize
            @usage = "Usage: rogems [options] [DIRECTORY?]"
            @options = {}
            OptionParser.new do |opts|
                opts.banner = @usage
                opts.on("-t", "--test", "Run RSpec for RoGems.") do
                    @options[:testing] = true
                    system("rspec --format doc")
                end
                opts.on("-w", "--watch", "Watch for changes in directory.") { |watch| @options[:watch] = watch }
                opts.on("--init=INIT_MODE", "Create a new Rojo project and necessary configuration files. INIT_MODE can be \"none\", \"game\", or \"gem\"") do |init_mode|				# Create a new Rojo project
                    @options[:init] = true
                    init_project(init_mode)
                end
            end.parse!

            if @options[:init] || @options[:testing] then return end
            @options[:dir] = ARGV[0]
            @config = get_config(@options[:dir])
            @transpiler = Transpiler.new(@config, @options[:dir])

            if @options[:watch]
                puts "=== Compiling in watch mode ==="
                listener = Listen.to(@config["sourceDir"]) do
                    puts "Detected file change, compiling..."
                    self.run
                end
                listener.start
            end

            self.run
            if @options[:watch] then sleep end
        end

        def run
            elapsed = Benchmark.realtime do
                system("rbxtsc --includePath ts_include")
                @transpiler.transpile
            end
            Dir.glob("./out/**/*.rb").filter { |f| File.file?(f) }.each { |f| File.delete(f) }
            puts "Compiled files successfully. (#{(elapsed).floor}s)"
        end

        def path_from_lib(path)
            File.join(File.dirname(__FILE__), path)
        end

        def init_project(init_mode = "game")
            check_installed("rojo")
            check_installed("npm")
            unless is_installed?("rbxtsc")
                success = system("npm i --quiet -g roblox-ts")
                raise Exceptions::FailToInstallRobloxTS.new unless success
            end

            validated = validate_init_mode(init_mode)
            init_command = get_init_cmd(validated)
            success = system(init_command)
            return unless success

            default_rojo = File.read(path_from_lib("default_rojo.json")).gsub!("PROJECT_NAME", File.dirname("./"))
            File.open("default.project.json", "w") { |f| f.write(default_rojo) }

            FileUtils.touch("tsconfig.json")
            default_tsconfig = File.read(path_from_lib("default_tsconfig.json"))
            File.open("tsconfig.json", "w") { |f| f.write(default_tsconfig) }

            default_rogems_json = File.read(path_from_lib("default_rogems.json"))
            File.open("rogems.json", "w") { |f| f.write(default_rogems_json) }

            ran_npm = system("npm i --quiet @rbxts/compiler-types @rbxts/types @rbxts/roact @rbxts/services typescript")
            return unless ran_npm

            FileUtils.mv("src", "out") # rename
            Dir.glob("./out/**/*").filter { |f| File.file?(f) }.each { |f| File.delete(f) } # get rid of all the default crap
            FileUtils.cp_r("out/.", "src", :remove_destination => true) # copy directories over

            FileUtils.mkdir("ts_include")
            FileUtils.mkdir("rb_include")
            FileUtils.cp_r(path_from_lib("rb_include"), "rb_include", :remove_destination => false)

            @config = JSON.parse(default_rogems_json)
            @transpiler = Transpiler.new(@config)
            FileUtils.touch("./src/shared/helloWorld.rb") # create example files
            File.open("./src/shared/helloWorld.rb", "w") do |f|
                f.write("def helloWorld\n    puts \"hello world\"\nend")
            end
            FileUtils.touch("./src/client/main.client.rb")
            File.open("./src/client/main.client.rb", "w") do |f|
                f.write("require \"shared/helloWorld\"\n\nhelloWorld()")
            end
            self.run
        end

        def validate_init_mode(mode = "game")
            case mode.downcase
            when "none"
                InitMode::NONE
            when "game"
                InitMode::GAME
            when "gem"
                InitMode::GEM
            else
                raise Exceptions::InvalidInitModeError.new(mode, @usage)
            end
        end

        def get_init_cmd(init_mode)
            case init_mode
            when InitMode::NONE, InitMode::GEM
                "rojo init"
            when InitMode::GAME
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
end
