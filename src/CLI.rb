require "json"
require "listen"
require "optparse"
require "fileutils"
require "open3"
require "Transpiler"

class CLI
	module InitMode
		NONE = 0
		GAME = 1
		GEM = 2
	end

    def get_config(base_dir = Dir.pwd)
        config_name = File.join(base_dir, "rogems.json")
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
				@transpiler.transpile
			end
			listener.start
		end

		@transpiler.transpile
        if @options[:watch] then sleep end
	end

    def init_project(init_mode = "game")
        validated = validate_init_mode(init_mode)
        init_command = get_init_cmd(validated)
        self.check_rojo_installed
        success = system(init_command)
        if !success then return end

        FileUtils.mv("src", "out") # rename
        Dir.glob("./out/**/*").filter { |f| File.file?(f) }.each { |f| File.delete(f) }
        FileUtils.cp_r("out/.", "src", :remove_destination => true) # copy dirs
        path = File.join(File.dirname(__FILE__), "default_rogems.json")
        default_rogems_json = File.read(path)
        File.open("rogems.json", "w") { |f| f.write(default_rogems_json) }

		@config = JSON.parse(default_rogems_json)
		@transpiler = Transpiler.new(@config)
        FileUtils.touch("./src/shared/helloWorld.rb") # create example files
        File.open("./src/shared/helloWorld.rb", "w") do |file|
            file.write("def helloWorld\n    puts \"hello world\"\nend")
        end
        FileUtils.touch("./src/client/main.client.rb")
        File.open("./src/client/main.client.rb", "w") do |file|
            file.write("require \"shared/helloWorld\"\n\nhelloWorld()")
        end
        @transpiler.transpile
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

	def check_rojo_installed
        rojo_installed = false
		begin
            stderr, stdout, status = Open3.capture3("rojo -v")
            rojo_installed = stderr.nil? || stderr == ""
        rescue Exception => e
            rojo_installed = false
        ensure
            raise Exceptions::RojoNotFoundError.new unless rojo_installed
        end
	end
end
