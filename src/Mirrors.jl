__precompile__(true)
module Mirrors

export Mirror
include("types.jl")

export availables, current, setmirror
include("api.jl")

include("utils.jl")

export Pkg2, Pkg3
const ISPKG3 = VERSION >= v"0.7"
include(joinpath(ISPKG3 ? "Pkg3" : "Pkg2", "pkg.jl"))

export PKG
const PKG = ISPKG3 ? Pkg3 : Pkg2
const MIRRORS = Dict{String, String}()
const CURRENT = Ref{Mirror}()
const BUILDPATH = joinpath(@__DIR__, "../build")
const CACHEFILE = joinpath(BUILDPATH, "current.txt")


function __init__()
    open(joinpath(@__DIR__, "../data/mirror_list.txt")) do fi
        for line = readlines(fi)
            tmp = split(line, ' ')
            MIRRORS[tmp[1]] = tmp[2]
        end
    end
    isdir(BUILDPATH) || mkdir(BUILDPATH)
    isfile(CACHEFILE) && open(CACHEFILE) do fi
        tmp = split(readline(fi), ' ')
        setmirror(tmp[1], tmp[2])
    end
end

end
