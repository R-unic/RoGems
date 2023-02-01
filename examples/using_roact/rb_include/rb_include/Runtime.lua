local Ruby = {}

function Ruby.list(t)
    local i = 0
    return function()
        i += 1
        if i <= #t then
            return t[i]
        end
    end
end

return Ruby
