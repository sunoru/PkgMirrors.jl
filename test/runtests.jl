using Mirrors

if VERSION < v"0.7-"
    import Base.Test: @test
else
    import Test: @test
end

@test availables() == ["zju"]

@test current() == nothing

setmirror("zju")

@test current() == Mirror("zju", "https://mirrors.zju.edu.cn/julia")

include(Mirrors.ISPKG3 ? "pkg3.jl" : "pkg2.jl")
