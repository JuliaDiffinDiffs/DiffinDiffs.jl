@testset "findcell" begin
    hrs = exampledata("hrs")
    @test_throws ArgumentError findcell((), hrs)
    @test_throws ArgumentError findcell((:wave,), hrs, falses(size(hrs, 1)))

    rows = findcell((:wave,), hrs)
    @test length(rows) == 5
    @test rows[UInt32(5)] == findall(x->x==7, hrs.wave)

    df = DataFrame(hrs)
    df.wave = PooledArray(df.wave)
    @test findcell((:wave,), df) == rows

    esample = hrs.wave.!=11
    rows = findcell((:wave, :wave_hosp), hrs, esample)
    @test length(rows) == 16
    @test rows[one(UInt32)] == intersect(findall(x->x==10, view(hrs.wave, esample)), findall(x->x==10, view(hrs.wave_hosp, esample)))

    rows = findcell((:wave, :wave_hosp, :male), hrs)
    @test length(rows) == 40
end

@testset "cellrows" begin
    hrs = exampledata("hrs")
    cols0 = subcolumns(hrs, (:wave, :wave_hosp), falses(size(hrs, 1)))
    cols = subcolumns(hrs, (:wave, :wave_hosp))
    rows_dict0 = IdDict{UInt32, Vector{Int}}()
    @test_throws ArgumentError cellrows(cols, rows_dict0)
    rows_dict = findcell(cols)
    @test_throws ArgumentError cellrows(cols0, rows_dict)

    cells, rows = cellrows(cols, rows_dict)
    @test length(cells) == length(rows) == 20
    @test getfield(cells, :matrix) ==
        sortslices(unique(hcat(hrs.wave, hrs.wave_hosp), dims=1), dims=1)
    @test propertynames(cells) == [:wave, :wave_hosp]
    @test rows[1] == intersect(findall(x->x==7, hrs.wave), findall(x->x==8, hrs.wave_hosp))
end
