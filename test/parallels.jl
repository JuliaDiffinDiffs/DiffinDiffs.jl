@testset "singletons" begin
    @testset "alias" begin
        @test unconditional() == Unconditional()
        @test exact() == Exact()
    end

    @testset "show" begin
        @test sprint(show, Unconditional()) == "Unconditional"
        @test sprintcompact(Unconditional()) == "U"

        @test sprint(show, Exact()) == "Parallel"
        @test sprintcompact(Exact()) == "P"
    end
end

@testset "nevertreated" begin
    nt0 = NeverTreatedParallel([0], Unconditional(), Exact())
    nt1 = NeverTreatedParallel([0,1], Unconditional(), Exact())
    
    @testset "inner constructor" begin
        @test NeverTreatedParallel([1,1,0], Unconditional(), Exact()) == nt1
        @test_throws ErrorException NeverTreatedParallel([], Unconditional(), Exact())
        @test_throws InexactError NeverTreatedParallel([-0.5], Unconditional(), Exact())
    end

    @testset "without @formula" begin
        @test nevertreated(0) == nt0
        @test nevertreated([0,1]) == nt1
        @test nevertreated(0:1) == nt1
        @test nevertreated(Set([0,1])) == nt1
        @test nevertreated([0,1,1]) == nt1

        @test nevertreated(0, Unconditional(), Exact()) == nt0
        @test nevertreated(0, c=Unconditional(), s=Exact()) == nt0
        @test nevertreated([0,1], Unconditional(), Exact()) == nt1
        @test nevertreated([0,1], c=Unconditional(), s=Exact()) == nt1
    end

    @testset "with @formula" begin
        @test nevertreated(term(0)) == nt0

        f = @formula(y ~ nevertreated(cb(0,1)))
        @test nevertreated(f.rhs.args_parsed[1]) == nt1

        f = @formula(y ~ treat(g, ttreat(t, 0), nevertreated(0)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, ttreat(t, 0), nevertreated(cb(0,1))))
        t = parse_treat(f)[1]
        @test t.pr == nt1

        f = @formula(y ~ treat(g, ttreat(t, 0), nevertreated(0, Unconditional, Exact)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, ttreat(t, 0), nevertreated(0, unconditional, exact)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, ttreat(t, 0), nevertreated(0, unconditional)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, ttreat(t, 0), nevertreated(0, exact)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, ttreat(t, 0), nevertreated(exact, unconditional, 0)))
        t = parse_treat(f)[1]
        @test t.pr == nt0
    end

    @testset "show" begin
        @test sprint(show, nt0) == "NeverTreated{U,P}([0])"
        @test sprint(show, MIME("text/plain"), nt0) == """
            Parallel trends with any never-treated group:
              Never-treated groups: [0]"""

        @test sprint(show, nt1) == "NeverTreated{U,P}([0, 1])"
        @test sprint(show, MIME("text/plain"), nt1) == """
            Parallel trends with any never-treated group:
              Never-treated groups: [0, 1]"""
    end
end

@testset "notyettreated" begin
    ny0 = NotYetTreatedParallel([0], [0], Unconditional(), Exact())
    ny1 = NotYetTreatedParallel([0,1], [0], Unconditional(), Exact())
    ny2 = NotYetTreatedParallel([0,1], [0], Unconditional(), Exact())
    ny3 = NotYetTreatedParallel([0,1], [0,1], Unconditional(), Exact())

    @testset "inner constructor" begin
        @test NotYetTreatedParallel([1,1,0], [1,0,0], Unconditional(), Exact()) == ny3
        @test_throws ErrorException NotYetTreatedParallel([0], [], Unconditional(), Exact())
        @test_throws ErrorException NotYetTreatedParallel([], [0], Unconditional(), Exact())
        @test_throws InexactError NotYetTreatedParallel([-0.5], [-1], Unconditional(), Exact())
    end

    @testset "without @formula" begin
        @test notyettreated(0) == ny0
        @test notyettreated([0,1]) == ny1
        @test notyettreated(0:1, 0) == ny2
        @test notyettreated(Set([0,1]), 0:1) == ny3
        @test notyettreated([0,1,1], [0,1,1]) == ny3

        @test notyettreated(0, 0, Unconditional(), Exact()) == ny0
        @test notyettreated(0, c=Unconditional(), s=Exact()) == ny0
        @test notyettreated([0,1], [0], Unconditional(), Exact()) == ny1
        @test notyettreated([0,1], c=Unconditional(), s=Exact()) == ny1
    end

    @testset "with @formula" begin
        @test notyettreated(term(0)) == ny0
        
        f = @formula(y ~ notyettreated(cb(0,1)))
        @test notyettreated(f.rhs.args_parsed[1]) == ny1

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(0)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(cb(0,1), 0)))
        t = parse_treat(f)[1]
        @test t.pr == ny2

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(cb(0,1), cb(0,1))))
        t = parse_treat(f)[1]
        @test t.pr == ny3

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(0, Unconditional, Exact)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(0, unconditional, exact)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(0, unconditional)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(0, exact)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(exact, unconditional, 0)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(cb(0,1), 0, Unconditional, Exact)))
        t = parse_treat(f)[1]
        @test t.pr == ny2

        f = @formula(y ~ treat(g, ttreat(t, 0), notyettreated(exact, unconditional, cb(0,1), cb(0,1))))
        t = parse_treat(f)[1]
        @test t.pr == ny3
    end

    @testset "show" begin
        @test sprint(show, ny0) == "NotYetTreated{U,P}([0])"
        @test sprint(show, MIME("text/plain"), ny0) == """
            Parallel trends with any not-yet-treated group:
              Not-yet-treated groups: [0]
              Treated since: [0]"""

        @test sprint(show, ny1) == "NotYetTreated{U,P}([0, 1])"
        @test sprint(show, MIME("text/plain"), ny1) == """
            Parallel trends with any not-yet-treated group:
              Not-yet-treated groups: [0, 1]
              Treated since: [0]"""

        @test sprint(show, ny2) == "NotYetTreated{U,P}([0, 1])"
        @test sprint(show, MIME("text/plain"), ny2) == """
            Parallel trends with any not-yet-treated group:
              Not-yet-treated groups: [0, 1]
              Treated since: [0]"""

        @test sprint(show, ny3) == "NotYetTreated{U,P}([0, 1])"
        @test sprint(show, MIME("text/plain"), ny3) == """
            Parallel trends with any not-yet-treated group:
              Not-yet-treated groups: [0, 1]
              Treated since: [0, 1]"""
    end
end

@testset "istreated" begin
    nt = nevertreated(-1)
    @test istreated(nt, -1) == false
    @test istreated(nt, 0)

    ny = notyettreated(5)
    @test istreated(ny, 5) == false
    @test istreated(ny, 4)

    ny = notyettreated(5, 4)
    @test istreated(ny, 4)
end

@testset "termvars" begin
    @test termvars(Unconditional()) == Symbol[]
    @test termvars(Exact()) == Symbol[]
    @test termvars(nevertreated(-1)) == Symbol[]
    @test termvars(notyettreated(5)) == Symbol[]

    @test_throws ErrorException termvars(TestParaCondition())
    @test_throws ErrorException termvars(TestParaStrength())
    @test_throws ErrorException termvars(PR)
end
