include("set_up_tests.jl")
# below tests were originally copied from:
# https://github.com/Nemocas/AbstractAlgebra.jl/blob/f33f5de5e471938acbd06565245d839df4622916/test/WeakKeyIdDict-test.jl

@testset "WeakKeyIdDicts.jl" begin
    @testset "Aqua" begin
        Aqua.test_all(WeakKeyIdDicts; ambiguities=false)
    end

    # NOTE: the first two testsets are copied from
    # https://github.com/JuliaLang/julia/blob/d7dc9a8cc8f2aebf04d5cecc8625be250169644b/test/dict.jl#L565-L626
    # an modified for WeakKeyIdDict.

    # https://github.com/JuliaLang/julia/pull/10657
    mutable struct T10647{T}
        x::T
    end
    @testset "issue julia#10647" begin
        a = WeakKeyIdDict()
        a[1] = a
        a[a] = 2
        a[3] = T10647(a)
        @test isequal(a, a)
        show(IOBuffer(), a)
        Base.show(Base.IOContext(IOBuffer(), :limit => true), a)
        Base.show(IOBuffer(), a)
        Base.show(Base.IOContext(IOBuffer(), :limit => true), a)
    end

    @testset "WeakKeyIdDict{Any,Any} and partial inference" begin
        a = WeakKeyIdDict{Any,Any}()
        a[1] = a
        a[a] = 2

        sa = empty(a)
        @test isempty(sa)
        @test isa(sa, WeakKeyIdDict{Any,Any})

        @test length(a) == 2
        @test 1 in keys(a)
        @test a in keys(a)
        @test a[1] === a
        @test a[a] === 2

        ca = copy(a)
        @test length(ca) == length(a)
        @test isequal(ca, a)
        @test ca !== a # make sure they are different objects

        ca = empty!(ca)
        @test length(ca) == 0
        @test length(a) == 2

        d = Dict('a' => 1, 'b' => 1, 'c' => 3)
        @test a != d
        @test !isequal(a, d)

        d = @inferred WeakKeyIdDict{Any,Any}(Pair(1, 1), Pair(2, 2), Pair(3, 3))
        @test isa(d, WeakKeyIdDict{Any,Any})
        @test d == WeakKeyIdDict{Any,Any}(1 => 1, 2 => 2, 3 => 3)
        @test eltype(d) == Pair{Any,Any}

        d = WeakKeyIdDict{Any,Int32}(:hi => 7)
        let c = Ref{Any}(1.5)
            f() = c[]
            @test @inferred(get!(f, d, :hi)) === Int32(7)
            @test_throws InexactError(:Int32, Int32, 1.5) get!(f, d, :hello)
        end
    end

    @testset "WeakKeyIdDict" begin
        A = [1]
        B = [2]
        C = [3]

        # construction
        wkd = WeakKeyIdDict()
        wkd[A] = 2
        wkd[B] = 3
        wkd[C] = 4
        dd = convert(Dict{Any,Any}, wkd)
        @test WeakKeyIdDict(dd) == wkd
        @test convert(WeakKeyIdDict{Any,Any}, dd) == wkd
        @test isa(WeakKeyIdDict(dd), WeakKeyIdDict{Any,Any})

        # test many constructors without type parameters specified
        @test WeakKeyIdDict(A => 2, B => 3, C => 4) == wkd
        @test isa(WeakKeyIdDict(A => 2, B => 3, C => 4), WeakKeyIdDict{Vector{Int},Int})
        @test WeakKeyIdDict(a => i + 1 for (i, a) in enumerate([A, B, C])) == wkd
        @test WeakKeyIdDict([(A, 2), (B, 3), (C, 4)]) == wkd
        @test WeakKeyIdDict(Pair(A, 2), Pair(B, 3), Pair(C, 4)) == wkd

        # inferred type parameters during construction
        @test typeof(WeakKeyIdDict(1 => 1, :a => 2)) == WeakKeyIdDict{Any,Int}
        @test typeof(WeakKeyIdDict(1 => 1, 1 => :a)) == WeakKeyIdDict{Int,Any}
        @test typeof(WeakKeyIdDict(:a => 1, 1 => :a)) == WeakKeyIdDict{Any,Any}
        @test typeof(WeakKeyIdDict(())) == WeakKeyIdDict{Any,Any}

        # constructing from iterators
        @test_throws BoundsError WeakKeyIdDict(((),))
        @test_throws ArgumentError IdDict(nothing)

        # test many constructors with type parameters specified
        @test WeakKeyIdDict{Vector{Int},Int}(A => 2, B => 3, C => 4) == wkd
        @test isa(WeakKeyIdDict{Vector{Int},Int}(A => 2, B => 3, C => 4),
                  WeakKeyIdDict{Vector{Int},Int})
        @test WeakKeyIdDict{Vector{Int},Int}(a => i + 1 for (i, a) in enumerate([A, B, C])) ==
              wkd
        @test WeakKeyIdDict{Vector{Int},Int}([(A, 2), (B, 3), (C, 4)]) == wkd
        @test WeakKeyIdDict{Vector{Int},Int}(Pair(A, 2), Pair(B, 3), Pair(C, 4)) == wkd

        # test more constructors with mixed types
        @test isa(WeakKeyIdDict(A => 2, B => 3, C => "4"), WeakKeyIdDict{Vector{Int},Any})
        @test isa(WeakKeyIdDict(A => 2, B => 3, "C" => 4), WeakKeyIdDict{Any,Int})
        @test isa(WeakKeyIdDict(A => 2, B => 3, "C" => "4"), WeakKeyIdDict{Any,Any})

        @test copy(wkd) == wkd

        @test length(wkd) == 3
        @test !isempty(wkd)
        @test haskey(wkd, C)
        @test getkey(wkd, C, 123) === C
        res = pop!(wkd, C)
        @test res == 4
        @test C ∉ keys(wkd)
        @test 4 ∉ values(wkd)
        @test !haskey(wkd, C)
        @test length(wkd) == 2
        @test !isempty(wkd)
        @test 47 == pop!(wkd, C, 47)
        @test getkey(wkd, C, 123) == 123
        wkd = filter!(p -> p.first != B, wkd)
        @test B ∉ keys(wkd)
        @test 3 ∉ values(wkd)
        @test length(wkd) == 1
        @test WeakKeyIdDict(Pair(A, 2)) == wkd
        @test !isempty(wkd)

        wkd[A] = 42
        @test wkd[A] == 42

        wkd = WeakKeyIdDict(A => 2, B => 3, C => 4)
        map!(x -> x + 1, values(wkd))
        @test WeakKeyIdDict(A => 3, B => 4, C => 5) == wkd

        wkd = WeakKeyIdDict(A => 2, B => 3, C => 4)
        @test delete!(wkd, A) == WeakKeyIdDict(B => 3, C => 4)
        @test delete!(wkd, A) == WeakKeyIdDict(B => 3, C => 4)  # deleting the same key twice works
        @test delete!(wkd, C) == WeakKeyIdDict(B => 3)
        @test delete!(wkd, B) == WeakKeyIdDict()
        # adding stuff back is OK
        wkd[A] = 2
        wkd[B] = 3
        wkd[C] = 4
        @test wkd == WeakKeyIdDict(A => 2, B => 3, C => 4)

        wkd = WeakKeyIdDict(A => 2)
        @test get(wkd, A, 17) == 2
        @test get!(wkd, A, 17) == 2
        @test get(wkd, B, 17) == 17
        @test length(wkd) == 1
        @test get!(wkd, B, 17) == 17
        @test length(wkd) == 2

        wkd = WeakKeyIdDict(A => 2)
        @test get(() -> 23, wkd, A) == 2
        @test get!(() -> 23, wkd, A) == 2
        @test get(() -> 23, wkd, B) == 23
        @test length(wkd) == 1
        @test get!(() -> 23, wkd, B) == 23
        @test length(wkd) == 2

        wkd = empty!(wkd)
        @test wkd == empty(wkd)
        @test wkd == empty(wkd)
        @test typeof(wkd) == typeof(empty(wkd))
        @test length(wkd) == 0
        @test isempty(wkd)
        @test isa(wkd, WeakKeyIdDict)
        @test WeakKeyIdDict() == WeakKeyIdDict(())

        # test inference for returned values
        d = @inferred WeakKeyIdDict(Pair(1, 1), Pair(2, 2), Pair(3, 3))
        @test 1 == @inferred d[1]
        @inferred setindex!(d, -1, 10)
        @test d[10] == -1
        @test 1 == @inferred d[1]
        @test get(d, -111, nothing) == nothing
        @test 1 == @inferred get(d, 1, 1)
        @test pop!(d, -111, nothing) == nothing
        @test 1 == @inferred pop!(d, 1)

        # sizehint! & rehash!
        d = WeakKeyIdDict()
        @test sizehint!(d, 10^4) === d
        @test length(d.ht.vals) >= 10^4
        d = WeakKeyIdDict()
        for jj in 1:30, i in 1:(10^4)
            d[string(i)] = i
        end
        @test all(i -> d[string(i)] == i, 1:(10^4))
        @test length(d.ht.vals) >= 10^4

        # bad iterable argument
        @test_throws ArgumentError WeakKeyIdDict([1, 2, 3])

        # immutables can be arguments
        WeakKeyIdDict([1 => 2])
        WeakKeyIdDict([MyStruct([1,2,3]) => 2])

        # WeakKeyIdDict does not convert keys
        @test_throws ArgumentError WeakKeyIdDict{Int,Any}(5.0 => 1)

        # iterator
        wkd = WeakKeyIdDict(A => 2, B => 3, C => 4)
        @test Set(collect(wkd)) == Set([A => 2, B => 3, C => 4])
        @test 2 + 3 + 4 == sum(v for (k, v) in wkd)

        # WeakKeyIdDict hashes with object-id
        AA = copy(A)
        GC.@preserve A AA begin
            wkd = WeakKeyIdDict(A => 1, AA => 2)
            @test length(wkd) == 2
            kk = collect(keys(wkd))
            @test kk[1] == kk[2]
            @test kk[1] !== kk[2]
        end

        # WeakKeyIdDict compares to other dicts:
        @test IdDict(A => 1) != WeakKeyIdDict(A => 1)
        @test Dict(A => 1) == WeakKeyIdDict(A => 1)
        @test Dict(copy(A) => 1) != WeakKeyIdDict(A => 1)
    end

    @testset "WeakKeyIdDict.lock" begin
        A = [1]
        B = [2]
        C = [3]
        wkd = WeakKeyIdDict(A => 2, B => 3, C => 4)
        @test !islocked(wkd)
        lock(wkd)
        @test islocked(wkd)
        unlock(wkd)
        @test !islocked(wkd)
    end

    @testset "WeakKeyIdDict.gc" begin
        # https://github.com/JuliaLang/julia/issues/26939
        d26939 = WeakKeyIdDict()
        d26939[big"1.0" + 1.1] = 1
        GC.gc() # make sure this doesn't segfault

        wkd = WeakKeyIdDict([42] => 2, [43] => 3, [44] => 4)
        for k in keys(wkd)
            delete!(wkd, k)
        end
        @test isempty(wkd)
        GC.gc()  # try to get it to evict some weak references
        @test isempty(wkd)
    end
end

# verify that garbage collection takes care of our weak references
#
# This test somehow doesn't work if it is inside a @testset as then the
# WeakRef is not collected for some reason I don't quite understand at
# this point... :-(
_tmp_key = MyStruct([1,2])
wkd = WeakKeyIdDict(_tmp_key => 1)
let tmp = MyStruct([42])
    @test length(wkd) == 1
    wkd[tmp] = 2
    @test length(wkd) == 2
end
# at this point there is no strong reference left to the vector [42]
# previously reachable via tmp
GC.gc(true)

@test wkd[_tmp_key] == 1
@test length(wkd) == 1
@test length(keys(wkd)) == 1
@test WeakKeyIdDict(_tmp_key => 1) == wkd
