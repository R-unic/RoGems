module Exceptions
	class NoInputDirError < Exception
        def initialize(searched)
            super("No input directory '#{searched}' found.")
        end
    end
    class NoOutputDirError < Exception
        def initialize(searched)
            super("No output directory '#{searched}' found.")
        end
    end
    class UnsupportedBitOpError < Exception
        def initialize(op)
            super("Unsupported bitwise operator: '#{op}'")
        end
    end
    class TranspileError < Exception
        def initialize(msg)
            super("Cannot run RoGems: #{msg}")
        end
    end
    class MissingConfigError < TranspileError
        def initialize
            super("Missing 'rogems.json' config file in directory")
        end
    end
end
