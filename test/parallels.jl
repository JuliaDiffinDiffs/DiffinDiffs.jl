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
end
