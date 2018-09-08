import PkgMirrors
import Pkg
import Test: @test

PkgMirrors.clear()

@test PkgMirrors.availables() == ["ZJU"]

@test PkgMirrors.current() == nothing

PkgMirrors.setmirror("ZJU")

@test PkgMirrors.current() == PkgMirrors.PkgMirror("ZJU", "https://mirrors.zju.edu.cn/julia")

Pkg.update()

Pkg.add("RandomNumbers")

PkgMirrors.deactivate()

PkgMirrors.clear()
