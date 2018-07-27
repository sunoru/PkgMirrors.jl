# This file is a part of Julia. License is MIT: https://julialang.org/license

module Read

import Base.LibGit2, ..Reqs, ...Pkg2.PkgError, ..Dir
import ...Mirrors
using ..Types

readstrip(path...) = strip(readstring(joinpath(path...)))

url(pkg::AbstractString) = readstrip(Dir.path("METADATA"), pkg, "url")
sha1(pkg::AbstractString, ver::VersionNumber) =
    readstrip(Dir.path("METADATA"), pkg, "versions", string(ver), "sha1")

function available(names=readdir("METADATA"))
    pkgs = Dict{String,Dict{VersionNumber,Available}}()
    for pkg in names
        isfile("METADATA", pkg, "url") || continue
        versdir = joinpath("METADATA", pkg, "versions")
        isdir(versdir) || continue
        for ver in readdir(versdir)
            ismatch(Base.VERSION_REGEX, ver) || continue
            isfile(versdir, ver, "sha1") || continue
            haskey(pkgs,pkg) || (pkgs[pkg] = Dict{VersionNumber,Available}())
            pkgs[pkg][convert(VersionNumber,ver)] = Available(
                readchomp(joinpath(versdir,ver,"sha1")),
                Reqs.parse(joinpath(versdir,ver,"requires"))
            )
        end
    end
    return pkgs
end
available(pkg::AbstractString) = get(available([pkg]),pkg,Dict{VersionNumber,Available}())

function latest(names=readdir("METADATA"))
    pkgs = Dict{String,Available}()
    for pkg in names
        isfile("METADATA", pkg, "url") || continue
        versdir = joinpath("METADATA", pkg, "versions")
        isdir(versdir) || continue
        pkgversions = VersionNumber[]
        for ver in readdir(versdir)
            ismatch(Base.VERSION_REGEX, ver) || continue
            isfile(versdir, ver, "sha1") || continue
            push!(pkgversions, convert(VersionNumber,ver))
        end
        isempty(pkgversions) && continue
        ver = string(maximum(pkgversions))
        pkgs[pkg] = Available(
                readchomp(joinpath(versdir,ver,"sha1")),
                Reqs.parse(joinpath(versdir,ver,"requires"))
            )
    end
    return pkgs
end

isinstalled(pkg::AbstractString) = pkg != "METADATA" && pkg != "REQUIRE" && Mirrors.hascache("versions", pkg)

function ispinned(pkg::AbstractString)
    cache = Mirrors.getcache("versions", pkg)
    cache === nothing && return false
    tmp = split(cache, ' ')
    return length(tmp) === 2 && tmp[2] == "pinned"
end

function installed_version(pkg::AbstractString)
    cache = Mirrors.getcache("versions", pkg)
    cache === nothing ? typemin(VersionNumber) : VersionNumber(split(cache, ' ')[1])
end

function requires_path(pkg::AbstractString)
    pkgreq = joinpath(pkg,"REQUIRE")
    return pkgreq
end

requires_list(pkg::AbstractString) =
    collect(keys(Reqs.parse(requires_path(pkg))))

requires_dict(pkg::AbstractString) =
    Reqs.parse(requires_path(pkg))

function installed()
    pkgs = Dict{String,Tuple{VersionNumber,Bool}}()
    for pkg in readdir(joinpath(Mirrors.CACHEPATH, "versions"))
        pkgs[pkg] = (installed_version(pkg), ispinned(pkg))
    end
    return pkgs
end

function fixed(inst::Dict=installed(), dont_update::Set{String}=Set{String}(),
    julia_version::VersionNumber=VERSION)
    pkgs = Dict{String,Fixed}()
    for (pkg,(ver,fix)) in inst
        (fix || pkg in dont_update) || continue
        pkgs[pkg] = Fixed(ver,requires_dict(pkg))
    end
    pkgs["julia"] = Fixed(julia_version)
    return pkgs
end

function free(inst::Dict=installed(), dont_update::Set{String}=Set{String}())
    pkgs = Dict{String,VersionNumber}()
    for (pkg,(ver,fix)) in inst
        (fix || pkg in dont_update) && continue
        pkgs[pkg] = ver
    end
    return pkgs
end

function issue_url(pkg::AbstractString)
    ispath(pkg,".git") || return ""
    m = match(LibGit2.GITHUB_REGEX, url(pkg))
    m === nothing && return ""
    return "https://github.com/" * m.captures[1] * "/issues"
end

end # module
