import Mirrors: Mirror

availables() = collect(keys(MIRRORS))

current() = isdefined(CURRENT, :x) ? CURRENT.x : nothing

function setmirror(name::AbstractString, url::AbstractString)
    CURRENT.x = Mirror(name, url)
    setcache("$name $url", "current.txt")
    return CURRENT.x
end

function setmirror(name::AbstractString)
    haskey(MIRRORS, name) || error("Please specify an url for unknown mirror.")
    setmirror(name, MIRRORS[name])
end
