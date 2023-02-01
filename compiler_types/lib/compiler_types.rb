# typed: true
require_relative "compiler_types/version"

module CompilerTypes
    class CoroutineObject

    end

    module Coroutine
        def create(f)
            CoroutineObject.new
        end
        def resume(co, *params); end
        def running; end
        def status(co); end
        def wrap(f); end
        def yield(*params); end
    end
end
