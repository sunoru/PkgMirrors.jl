__precompile__(true)
module PkgMirrors

include("types.jl")
const PkgMirror = Types.PkgMirror
export PkgMirror

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
const activated = API.activated
export availables, setmirror, activate, deactivate, clear, activated

function __init__()
    open(joinpath(@__DIR__, "../data/mirror_list.txt")) do fi
        for line = readlines(fi)
            tmp = split(line, ' ')
            MIRRORS[tmp[1]] = tmp[2]
        end
    end
    API.activate(first=false)
    finalizer(Types.FINALIZER) do _
        activated() && API.deactivate()
    end
end

end
