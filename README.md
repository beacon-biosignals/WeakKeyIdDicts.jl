# WeakKeyIdDicts

[![CI](https://github.com/beacon-biosignals/WeakKeyIdDicts.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/beacon-biosignals/WeakKeyIdDicts.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/beacon-biosignals/WeakKeyIdDicts.jl/branch/main/graph/badge.svg?token=IeRxFxQwG8&flag=WeakKeyIdDicts)](https://app.codecov.io/gh/beacon-biosignals/WeakKeyIdDicts.jl/tree/main)

Implements one public type, `WeakKeyIdDict`. It constructs a hash table where the keys are weak references to objects that may be garbage collected even when referenced in a hash table. Like [`WeakKeyDict`](https://docs.julialang.org/en/v1/base/collections/#Base.WeakKeyDict) it only supports keys that are mutable objects (all objects satisfying `ismutable(obj) == true`, such as Strings, Arrays and objects defined with `mutable struct`). Like [`IdDict`](https://docs.julialang.org/en/v1/base/collections/#Base.IdDict) the keys are hashed by `objectid`.

A dictionary with weak keys is useful when we wish to store information about an object that survives only for the life-time of that object, usually to avoid memory leaks. For instance, if we wish to cache some hard to compute value associated with the keys of the dictionary.

```julia
_tmp_key = [1]
wkd = WeakKeyIdDict(_tmp_key => 1)
let tmp = [42]
    wkd[tmp] = 2
    @show length(wkd) # 2
end
# at this point there is no strong reference left to the vector [42]
# previously reachable via tmp
GC.gc(true)

@show length(wkd) # 1
```

Avoid assuming a key exists in a `WeakKeyDict`, especially when allocation occurs. Keys can be removed any time garbage collection occurs. Favor the methods `get!` and `get` over `getindex`.
