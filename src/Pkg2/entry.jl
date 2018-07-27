# This file is a part of Julia. License is MIT: https://julialang.org/license

module Entry

import Base: thispatch, nextpatch, nextminor, nextmajor, check_new_version
import ..Reqs, ..Read, ..Query, ..Resolve, ..Write, ..Dir
import Base.LibGit2
importall Base.LibGit2
import ...Pkg2.PkgError
using ..Types
import ...Mirrors

macro recover(ex)
    quote
        try $(esc(ex))
        catch err
            show(err)
            print('\n')
        end
    end
end

function edit(f::Function, pkg::AbstractString, args...)
    r = Reqs.read("REQUIRE")
    reqs = Reqs.parse(r)
    avail = Read.available()
    !haskey(avail,pkg) && !haskey(reqs,pkg) && return false
    rʹ = f(r,pkg,args...)
    rʹ == r && return false
    reqsʹ = Reqs.parse(rʹ)
    reqsʹ != reqs && resolve(reqsʹ,avail)
    Reqs.write("REQUIRE",rʹ)
    info("Package database updated")
    return true
end

function edit()
    editor = get(ENV,"VISUAL",get(ENV,"EDITOR",nothing))
    editor !== nothing ||
        throw(PkgError("set the EDITOR environment variable to an edit command"))
    editor = Base.shell_split(editor)
    reqs = Reqs.parse("REQUIRE")
    run(`$editor REQUIRE`)
    reqsʹ = Reqs.parse("REQUIRE")
    reqs == reqsʹ && return info("Nothing to be done")
    info("Computing changes...")
    resolve(reqsʹ)
end

function add(pkg::AbstractString, vers::VersionSet)
    outdated = :maybe
    @sync begin
        @async if !edit(Reqs.add,pkg,vers)
            ispath(pkg) || throw(PkgError("unknown package $pkg"))
            info("Package $pkg is already installed")
        end
        branch = Dir.getmetabranch()
        outdated = with(GitRepo, "METADATA") do repo
            if LibGit2.branch(repo) == branch
                if LibGit2.isdiff(repo, "origin/$branch")
                    outdated = :yes
                else
                    try
                        LibGit2.fetch(repo)
                        outdated = LibGit2.isdiff(repo, "origin/$branch") ? (:yes) : (:no)
                    end
                end
            else
                :no # user is doing something funky with METADATA
            end
        end
    end
    if outdated != :no
        is = outdated == :yes ? "is" : "might be"
        info("METADATA $is out-of-date — you may not have the latest version of $pkg")
        info("Use `Pkg2.update()` to get the latest versions of your packages")
    end
end
add(pkg::AbstractString, vers::VersionNumber...) = add(pkg,VersionSet(vers...))

function rm(pkg::AbstractString)
    edit(Reqs.rm,pkg) && return
    ispath(pkg) || return info("Package $pkg is not installed")
    Write.remove(pkg)
end

function available()
    all_avail = Read.available()
    avail = AbstractString[]
    for (pkg, vers) in all_avail
        any(x->Types.satisfies("julia", VERSION, x[2].requires), vers) && push!(avail, pkg)
    end
    sort!(avail, by=lowercase)
end

function available(pkg::AbstractString)
    avail = Read.available(pkg)
    if !isempty(avail) || Read.isinstalled(pkg)
        return sort!(collect(keys(avail)))
    end
    throw(PkgError("$pkg is not a package (not registered or installed)"))
end

function installed()
    pkgs = Dict{String,VersionNumber}()
    for (pkg,(ver,fix)) in Read.installed()
        pkgs[pkg] = ver
    end
    return pkgs
end

function installed(pkg::AbstractString)
    avail = Read.available(pkg)
    if Read.isinstalled(pkg)
        return Read.installed_version(pkg)
    end
    isempty(avail) && throw(PkgError("$pkg is not a package (not registered or installed)"))
    return nothing # registered but not installed
end

