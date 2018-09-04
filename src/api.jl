module API

import Mirrors: Mirror, MIRRORS
import ..Utils: setcache, getcache, delcache, current, CURRENT
import ..PKG

availables() = collect(keys(MIRRORS))

function setmirror(name::AbstractString, url::AbstractString)
    CURRENT.x = Mirror(name, url)
    try
        PKG.activate()
    catch e
        CURRENT.x = nothing
        rethrow(e)
    end
    setcache("$name $url", "current.txt")
    @info "Mirror $name activated."
    return CURRENT.x
end

function setmirror(name::AbstractString)
    haskey(MIRRORS, name) || error("Please specify an url for unknown mirror.")
    setmirror(name, MIRRORS[name])
end

function activate(;first=false)
    if current() !== nothing
        @warn "Already activated"
        return
    end
    current_mirror = getcache("current.txt")
    if current_mirror !== nothing
        tmp = split(current_mirror, ' ')
        @info "Using saved mirror: $(tmp[1]) ($(tmp[2]))"
        setmirror(tmp[1], tmp[2])
    elseif !first
        @warn "Please use `setmirror`."
    end
end

function deactivate()
    current_mirror = current()
    if current_mirror === nothing
        @warn "No mirror activated"
    else
        PKG.deactivate()
        CURRENT.x = nothing
        @info "Mirror $(current_mirror.name) deactivated."
    end
end

function clear()
    current() === nothing || deactivate()
    delcache("current.txt")
    delcache("status.json")
    @info "Cache clear."
end

end