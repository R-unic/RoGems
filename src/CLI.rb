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

	def initialize
		@options = {}
		OptionParser.new do |opts|
			opts.banner = "Usage: rogems [options]"
			opts.on("-w", "--watch", "Watch for changes in directory") { |watch| @options[:watch] = watch }
			opts.on("--init=INIT_MODE", "Create a new Rojo project and necessary configuration files. INIT_MODE can be 'none', 'game', or 'gem'") do |init_mode|				# Create a new Rojo project
				@options[:init] = true
                validated = validate_init_mode(init_mode == "" || init_mode.nil?  ? "game" : init_mode)
				init_command = get_init_cmd(validated)
				self.check_rojo_installed
				success = system(init_command)
                if !success then return end

				# Rename the created "src" directory to "out"
				FileUtils.mv("src", "out")
				# Create a new "src" directory
				FileUtils.mkdir("src")
				# Create a new "rogems.json" file
                path = File.join(File.dirname(__FILE__), "default_rogems.json")
                default_rogems_json = File.read(path)
				File.open("rogems.json", "w") { |f| f.write(default_rogems_json) }
			end
		end.parse!

        if @options[:init] then return end
		config_name = File.join(Dir.pwd, "rogems.json")
		if !File.exist?(config_name) then
			raise Exceptions::MissingConfigError.new
		end

		file = File.read(config_name)

		@config = JSON.parse(file)
		@transpiler = Transpiler.new(@config)

		if @options[:watch]
			puts "== Compiling in watch mode =="
			listener = Listen.to(@config["sourceDir"]) do
				puts "Detected file change, compiling..."
				@transpiler.transpile
			end
			listener.start
			sleep
		end
		@transpiler.transpile
	end

	def validate_init_mode(mode = "game")
		valids = ["none", "game", "gem"]
		if !valids.include?(mode)
			raise Exceptions::InvalidInitModeError.new(mode, valids)
		end
		case mode
		when "none"
			InitMode::NONE
		when "game"
			InitMode::GAME
		when "gem"
			InitMode::GEM
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
		stderr, stdout, status = Open3.capture3("rojo -v")
		rojo_installed = stderr.nil? || stderr == ""
		raise Exceptions::RojoNotFoundError.new unless rojo_installed
	end
end
