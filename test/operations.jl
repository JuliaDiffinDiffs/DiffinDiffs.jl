@testset "findcell" begin
    hrs = exampledata("hrs")
    @test_throws ArgumentError findcell((), hrs)
    @test findcell((:wave,), hrs, falses(size(hrs, 1))) == IdDict{Tuple, Vector{Int}}()

    cellrows = findcell((:wave,), hrs)
    cells = sort(collect(keys(cellrows)))
    @test cells == Tuple[(7,), (8,), (9,), (10,), (11,)]
    @test cellrows[(7,)] == findall(x->x==7, hrs.wave)

    df = DataFrame(hrs)
    df.wave = PooledArray(df.wave)
    @test findcell((:wave,), df) == cellrows

    esample = hrs.wave.!=11
    cellrows = findcell((:wave, :wave_hosp), hrs, esample)
    @test length(cellrows) == 16
    cells = sort(collect(keys(cellrows)))
    @test cells[1] == (7,8)
    @test cellrows[(7,8)] == intersect(findall(x->x==7, view(hrs.wave, esample)), findall(x->x==8, view(hrs.wave_hosp, esample)))

    df.wave_hosp = PooledArray(df.wave_hosp)
    @test findcell((:wave, :wave_hosp), df, esample) == cellrows

    cellrows = findcell((:wave, :wave_hosp, :male), hrs)
    @test length(cellrows) == 40
end
