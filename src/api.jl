module API

import PkgMirrors: MIRRORS
import ..Types: PkgMirror
import ..Utils: setcache, getcache, delcache, current, CURRENT
import ..PKG

availables() = collect(keys(MIRRORS))

function setmirror(name::AbstractString, url::AbstractString)
    CURRENT[] = PkgMirror(name, url)
    try
        PKG.activate()
    catch e
        CURRENT[] = nothing
        rethrow(e)
    end
    setcache("$name $url", "current.txt")
    @info "PkgMirror $name activated."
    return CURRENT[]
end

function setmirror(name::AbstractString)
    haskey(MIRRORS, name) || error("Please specify an url for unknown mirror.")
    setmirror(name, MIRRORS[name])
end

function activate(;first=true)
    if activated()
        @warn "Already activated."
        return
    end
    current_mirror = getcache("current.txt")
    if current_mirror !== nothing
        tmp = split(current_mirror, ' ')
        @info "Using saved mirror: $(tmp[1]) ($(tmp[2]))"
        mirror = setmirror(tmp[1], tmp[2])
        return mirror
    elseif first
        @error "Please use `setmirror` for the first time."
    end
    return nothing
end

function deactivate()
    current_mirror = current()
    if current_mirror === nothing
        @warn "No mirror activated."
    else
        PKG.deactivate()
        CURRENT[] = nothing
        @info "PkgMirror $(current_mirror.name) deactivated."
    end
end

function clear()
    activated() && deactivate()
    delcache("current.txt")
    delcache("registries.txt")
    @info "Cache clear."
end

function activated()
    current() !== nothing
end

end
