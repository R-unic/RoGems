# typed: true

module CompilerTypes
    class CoroutineObject

    end

    module Coroutine
        extend T::Sig

        sig {params(f: T.proc.params(fparams: T::Array[T.untyped]).returns(T.untyped)).returns(CoroutineObject)}
        def create(f); end

        sig {params(co: CoroutineObject, params: T::Array[T.untyped]).void}
        def resume(co, *params); end

        def running; end
        def status(co); end
        def wrap(f); end
        def yield(*params); end
    end
end
