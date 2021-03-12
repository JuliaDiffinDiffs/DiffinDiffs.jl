@testset "VecColumnTable" begin
    hrs = exampledata("hrs")
    cols = VecColumnTable(AbstractVector[], Symbol[], Dict{Symbol,Int}())
    cols1 = VecColumnTable(AbstractVector[], Symbol[])
    @test cols1 == cols
    @test size(cols) == (0, 0)
    @test length(cols) == 0
    @test isempty(cols)
    @test_throws BoundsError cols[1]
    @test_throws ArgumentError size(cols, 3)
    @test sprint(show, MIME("text/plain"), cols) == "0×0 VecColumnTable"

    cols = VecColumnTable(AbstractVector[[]], Symbol[:a], Dict{Symbol,Int}(:a=>1))
    @test size(cols) == (0, 1)
    @test length(cols) == 1
    @test isempty(cols)

    cols = VecColumnTable(AbstractVector[hrs.wave, hrs.oop_spend], [:wave, :oop_spend],
        Dict(:wave=>1, :oop_spend=>2))
    cols1 = VecColumnTable(AbstractVector[hrs.wave, hrs.oop_spend], [:wave, :oop_spend])
    @test cols1 == cols
    @test nrow(cols) == 3280
    @test ncol(cols) == 2
    @test size(cols) == (3280, 2)
    @test length(cols) == 2
    @test isempty(cols) === false

    cols2 = VecColumnTable(hrs)
    @test size(cols2) == (3280, 11)

    @test cols[1] === hrs.wave
    @test cols[:] == cols[1:2] == cols[[1,2]] == cols[trues(2)] == [hrs.wave, hrs.oop_spend]
    @test cols[:wave] === cols[1]
    @test cols[[:oop_spend, :wave]] == [hrs.oop_spend, hrs.wave]
    @test_throws ArgumentError cols[[1, :oop_spend]]
    @test_throws BoundsError cols[1:3]

    @test propertynames(cols) == [:wave, :oop_spend]
    @test cols.wave === cols[1]

    @test keys(cols) == [:wave, :oop_spend]
    @test values(cols) == [hrs.wave, hrs.oop_spend]
    @test haskey(cols, :wave)
    @test haskey(cols, 1)
    @test get(cols, :wave, nothing) == cols[1]
    @test get(cols, :none, nothing) === nothing

    @test [col for col in cols] == cols[:]

    @test cols == deepcopy(cols)

    @test sprint(show, cols) == "3280×2 VecColumnTable"
    # There may be extra white space at the end of a row in earlier versions of Julia
    out1 = """
        3280×2 VecColumnTable:
         :wave       Int64  
         :oop_spend  Float64"""
    out2 = """
        3280×2 VecColumnTable:
         :wave       Int64
         :oop_spend  Float64"""
    @test sprint(show, MIME("text/plain"), cols) in (out1, out2)

    @test summary(cols) == "3280×2 VecColumnTable"
    summary(stdout, cols)

    @test Tables.istable(typeof(cols))
    @test Tables.columnaccess(typeof(cols))
    @test Tables.columns(cols) === cols
    @test Tables.getcolumn(cols, 1) === cols[1]
    @test Tables.getcolumn(cols, :wave) === cols[1]
    @test Tables.columnnames(cols) == [:wave, :oop_spend]

    @test Tables.schema(cols) == Tables.Schema{(:wave, :oop_spend), Tuple{Int, Float64}}()
    @test Tables.materializer(cols) == VecColumnTable

    @test Tables.columnindex(cols, :wave) == 1
    @test Tables.columntype(cols, :wave) == Int
    @test Tables.rowcount(cols) == 3280
end

@testset "subcolumns" begin
    hrs = exampledata("hrs")
    df = DataFrame(hrs)
    allowmissing!(df)

    cols = subcolumns(df, [])
    @test size(cols) == (0, 0)
    @test isempty(cols)

    cols = subcolumns(df, :wave, falses(size(df,1)))
    @test size(cols) == (0, 1)
    @test isempty(cols)
    @test cols.wave == cols[:wave] == cols[1] == Int[]

    cols = subcolumns(df, :wave)
    @test cols.wave == hrs.wave
    @test eltype(cols.wave) == Int
    @test size(cols) == (3280, 1)

    cols = subcolumns(df, :wave, nomissing=false)
    @test cols.wave == hrs.wave
    @test eltype(cols.wave) == Union{Int, Missing}

    df.male .= ifelse.(df.wave.==11, missing, df.male)
    @test_throws MethodError subcolumns(df, :male)

    cols = subcolumns(df, :male, df.wave.!=11)
    @test cols.male == hrs.male[hrs.wave.!=11]
    @test eltype(cols.male) == Int

    cols = subcolumns(df, (:wave, :male), df.wave.!=11)
    @test cols.wave == hrs.wave[hrs.wave.!=11]
    @test eltype(cols.wave) == Int
    @test subcolumns(df, [:wave, :male], df.wave.!=11) == cols
end
