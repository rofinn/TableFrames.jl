using TableFrames
using NamedTuples
using Base.Test

@testset "DataFrame" begin
    df = DataFrame(:id => collect(1:5), :val => collect(10:10:50))
    @test df[:id] == collect(1:5)
    @test df[:id, 2] == 2
    @test df[:val, 2] == 20
    r = df[2]
    @test r.id == 2
    @test r.val == 20

    df[:val, 2] = 100
    @test df[:val, 2] == 100
    df[2] = record(:id => 10, :val => 75)
    r = df[2]
    @test r.id == 10
    @test r.val == 75

    rs = collect(rows(df))
    @test length(rs) == 5
    @test isa(rs, Vector)
    @test isa(rs[1], NamedTuple)
end