function status(io::IO; pkgname::AbstractString = "")
    mirror = Mirrors.current()
    println(io, "Mirror: $(mirror.name) ($(mirror.url))")
    showpkg(pkg) = isempty(pkgname) ? true : (pkg == pkgname)
    reqs = Reqs.parse("REQUIRE")
    instd = Read.installed()
    required = sort!(collect(keys(reqs)))
    if !isempty(required)
        showpkg("") && println(io, "$(length(required)) required packages:")
        for pkg in required
            if !haskey(instd, pkg)
                showpkg(pkg) && status(io,pkg,"not found")
            else
                ver,fix = pop!(instd,pkg)
                showpkg(pkg) && status(io,pkg,ver,fix)
            end
        end
    end
    additional = sort!(collect(keys(instd)))
    if !isempty(additional)
        showpkg("") && println(io, "$(length(additional)) additional packages:")
        for pkg in additional
            ver,fix = instd[pkg]
            showpkg(pkg) && status(io,pkg,ver,fix)
        end
    end
    if isempty(required) && isempty(additional)
        println(io, "No packages installed")
    end
end

status(io::IO, pkg::AbstractString) = status(io, pkgname = pkg)

function status(io::IO, pkg::AbstractString, ver::VersionNumber, fix::Bool)
    @printf io " - %-29s " pkg
    fix || return println(io,ver)
    @printf io "%-19s" ver
    if ispath(pkg,".git")
        prepo = GitRepo(pkg)
        try
            with(LibGit2.head(prepo)) do phead
                if LibGit2.isattached(prepo)
                    print(io, LibGit2.shortname(phead))
                else
                    print(io, string(LibGit2.GitHash(phead))[1:8])
                end
            end
            attrs = AbstractString[]
            isfile("METADATA",pkg,"url") || push!(attrs,"unregistered")
            LibGit2.isdirty(prepo) && push!(attrs,"dirty")
            isempty(attrs) || print(io, " (",join(attrs,", "),")")
        catch err
            print_with_color(Base.error_color(), io, " broken-repo (unregistered)")
        finally
            close(prepo)
        end
    elseif Mirrors.hascache("versions", pkg)
        print_with_color(Base.warn_color(), io, "non-repo (from Mirrors)")
    else
        print_with_color(Base.warn_color(), io, "non-repo (unregistered)")
    end
    println(io)
end

function status(io::IO, pkg::AbstractString, msg::AbstractString)
    @printf io " - %-29s %-19s\n" pkg msg
end

function url_and_pkg(url_or_pkg::AbstractString)
    if !(':' in url_or_pkg)
        # no colon, could be a package name
        url_file = joinpath("METADATA", url_or_pkg, "url")
        isfile(url_file) && return readchomp(url_file), url_or_pkg
    end
    # try to parse as URL or local path
    m = match(r"(?:^|[/\\])(\w+?)(?:\.jl)?(?:\.git)?$", url_or_pkg)
    m === nothing && throw(PkgError("can't determine package name from URL: $url_or_pkg"))
    return url_or_pkg, m.captures[1]
end

function unpin(pkg::AbstractString)
    cache = Mirrors.getcache("versions", pkg)
    cache === nothing && return false
    tmp = split(cache, ' ')
    Mirrors.setcache(tmp[1], "versions", pkg)
end

function free(pkg::AbstractString)
    unpin(pkg)
    resolve()
end

function free(pkgs)
    try
        for pkg in pkgs
            unpin(pkg)
        end
    finally
        resolve()
    end
end

function pin(pkg::AbstractString, head::AbstractString)
    cache = Mirrors.getcache("versions", pkg)
    if cache !== nothing
        isempty(head) || throw(PkgError("$pkg is a non-git repo so only current version can be pinned"))
        tmp = split(cache, ' ')
        Mirrors.setcache(join([tmp[1], "pinned"], ' '), "versions", pkg)
        return
    end
    nothing
end
pin(pkg::AbstractString) = pin(pkg, "")

function pin(pkg::AbstractString, ver::VersionNumber)
    ver == Read.installed_version(pkg) && return pin(pkg, "")
    throw(PkgError("Cannot pin other version numbers for a package from Mirrors."))
end

