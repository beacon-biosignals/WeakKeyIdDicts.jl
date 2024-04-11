# WeakKeyIdDicts

[![CI](https://github.com/beacon-biosignals/WeakKeyIdDicts.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/beacon-biosignals/WeakKeyIdDicts.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/beacon-biosignals/WeakKeyIdDicts.jl/branch/main/graph/badge.svg?token=IeRxFxQwG8&flag=WeakKeyIdDicts)](https://app.codecov.io/gh/beacon-biosignals/WeakKeyIdDicts.jl/tree/main)

Implements a WeakKeyIdDict which constructs a hash table where the keys are weak
references to objects that may be garbage collected even when referenced in a hash table.

It defines one type, `WeakKeyIdDict`, that follows the same API as `Dict`.

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
