# Mirrors

*Use alternative mirrors to manage your packages for Julia.*

Linux, OSX:
[![Build Status](https://travis-ci.org/sunoru/Mirrors.jl.svg?branch=master)](https://travis-ci.org/sunoru/Mirrors.jl)

Windows:
[![Build status](https://ci.appveyor.com/api/projects/status/jw8aik6dcug8io06?svg=true)](https://ci.appveyor.com/project/sunoru/mirrors-jl)

Code Coverage:
[![Coverage Status](https://coveralls.io/repos/sunoru/Mirrors.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/sunoru/Mirrors.jl?branch=master)
[![codecov.io](http://codecov.io/github/sunoru/Mirrors.jl/coverage.svg?branch=master)](http://codecov.io/github/sunoru/Mirrors.jl?branch=master)

`Mirrors.jl` is a client for boosting your download by using a mirror when you have a slow connection to GitHub (for example, in China).

Current supported mirrors (see [mirror_list.txt](./data/mirror_list.txt)):
- ZJU (https://mirrors.zju.edu.cn/julia/)

## Installation

NOTE: This package will only work with Pkg3, which means you need to run Julia 0.7+ to use it.

There are several ways to install this package:

```julia
julia> # Type "]" to enter Pkg REPL-mode.

(v1.0) pkg> add Mirrors  # Install from the official registry.

(v1.0) pkg> add https://github.com/sunoru/Mirrors.jl.git  # Install from source code.

(v1.0) pkg> add https://mirrors.zju.edu.cn/julia/Mirrors.jl.git#v1.0.0  # Install from the mirror. (Recommended)
```

You will probably prefer the third way, for it is why you want to use `Mirrors.jl`. The URL can be replaced by that of your preferred mirror. Remove `#v1.0.0` if you want to use the developing branch.

## Usage

To start with `Mirrors.jl`, import the package and set a mirror.

```julia
julia> import Mirrors

julia> Mirrors.availables()  # to list available mirrors.
1-element Array{String,1}:
 "ZJU"

julia> Mirrors.setmirror("ZJU")
[ Info: Updating mirror information...
[ Info: Mirror ZJU activated.
Mirrors.Mirror("ZJU", "https://mirrors.zju.edu.cn/julia")
```

It will remember which mirror you have chosen, so there's no need to `setmirror` for the next time:

```julia
julia> import Mirrors
[ Info: Using saved mirror: ZJU (https://mirrors.zju.edu.cn/julia)
[ Info: Updating mirror information...
[ Info: Mirror ZJU activated.
```

Once a mirror is selected and activated, you are free to use the standard `Pkg` to install or update packages. For example:

```julia
julia> # Type "]" to enter Pkg REPL-mode.

(v1.0) pkg> update
  Updating registry at `C:\Users\sunoru\.julia\registries\General`
  Updating git-repo `https://mirrors.zju.edu.cn/julia/registries/General.git`
 Resolving package versions...
  Updating `C:\Users\sunoru\.julia\environments\v1.0\Project.toml`
 [no changes]
  Updating `C:\Users\sunoru\.julia\environments\v1.0\Manifest.toml`
 [no changes]

(v1.0) pkg> add RandomNumbers
 Resolving package versions...
  Updating `C:\Users\sunoru\.julia\environments\v1.0\Project.toml`
  [e6cf234a] + RandomNumbers v1.0.1
  Updating `C:\Users\sunoru\.julia\environments\v1.0\Manifest.toml`
  [e6cf234a] + RandomNumbers v1.0.1
```

You can find that the URL of the git repo for General registry has been modified to the one `Mirrors.jl` provides.

When you exit Julia the changes to your registries will be undone automatically:

```julia
julia> exit()
[ Info: Mirror ZJU deactivated.
```

You can also deactivate the mirror manually or clear the cache data by a simple statement:
```julia
julia> Mirrors.deactivate()
[ Info: Mirror ZJU deactivated.

julia> Mirrors.clear()
[ Info: Cache clear.
```

## New mirror?

See [julia-mirror](https://github.com/sunoru/julia-mirror) for how to build a mirror. You can file an issue or open a pull request to add a new mirror into [the mirror list](./data/mirror_list.txt).

## Issues

Known:
- `Mirrors.jl` is not able to deal with packages not in General registry at the moment. It is not vital yet, since the only mirror doesn't provide other registries as well.

You are welcome to [file an issue](https://github.com/sunoru/Mirrors.jl/issues/new) if having any questions.

Chinese user

## License

[MIT License](./LICENSE.md)
