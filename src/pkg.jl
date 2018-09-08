module PKG

import Pkg

import ..Utils: current, download_cache, cachefile

const CACHEDICT = Dict{String, Any}()

function get_registry_list(baseurl, update=false)
    registries_file = cachefile("registries.txt")
    if update || !ispath(registries_file)
        @info "Updating mirror information..."
        download_cache(joinpath(baseurl, "registries", "list.txt"), "registries.txt")
    end
    registries = open(registries_file) do io
        readlines(io)
    end
    return registries
end

function activate()
    baseurl = current().url
    registry_list = get_registry_list(baseurl, true)
    original_dict = CACHEDICT["default_registries"] = copy(Pkg.Types.DEFAULT_REGISTRIES)
    for (x, _) in Pkg.Types.DEFAULT_REGISTRIES
        if x in registry_list
            Pkg.Types.DEFAULT_REGISTRIES[x] = joinpath(baseurl, "registries", "$(x).git")
        end
    end
    registries = Pkg.Types.registries()
    for registry in registries
        name = basename(registry)
        git_config_file = joinpath(registry, ".git", "config")
        if name in registry_list && isfile(git_config_file)
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
    registry_list = get_registry_list(baseurl, true)
    registries = Pkg.Types.registries()
    original_dict = CACHEDICT["default_registries"]
    for registry in registries
        name = basename(registry)
        if name in registry_list
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