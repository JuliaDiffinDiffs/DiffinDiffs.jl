@testset "SubColumns" begin
    hrs = exampledata("hrs")
    df = DataFrame(hrs)
    allowmissing!(df)

    cols = SubColumns(df, [])
    @test size(cols) == (0, 0)
    @test isempty(cols)
    @test_throws BoundsError cols[1]
    @test_throws ArgumentError size(cols, 3)
    @test sprint(show, MIME("text/plain"), cols) == "0×0 SubColumns"

    cols = SubColumns(df, :wave, falses(size(df,1)))
    @test size(cols) == (0, 1)
    @test isempty(cols)
    @test cols.wave == cols[:wave] == cols[1] == Int[]

    cols = SubColumns(df, :wave)
    @test cols.wave == hrs.wave
    @test eltype(cols.wave) == Int
    @test size(cols) == (3280, 1)

    cols = SubColumns(df, :wave, nomissing=false)
    @test cols.wave == hrs.wave
    @test eltype(cols.wave) == Union{Int, Missing}

    df.male .= ifelse.(df.wave.==11, missing, df.male)
    @test_throws MethodError SubColumns(df, :male)

    cols = SubColumns(df, :male, df.wave.!=11)
    @test cols.male == hrs.male[hrs.wave.!=11]
    @test eltype(cols.male) == Int

    cols = SubColumns(df, (:wave, :male), df.wave.!=11)
    @test cols.wave == hrs.wave[hrs.wave.!=11]
    @test eltype(cols.wave) == Int
    names = [:wave, :male]
    @test SubColumns(df, names, df.wave.!=11) == cols
    @test cols[1:2] == cols[[1,2]] == getfield(cols, :columns)

    @test propertynames(cols) == names
    @test propertynames(cols) !== names

    @test sprint(show, cols) == "2624×2 SubColumns"
    @test sprint(show, MIME("text/plain"), cols) == """
        2624×2 SubColumns:
          wave male"""
    
    @test summary(cols) == "2624×2 SubColumns"
    summary(stdout, cols)

    @test Tables.istable(typeof(cols))
    @test Tables.columnaccess(typeof(cols))
    @test Tables.columns(cols) === cols
    col1 = getfield(cols, :columns)[1]
    @test Tables.getcolumn(cols, 1) === col1
    @test Tables.getcolumn(cols, :wave) === col1
end
