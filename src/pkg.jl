module PKG

import Pkg

import ..Utils: current, download_cache, cachefile, replace_in_file

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
    default_list = Pkg.Types.DEFAULT_REGISTRIES
    if typeof(default_list) <: Function
        default_list = default_list()
    end
    CACHEDICT["default_registries"] = deepcopy(default_list)
    for registry in default_list
        if registry.name in registry_list
            registry.url = joinpath(baseurl, "registries", "$(registry.name).git")
        end
    end
    for registry in Pkg.Types.collect_registries()
        git_config_file = joinpath(registry.path, ".git", "config")
        if registry.name in registry_list && isfile(git_config_file)
            i = findfirst(x -> x.name == registry.name, default_list)
            if i == nothing
                continue
            end
            replace_in_file(git_config_file, registry.url => default_list[i].url)
            toml_file = joinpath(registry.path, "Registry.toml")
            replace_in_file(toml_file, registry.url => default_list[i].url)
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
    registry_list = get_registry_list(baseurl, false)
    registries = Pkg.Types.collect_registries()
    original_list = CACHEDICT["default_registries"]
    for registry in registries
        if registry.name in registry_list
            i = findfirst(x -> x.name == registry.name, original_list)
            if i == nothing
                continue
            end
            git_config_file = joinpath(registry.path, ".git", "config")
            replace_in_file(git_config_file, registry.url => original_list[i].url)
            toml_file = joinpath(registry.path, "Registry.toml")
            replace_in_file(toml_file, registry.url => original_list[i].url)
        end
    end
    for (i, x) in enumerate(original_list)
        Pkg.Types.DEFAULT_REGISTRIES[i] = x
    end

    @eval function Pkg.Operations.get_archive_url_for_version(url::String, ref)
        if (m = match(r"https://github.com/(.*?)/(.*?).git", url)) != nothing
            return "https://api.github.com/repos/$(m.captures[1])/$(m.captures[2])/tarball/$(ref)"
        end
        return nothing
    end
end

end
