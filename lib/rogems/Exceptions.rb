module RoGems
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

        class MissingGlobalConfig < InitError
            def initialize
                super("No rogems.config.yml found in RoGems installation directory.")
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
            def initialize(dir)
                super("Missing 'rogems.json' config file in '#{dir}'")
            end
        end
        class InvalidInitModeError  < InitError
            def initialize(mode, usage)
                super("Invalid init mode '#{mode}' provided.")
                puts usage
            end
        end
        class NotFoundError < InitError
            def initialize(cmd)
                super("#{cmd.capitalize} could not be found. Please make sure it is installed and discoverable (i.e. you can run '#{cmd.downcase} -v').")
            end
        end

        class UnsupportedBitOpError < TranspileError
            def initialize(op)
                super("Bitwise operators are not supported (yet).")
            end
        end
    end
end
