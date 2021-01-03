@testset "show singleton" begin
    @test sprint(show, Unconditional()) == "Unconditional"
    @test sprint(show, Unconditional(); context=:compact => true) == "U"

    @test sprint(show, Exact()) == "Parallel"
    @test sprint(show, Exact(); context=:compact => true) == "P"
end

@testset "nevertreated" begin
    nt0 = NeverTreatedParallel([0], Unconditional(), Exact())
    nt1 = NeverTreatedParallel([0,1], Unconditional(), Exact())

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

        f = @formula(y ~ nevertreated(c(0,1)))
        @test nevertreated(f.rhs.args_parsed[1]) == nt1

        f = @formula(y ~ treat(g, testtreat(t, 0), nevertreated(0)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, testtreat(t, 0), nevertreated(c(0,1))))
        t = parse_treat(f)[1]
        @test t.pr == nt1

        f = @formula(y ~ treat(g, testtreat(t, 0), nevertreated(0, Unconditional, Exact)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, testtreat(t, 0), nevertreated(0, unconditional, exact)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, testtreat(t, 0), nevertreated(0, unconditional)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, testtreat(t, 0), nevertreated(0, exact)))
        t = parse_treat(f)[1]
        @test t.pr == nt0

        f = @formula(y ~ treat(g, testtreat(t, 0), nevertreated(exact, unconditional, 0)))
        t = parse_treat(f)[1]
        @test t.pr == nt0
    end

    @testset "show" begin
        @test sprint(show, nt0) == """
            Parallel trends with any never-treated group:
              Never-treated groups: [0]
            """
        @test sprint(show, nt0; context=:compact => true) ==
            "NeverTreated{U,P}([0])"

        @test sprint(show, nt1) == """
            Parallel trends with any never-treated group:
              Never-treated groups: [0, 1]
            """
        @test sprint(show, nt1; context=:compact => true) ==
            "NeverTreated{U,P}([0, 1])"
    end
end

@testset "notyettreated" begin
    ny0 = NotYetTreatedParallel([0], nothing, Unconditional(), Exact())
    ny1 = NotYetTreatedParallel([0,1], nothing, Unconditional(), Exact())
    ny2 = NotYetTreatedParallel([0,1], [0], Unconditional(), Exact())
    ny3 = NotYetTreatedParallel([0,1], [0,1], Unconditional(), Exact())

    @testset "without @formula" begin
        @test notyettreated(0) == ny0
        @test notyettreated([0,1]) == ny1
        @test notyettreated(0:1, 0) == ny2
        @test notyettreated(Set([0,1]), 0:1) == ny3
        @test notyettreated([0,1,1], [0,1,1]) == ny3

        @test notyettreated(0, nothing, Unconditional(), Exact()) == ny0
        @test notyettreated(0, nothing, c=Unconditional(), s=Exact()) == ny0
        @test notyettreated([0,1], nothing, Unconditional(), Exact()) == ny1
        @test notyettreated([0,1], nothing, c=Unconditional(), s=Exact()) == ny1
    end

    @testset "with @formula" begin
        @test notyettreated(term(0)) == ny0
        
        f = @formula(y ~ notyettreated(c(0,1)))
        @test notyettreated(f.rhs.args_parsed[1]) == ny1

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(0)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(c(0,1), 0)))
        t = parse_treat(f)[1]
        @test t.pr == ny2

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(c(0,1), c(0,1))))
        t = parse_treat(f)[1]
        @test t.pr == ny3

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(0, Unconditional, Exact)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(0, unconditional, exact)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(0, unconditional)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(0, exact)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(exact, unconditional, 0)))
        t = parse_treat(f)[1]
        @test t.pr == ny0

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(c(0,1), 0, Unconditional, Exact)))
        t = parse_treat(f)[1]
        @test t.pr == ny2

        f = @formula(y ~ treat(g, testtreat(t, 0), notyettreated(exact, unconditional, c(0,1), c(0,1))))
        t = parse_treat(f)[1]
        @test t.pr == ny3
    end

    @testset "show" begin
        @test sprint(show, ny0) == """
            Parallel trends with any not-yet-treated group:
              Not-yet-treated groups: [0]
              Treated since: not specified
            """
        @test sprint(show, ny0; context=:compact => true) ==
            "NotYetTreated{U,P}([0], NA)"

        @test sprint(show, ny1) == """
            Parallel trends with any not-yet-treated group:
              Not-yet-treated groups: [0, 1]
              Treated since: not specified
            """
        @test sprint(show, ny1; context=:compact => true) ==
            "NotYetTreated{U,P}([0, 1], NA)"

        @test sprint(show, ny2) == """
            Parallel trends with any not-yet-treated group:
              Not-yet-treated groups: [0, 1]
              Treated since: [0]
            """
        @test sprint(show, ny2; context=:compact => true) ==
            "NotYetTreated{U,P}([0, 1], [0])"

        @test sprint(show, ny3) == """
            Parallel trends with any not-yet-treated group:
              Not-yet-treated groups: [0, 1]
              Treated since: [0, 1]
            """
        @test sprint(show, ny3; context=:compact => true) ==
            "NotYetTreated{U,P}([0, 1], [0, 1])"
    end
end
