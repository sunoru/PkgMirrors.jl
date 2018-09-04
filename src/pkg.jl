module PKG

import Pkg
import JSON

import ..Utils: current, download_cache, cachefile

const CACHEDICT = Dict{String, Any}()

function getstatus(baseurl, update=false)
    status_file = cachefile("status.json")
    if update || !ispath(status_file)
        @info "Updating mirror information..."
        download_cache(joinpath(baseurl, "status.json"), "status.json")
    end
    status = open(status_file) do io
        JSON.parse(io)
    end
    return status
end

function activate()
    baseurl = current().url
    status = getstatus(baseurl, true)
    registry_names = keys(status["registries"]["registries"])
    original_dict = CACHEDICT["default_registries"] = copy(Pkg.Types.DEFAULT_REGISTRIES)
    for (x, _) in Pkg.Types.DEFAULT_REGISTRIES
        if x in registry_names
            Pkg.Types.DEFAULT_REGISTRIES[x] = joinpath(baseurl, "registries", "$(x).git")
        end
    end
    registries = Pkg.Types.registries()
    for registry in registries
        name = basename(registry)
        if name in registry_names
            git_config_file = joinpath(registry, ".git", "config")
            cfg = read(git_config_file, String)
            cfg = replace(cfg, original_dict[name] => Pkg.Types.DEFAULT_REGISTRIES[name])
            write(git_config_file, cfg)
        end
    end

    @eval function Pkg.Operations.get_archive_url_for_version(url::String, ref)
        if (m = match(r"https://github.com/(.*?)/(.*?).jl.git", url)) != nothing
            mirror = current()
            # TODO: include registry info.
            pkgname = m.captures[2]
            return "$(mirror.url)/packages/$pkgname/General/$pkgname-$ref.tar.gz"
        end
        return nothing
    end

end

function deactivate()
    baseurl = current().url
    status = getstatus(baseurl)
    registry_names = keys(status["registries"]["registries"])
    registries = Pkg.Types.registries()
    original_dict = CACHEDICT["default_registries"]
    for registry in registries
        name = basename(registry)
        if name in registry_names
            git_config_file = joinpath(registry, ".git", "config")
            cfg = read(git_config_file, String)
            cfg = replace(cfg, Pkg.Types.DEFAULT_REGISTRIES[name] => original_dict[name])
            write(git_config_file, cfg)
        end
    end
    for (x, y) in original_dict
        Pkg.Types.DEFAULT_REGISTRIES[x] = y
    end
    @eval function Pkg.Operations.get_archive_url_for_version(url::String, ref)
        if (m = match(r"https://github.com/(.*?)/(.*?).git", url)) != nothing
            return "https://api.github.com/repos/$(m.captures[1])/$(m.captures[2])/tarball/$(ref)"
        end
        return nothing
    end
end

end