function update(branch::AbstractString, upkgs::Set{String})
    info("Updating METADATA...")
    with(GitRepo, "METADATA") do repo
        try
            with(LibGit2.head(repo)) do h
                if LibGit2.branch(h) != branch
                    if LibGit2.isdirty(repo)
                        throw(PkgError("METADATA is dirty and not on $branch, bailing"))
                    end
                    if !LibGit2.isattached(repo)
                        throw(PkgError("METADATA is detached not on $branch, bailing"))
                    end
                    LibGit2.fetch(repo)
                    LibGit2.checkout_head(repo)
                    LibGit2.branch!(repo, branch, track="refs/remotes/origin/$branch")
                    LibGit2.merge!(repo)
                end
            end

            LibGit2.fetch(repo)
            ff_succeeded = LibGit2.merge!(repo, fastforward=true)
            if !ff_succeeded
                LibGit2.rebase!(repo, "origin/$branch")
            end
        catch err
            cex = CapturedException(err, catch_backtrace())
            throw(PkgError("METADATA cannot be updated. Resolve problems manually in " *
                Pkg2.dir("METADATA") * ".", cex))
        end
    end
    deferred_errors = CompositeException()
    avail = Read.available()
    instd = Read.installed()
    reqs = Reqs.parse("REQUIRE")
    if !isempty(upkgs)
        for (pkg, (v,f)) in instd
            satisfies(pkg, v, reqs) || throw(PkgError("Package $pkg: current " *
                "package status does not satisfy the requirements, cannot do " *
                "a partial update; use `Pkg2.update()`"))
        end
    end
    dont_update = Query.partial_update_mask(instd, avail, upkgs)
    free = Read.free(instd,dont_update)
    fixeds = Read.fixed(instd,dont_update)
    for (pkg,fixed) in fixeds
        Read.ispinned(pkg) && continue 
        pkg in dont_update && continue
        try
            Write.update(pkg, fixed.version)
        catch err
            rethrow(err)
            push!(deferred_errors, err)
        end
    end
    info("Computing changes...")
    resolve(reqs, avail, instd, fixeds, free, upkgs)
    # Don't use instd here since it may have changed
    updatehook(sort!(collect(keys(installed()))))

    # Print deferred errors
    length(deferred_errors) > 0 && throw(PkgError("Update finished with errors.", deferred_errors))
    nothing
end


function resolve(
    reqs  :: Dict = Reqs.parse("REQUIRE"),
    avail :: Dict = Read.available(),
    instd :: Dict = Read.installed(),
    fixed :: Dict = Read.fixed(instd),
    have  :: Dict = Read.free(instd),
    upkgs :: Set{String} = Set{String}()
)
    bktrc = Query.init_resolve_backtrace(reqs, fixed)
    orig_reqs = deepcopy(reqs)
    Query.check_fixed(reqs, fixed, avail)
    Query.propagate_fixed!(reqs, bktrc, fixed)
    deps, conflicts = Query.dependencies(avail, fixed)

    for pkg in keys(reqs)
        if !haskey(deps,pkg)
            if "julia" in conflicts[pkg]
                throw(PkgError("$pkg can't be installed because it has no versions that support $VERSION " *
                   "of julia. You may need to update METADATA by running `Pkg2.update()`"))
            else
                sconflicts = join(conflicts[pkg], ", ", " and ")
                throw(PkgError("$pkg's requirements can't be satisfied because " *
                    "of the following fixed packages: $sconflicts"))
            end
        end
    end

    Query.check_requirements(reqs, deps, fixed)

    deps = Query.prune_dependencies(reqs, deps, bktrc)
    want = Resolve.resolve(reqs, deps)

    if !isempty(upkgs)
        orig_deps, _ = Query.dependencies(avail)
        Query.check_partial_updates(orig_reqs, orig_deps, want, fixed, upkgs)
    end

    # compare what is installed with what should be
    changes = Query.diff(have, want, avail, fixed)
    isempty(changes) && return info("No packages to install, update or remove")

    # try applying changes, roll back everything if anything fails
    changed = []
    imported = String[]
    try
        for (pkg,(ver1,ver2)) in changes
            if ver1 === nothing
                info("Installing $pkg v$ver2")
                Write.install(pkg, ver2)
            elseif ver2 === nothing
                info("Removing $pkg v$ver1")
                Write.remove(pkg)
            else
                up = ver1 <= ver2 ? "Up" : "Down"
                info("$(up)grading $pkg: v$ver1 => v$ver2")
                Write.update(pkg, ver2)
                pkgsym = Symbol(pkg)
                if Base.isbindingresolved(Main, pkgsym) && isa(getfield(Main, pkgsym), Module)
                    push!(imported, "- $pkg")
                end
            end
            push!(changed,(pkg,(ver1,ver2)))
        end
    catch err
        for (pkg,(ver1,ver2)) in reverse!(changed)
            if ver1 === nothing
                info("Rolling back install of $pkg")
                @recover Write.remove(pkg)
            elseif ver2 === nothing
                info("Rolling back deleted $pkg to v$ver1")
                @recover Write.install(pkg, ver1)
            else
                info("Rolling back $pkg from v$ver2 to v$ver1")
                @recover Write.update(pkg, ver1)
            end
        end
        rethrow(err)
    end
    if !isempty(imported)
        warn(join(["The following packages have been updated but were already imported:",
            imported..., "Restart Julia to use the updated versions."], "\n"))
    end
    # re/build all updated/installed packages
    build(map(x->x[1], filter(x -> x[2][2] !== nothing, changes)))
