# This file is a part of Julia. License is MIT: https://julialang.org/license

module Write

import ..Read, ..BinaryProvider, ...Pkg2.PkgError
import ...Mirrors

function get_archive_url_for_version(pkg, ver)
    mirror = Mirrors.current()
    return "$(mirror.url)/packages/$pkg/General/$pkg-$ver.tar.gz"
end

function prefetch(pkg::AbstractString, ver::VersionNumber)
    pkg == "julia" && return
    dir = joinpath(".cache", "$pkg-$ver")
    mkpath(dir)
    length(filter!(x -> x != "pax_global_header", readdir(dir))) == 1 && return
    if isdir(".trash/$pkg-$ver")
        mv(".trash/$pkg-$ver", joinpath(dir, "from_trash"))
        return
    end
    rm(dir; force=true, recursive=true)
    mkpath(dir)
    # Copied from Pkg3.
    archive_url = get_archive_url_for_version(pkg, ver)
    path = tempname() * randstring(6) * ".tar.gz"
    url_success = true
    cmd = BinaryProvider.gen_download_cmd(archive_url, path);
    try
        run(cmd, (DevNull, DevNull, DevNull))
    catch e
        e isa InterruptException && rethrow(e)
        warn("failed to download from $(archive_url)")
        println(STDERR, e)
        url_success = false
    end
    url_success || return false
    cmd = BinaryProvider.gen_unpack_cmd(path, dir);
    # Might fail to extract an archive (Pkg#190)
    try
        run(cmd, (DevNull, DevNull, DevNull))
    catch e
        e isa InterruptException && rethrow(e)
        warn("failed to extract archive downloaded from $(archive_url)")
        println(STDERR, e)
        url_success = false
    end
    url_success || return false
    Base.rm(path; force = true)
end

function fetch(pkg::AbstractString, ver::VersionNumber)
    pkg == "julia" && return
    dir = joinpath(".cache", "$pkg-$ver")
    dirs = readdir(dir)
    # 7z on Win might create this spurious file
    filter!(x -> x != "pax_global_header", dirs)
    @assert length(dirs) == 1
    mv(joinpath(dir, dirs[1]), "./$pkg")
    Mirrors.setcache(ver, "versions", pkg)
    return true
end

function install(pkg::AbstractString, ver::VersionNumber)
    prefetch(pkg, ver)
    fetch(pkg, ver)
end

function update(pkg::AbstractString, ver::VersionNumber)
    prefetch(pkg, ver)
    remove(pkg)
    fetch(pkg, ver)
end

function remove(pkg::AbstractString)
    pkg == "julia" && return
    isdir(".trash") || mkdir(".trash")
    ver = Read.installed_version(pkg)
    name = "$pkg-$ver"
    ispath(".trash/$name") && rm(".trash/$name", recursive=true)
    mv(pkg, ".trash/$name")
    Mirrors.delcache("versions", pkg)
end

end # module
