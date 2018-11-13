import PkgMirrors
import Pkg
import Test: @test

PkgMirrors.clear()

@test PkgMirrors.availables()[1] == "ZJU"

@test PkgMirrors.current() == nothing

PkgMirrors.setmirror("ZJU")

@test PkgMirrors.current() == PkgMirrors.PkgMirror("ZJU", "https://mirrors.zju.edu.cn/julia")

PkgMirrors.setmirror("USTC")

Pkg.update()

Pkg.add("RandomNumbers")

PkgMirrors.deactivate()

PkgMirrors.clear()
