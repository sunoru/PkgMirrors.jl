using Mirrors

import Base.Test: @test

@test availables() == ["ZJU"]

@test current() == nothing

setmirror("ZJU")

@test current() == Mirror("ZJU", "https://mirrors.zju.edu.cn/julia")
