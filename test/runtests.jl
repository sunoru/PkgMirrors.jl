import Mirrors
import Pkg
import Test: @test

Mirrors.clear()

@test Mirrors.availables() == ["ZJU"]

@test Mirrors.current() == nothing

Mirrors.setmirror("ZJU")

@test Mirrors.current() == Mirrors.Mirror("ZJU", "https://mirrors.zju.edu.cn/julia")

Pkg.update()

Pkg.add("RandomNumbers")

Mirrors.deactivate()

Mirrors.clear()
