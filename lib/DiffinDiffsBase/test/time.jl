@testset "RotatingTimeValue" begin
    rt0 = RotatingTimeValue(1, Date(1))
    rt1 = RotatingTimeValue(1.0, Date(1))
    @test RotatingTimeValue(typeof(rt0), 1.0, Date(1)) === rt0

    @test rotatingtime(1.0, Date(1)) == rt1
    rot = repeat(5:-1:1, inner=5)
    time = repeat(1:5, outer=5)
    rt = rotatingtime(rot, time)
    @test eltype(rt) == RotatingTimeValue{Int, Int}
    @test getfield.(rt, :rotation) == rot
    @test getfield.(rt, :time) == time

    @test isless(rt[1], rt[2])
    @test isless(rt[6], rt[1])
    @test isless(rt[1], rt[7])
    @test isless(rt[1], 2.0)
    @test isless(1, rt[2])
    @test isless(rt[1], missing)
    @test !isless(missing, rt[1])

    @test isequal(rt[1], RotatingTimeValue(5, 1))

    @test rt[1] == RotatingTimeValue(Int32(5), Int32(1))
    @test isequal(rt[1] == RotatingTimeValue(missing, 1), missing)
    @test isequal(rt[1] == RotatingTimeValue(5, missing), missing)
    @test isequal(rt[1] == RotatingTimeValue(1, missing), missing)
    @test rt[1] == 1
    @test 1 == rt[1]
    @test isequal(rt[1] == missing, missing)
    @test isequal(missing == rt[1], missing)

    @test zero(typeof(rt[1])) === RotatingTimeValue(0, 0)
    @test iszero(RotatingTimeValue(1, 0))
    @test !iszero(RotatingTimeValue(0, 1))
    @test one(typeof(rt[1])) === RotatingTimeValue(1, 1)
    @test isone(RotatingTimeValue(1, 1))
    @test !isone(RotatingTimeValue(1, 0))

    @test convert(typeof(rt[1]), RotatingTimeValue(Int32(5), Int32(1))) ===
        RotatingTimeValue(5, 1)

    @test nonmissingtype(RotatingTimeValue{Union{Int,Missing}, Union{Int,Missing}}) ==
        RotatingTimeValue{Int, Int}

    @test iterate(rt1) == (rt1, nothing)
    @test iterate(rt1, 1) === nothing
    @test length(rt1) == 1

    @test sprint(show, rt[1]) == "5_1"
    w = VERSION < v"1.6.0" ? "" : " "
    @test sprint(show, MIME("text/plain"), rt[1]) == """
        RotatingTimeValue{Int64,$(w)Int64}:
          rotation: 5
          time:     1"""
end

@testset "RotatingTimeArray" begin
    rot = collect(1:5)
    time = collect(1.0:5.0)
    a = RotatingTimeArray(rot, time)
    @test eltype(a) == RotatingTimeValue{Int, Float64}
    @test size(a) == (5,)
    @test IndexStyle(typeof(a)) == IndexLinear()

    @test a[1] == RotatingTimeValue(1, 1.0)
    @test a[5:-1:1] == RotatingTimeArray(rot[5:-1:1], time[5:-1:1])

    a[1] = RotatingTimeValue(2, 2.0)
    @test a[1] == RotatingTimeValue(2, 2.0)
    a[1:2] = a[3:4]
    @test a[1:2] == a[3:4]

    v = view(a, 2:4)
    @test v isa RotatingTimeArray
    @test v == a[2:4]

    @test typeof(similar(a)) == typeof(a)
    @test size(similar(a, 3)) == (3,)

    @test v.rotation == rot[2:4]
    @test v.time == time[2:4]

    @test refarray(a).rotation == rot
end