end

function warnbanner(msg...; label="[ WARNING ]", prefix="")
    cols = Base.displaysize(STDERR)[2]
    warn(prefix="", Base.cpad(label,cols,"="))
    println(STDERR)
    warn(prefix=prefix, msg...)
    println(STDERR)
    warn(prefix="", "="^cols)
end

function build(pkg::AbstractString, build_file::AbstractString, errfile::AbstractString)
    # To isolate the build from the running Julia process, we execute each build.jl file in
    # a separate process. Errors are serialized to errfile for later reporting.
    # TODO: serialize the same way the load cache does, not with strings
    LOAD_PATH = filter(x -> x isa AbstractString, Base.LOAD_PATH)
    code = """
        empty!(Base.LOAD_PATH)
        append!(Base.LOAD_PATH, $(repr(LOAD_PATH)))
        empty!(Base.LOAD_CACHE_PATH)
        append!(Base.LOAD_CACHE_PATH, $(repr(Base.LOAD_CACHE_PATH)))
        empty!(Base.DL_LOAD_PATH)
        append!(Base.DL_LOAD_PATH, $(repr(Base.DL_LOAD_PATH)))
        open("$(escape_string(errfile))", "a") do f
            pkg, build_file = "$pkg", "$(escape_string(build_file))"
            try
                info("Building \$pkg")
                cd(dirname(build_file)) do
                    evalfile(build_file)
                end
            catch err
                Base.Pkg2.Entry.warnbanner(err, label="[ ERROR: \$pkg ]")
                serialize(f, pkg)
                serialize(f, err)
            end
        end
    """
    cmd = ```
        $(Base.julia_cmd()) -O0
        --compilecache=$(Bool(Base.JLOptions().use_compilecache) ? "yes" : "no")
        --history-file=no
        --color=$(Base.have_color ? "yes" : "no")
        --eval $code
    ```

    success(pipeline(cmd, stdout=STDOUT, stderr=STDERR))
end

function build!(pkgs::Vector, seen::Set, errfile::AbstractString)
    for pkg in pkgs
        pkg == "julia" && continue
        pkg in seen ? continue : push!(seen,pkg)
        Read.isinstalled(pkg) || throw(PkgError("$pkg is not an installed package"))
        build!(Read.requires_list(pkg), seen, errfile)
        path = abspath(pkg,"deps","build.jl")
        isfile(path) || continue
        build(pkg, path, errfile) || error("Build process failed.")
    end
end

function build!(pkgs::Vector, errs::Dict, seen::Set=Set())
    errfile = tempname()
    touch(errfile)  # create empty file
    try
        build!(pkgs, seen, errfile)
        open(errfile, "r") do f
            while !eof(f)
                pkg = deserialize(f)
                err = deserialize(f)
                errs[pkg] = err
            end
        end
    finally
        isfile(errfile) && Base.rm(errfile)
    end
