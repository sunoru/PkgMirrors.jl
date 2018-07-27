metadata_url(mirror::Mirror=current()) = "$(mirror.url)/metadata/METADATA.jl"

function setcache(value, name::AbstractString...)
    filename = joinpath(CACHEPATH, name...)
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
    filename = joinpath(CACHEPATH, name...)
    isfile(filename) || return nothing
    value = ""
    open(filename) do fi
        value = readline(fi)
    end
    value
end

function delcache(name::AbstractString...)
    filename = joinpath(CACHEPATH, name...)
    isfile(filename) && Base.rm(filename)
end

hascache(name::AbstractString...) = isfile(joinpath(CACHEPATH, name...))
