__precompile__(true)
module Mirrors

include("types.jl")
const Mirror = Types.Mirror
export Mirror

include("utils.jl")
const current = Utils.current
export current

const MIRRORS = Dict{String, String}()

export PKG
include("pkg.jl")

include("api.jl")

const availables = API.availables
const setmirror = API.setmirror
const activate = API.activate
const deactivate = API.deactivate
const clear = API.clear
export availables, setmirror, activate, deactivate, clear

function __init__()
    open(joinpath(@__DIR__, "../data/mirror_list.txt")) do fi
        for line = readlines(fi)
            tmp = split(line, ' ')
            MIRRORS[tmp[1]] = tmp[2]
        end
    end
    API.activate(first=true)
    finalizer(Types.FINALIZER) do _
        current() === nothing || API.deactivate()
    end
end

end