end

function build(pkgs::Vector)
    errs = Dict()
    build!(pkgs,errs)
    isempty(errs) && return
    println(STDERR)
    warnbanner(label="[ BUILD ERRORS ]", """
    WARNING: $(join(keys(errs),", "," and ")) had build errors.

     - packages with build errors remain installed in $(pwd())
     - build the package(s) and all dependencies with `Pkg2.build("$(join(keys(errs),"\", \""))")`
     - build a single package by running its `deps/build.jl` script
    """)
end
build() = build(sort!(collect(keys(installed()))))

function updatehook!(pkgs::Vector, errs::Dict, seen::Set=Set())
    for pkg in pkgs
        pkg in seen && continue
        updatehook!(Read.requires_list(pkg),errs,push!(seen,pkg))
        path = abspath(pkg,"deps","update.jl")
        isfile(path) || continue
        info("Running update script for $pkg")
        cd(dirname(path)) do
            try evalfile(path)
            catch err
                warnbanner(err, label="[ ERROR: $pkg ]")
                errs[pkg] = err
            end
        end
    end
end

function updatehook(pkgs::Vector)
    errs = Dict()
    updatehook!(pkgs,errs)
    isempty(errs) && return
    println(STDERR)
    warnbanner(label="[ UPDATE ERRORS ]", """
    WARNING: $(join(keys(errs),", "," and ")) had update errors.

     - Unrelated packages are unaffected
     - To retry, run Pkg2.update() again
    """)
end

function test!(pkg::AbstractString,
               errs::Vector{AbstractString},
               nopkgs::Vector{AbstractString},
               notests::Vector{AbstractString}; coverage::Bool=false)
    reqs_path = abspath(pkg,"test","REQUIRE")
    if isfile(reqs_path)
        tests_require = Reqs.parse(reqs_path)
        if (!isempty(tests_require))
            info("Computing test dependencies for $pkg...")
            resolve(merge(Reqs.parse("REQUIRE"), tests_require))
        end
    end
    test_path = abspath(pkg,"test","runtests.jl")
    if !isdir(pkg)
        push!(nopkgs, pkg)
    elseif !isfile(test_path)
        push!(notests, pkg)
    else
        info("Testing $pkg")
        cd(dirname(test_path)) do
            try
                color = Base.have_color? "--color=yes" : "--color=no"
                codecov = coverage? ["--code-coverage=user"] : ["--code-coverage=none"]
                compilecache = "--compilecache=" * (Bool(Base.JLOptions().use_compilecache) ? "yes" : "no")
                julia_exe = Base.julia_cmd()
                run(`$julia_exe --check-bounds=yes $codecov $color $compilecache $test_path`)
                info("$pkg tests passed")
            catch err
                warnbanner(err, label="[ ERROR: $pkg ]")
                push!(errs,pkg)
            end
        end
    end
    isfile(reqs_path) && resolve()
end

mutable struct PkgTestError <: Exception
    msg::String
end

function Base.showerror(io::IO, ex::PkgTestError, bt; backtrace=true)
    print_with_color(Base.error_color(), io, ex.msg)
end

function test(pkgs::Vector{AbstractString}; coverage::Bool=false)
    errs = AbstractString[]
    nopkgs = AbstractString[]
    notests = AbstractString[]
    for pkg in pkgs
        test!(pkg,errs,nopkgs,notests; coverage=coverage)
    end
    if !all(isempty, (errs, nopkgs, notests))
        messages = AbstractString[]
        if !isempty(errs)
            push!(messages, "$(join(errs,", "," and ")) had test errors")
        end
        if !isempty(nopkgs)
            msg = length(nopkgs) > 1 ? " are not installed packages" :
                                       " is not an installed package"
            push!(messages, string(join(nopkgs,", ", " and "), msg))
        end
        if !isempty(notests)
            push!(messages, "$(join(notests,", "," and ")) did not provide a test/runtests.jl file")
        end
        throw(PkgTestError(join(messages, "and")))
    end
end

test(;coverage::Bool=false) = test(sort!(AbstractString[keys(installed())...]); coverage=coverage)

end # module
