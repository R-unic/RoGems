module Exceptions
    class TranspileError < Exception
        def initialize(msg)
            super("Failed to transpile: #{msg}")
        end
    end
    class InitError < Exception
        def initialize(msg)
            super("Cannot run RoGems: #{msg}")
            self.set_backtrace([])
        end
    end
	class NoInputDirError < InitError
        def initialize(searched)
            super("No input directory '#{searched}' found.")
        end
    end
    class NoOutputDirError < InitError
        def initialize(searched)
            super("No output directory '#{searched}' found.")
        end
    end
    class MissingConfigError < InitError
        def initialize
            super("Missing 'rogems.json' config file in directory")
        end
    end
    class RojoNotFoundError < InitError
        def initialize
            super("Rojo could not be found. Please make sure it is installed and discoverable (i.e. you can run 'rojo -v').")
        end
    end
    class InvalidInitModeError  < InitError
        def initialize(mode, valids)
            super("Invalid init mode '#{mode}' provided. Valid modes include: #{valids.join(", ")}")
        end
    end
    class UnsupportedBitOpError < TranspileError
        def initialize(op)
            super("Unsupported bitwise operator: '#{op}'")
        end
    end

end
