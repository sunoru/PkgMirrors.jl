# PkgMirrors

*在 Julia 中使用镜像站*

`PkgMirrors.jl` 是一个用镜像站来加速下载的客户端。比如在中国在访问 GitHub 时经常会很慢，可以使用这个库来帮你安装其他库。

目前支持的镜像站（参见[镜像站列表](./data/mirror_list.txt)）：
- 浙江大学开源镜像站（https://mirrors.zju.edu.cn/julia/）
- 中国科学技术大学开源软件镜像（https://mirrors.ustc.edu.cn/julia/）

## 安装

**注意：这个库只能与 Pkg3 一起使用，也就是说最低支持的 Julia 版本是 0.7。**

推荐的安装方式如下：

```julia
julia> # 输入 "]" 以进入包管理器的 REPL 模式

# 如果你的 Julia 包管理器（Pkg）没有初始化过（比如刚安装完），可以用这句话来初始化 Pkg：
(v1.1) pkg> registry add https://mirrors.zju.edu.cn/julia/registries/General.git

# 从镜像站安装这个库：
(v1.1) pkg> add https://mirrors.zju.edu.cn/julia/PkgMirrors.jl.git#v1.2.0
```

根据喜好可以使用其它镜像站的 URL 替代上面使用的 ZJU 镜像站。Julia 1.0 的用户请把最后的版本号改成 `v1.1.0`。如果想使用开发分支可以删除 `#v1.2.0`。

如果你想用脚本来初始化，可以直接用 Pkg 的 API：
```julia
import Pkg
Pkg.Registry.add(Pkg.RegistrySpec(url="https://mirrors.zju.edu.cn/julia/registries/General.git"))
Pkg.add(Pkg.PackageSpec(url="https://mirrors.zju.edu.cn/julia/PkgMirrors.jl.git", rev="v1.2.0"))
import PkgMirrors
PkgMirrors.setmirror("ZJU")
```

## 使用

第一次使用 `PkgMirrors.jl` 时，需要指定所使用的镜像：

```julia
julia> import PkgMirrors

julia> PkgMirrors.availables()  # 列出所有可用的镜像。
1-element Array{String,1}:
 "ZJU"

julia> PkgMirrors.setmirror("ZJU")  # 设定当前镜像。
[ Info: Updating mirror information...
[ Info: PkgMirror ZJU activated.
PkgMirrors.PkgMirror("ZJU", "https://mirrors.zju.edu.cn/julia")
```

`PkgMirrors.jl` 会记住你所选择的镜像，因此以后无需重新调用 `setmirror`：

```julia
julia> import PkgMirrors
[ Info: Using saved mirror: ZJU (https://mirrors.zju.edu.cn/julia)
[ Info: Updating mirror information...
[ Info: PkgMirror ZJU activated.
```

选择镜像之后会自动被激活，然后你就可以用标准库中的 `Pkg` 来安装和更新软件包了。比如说：

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

你可以发现 Julia 语言官方的 General 登记簿（Registry）的 URL 已经被设定为你选择的镜像。

如果一个软件包不在你所选择的镜像上，则会自动通过 `git clone` 来下载。

当你退出 Julia 时 `PkgMirrors.jl` 会自动停用（比如把在硬盘上对 URL 的修改全都撤销），以免你下次不想使用它时出问题：

```julia
julia> exit()
[ Info: PkgMirror ZJU deactivated.
```

你也可以手动停用镜像站，或者使用如下语句清除本地缓存的信息：

```julia
julia> PkgMirrors.deactivate()
[ Info: PkgMirror ZJU deactivated.

julia> PkgMirrors.clear()
[ Info: Cache clear.
```

## 新的镜像？

若想搭建 Julia 软件包的镜像站，请参见 [julia-mirror](https://github.com/sunoru/julia-mirror)。欢迎在本 repo 中提 issue 或是发起 pull request 来补充[镜像列表](./data/mirror_list.txt)。

## 问题

目前已知的问题：
- `PkgMirrors.jl` 无法处理 General 登记簿以外的软件包（虽然现在镜像站也都并不提供其它登记簿）。

如果有任何疑问，欢迎来[提 issue](https://github.com/sunoru/PkgMirrors.jl/issues/new) 或是在 Discourse 论坛（[英文](https://discourse.julialang.org)或[中文](http://discourse.juliacn.com)的社区都可以）里发表问题的同时 @sunoru 。

## 开源协议

[MIT License](./LICENSE.md)
