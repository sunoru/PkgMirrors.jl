module Utils

import ..Types: Mirror

const CURRENT = Ref{Union{Mirror, Nothing}}(nothing)

current() = CURRENT[]

const CACHEPATH = joinpath(@__DIR__, "../cache")

cachefile(name::AbstractString...) = joinpath(CACHEPATH, name...)

function setcache(value, name::AbstractString...)
    filename = cachefile(name...)
    path = dirname(filename)
    isdir(path) || mkpath(path)
    try
        open(filename, "w") do fo
            println(fo, value)
        end
    catch
        return false
    end
    true
end

function getcache(name::AbstractString...)
    filename = cachefile(name...)
    isfile(filename) || return nothing
    value = ""
    open(filename) do fi
        value = readline(fi)
    end
    value
end

function delcache(name::AbstractString...)
    filename = cachefile(name...)
    isfile(filename) && Base.rm(filename)
end

hascache(name::AbstractString...) = isfile(cachefile(name...))

function download_cache(url::AbstractString, localfile::AbstractString)
    download(url, cachefile(localfile))
end

function __init__()
    isdir(CACHEPATH) || mkdir(CACHEPATH)
end

end