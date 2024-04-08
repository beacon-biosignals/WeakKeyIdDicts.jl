"""
    WeakKeyIdDicts

Implements [`WeakKeyIdDict`](@ref), which constructs a hash table where the keys are weak
references to objects that may be garbage collected even when referenced in a hash table.
"""
module WeakKeyIdDicts

export WeakKeyIdDict

# Weak key dict using object-id hashing/equality
# copied from: https://github.com/Nemocas/AbstractAlgebra.jl/blob/f33f5de5e471938acbd06565245d839df4622916/src/WeakKeyIdDict.jl
# Based on Julia's WeakKeyIdDict

# Type to wrap a WeakRef to furbish it with objectid comparison and hashing.
#
# Note that various getter and setter functions below all need to explicitly
# use `WeakRefForWeakDict(key)` instead of `key` because the automatism that
# works for `WeakRef` does not work here: for `WeakRef` the hash function is
# simply that of the wrapped object, and comparing a `WeakRef` to a value
# automatically unwraps. But this does not work for `WeakRefForWeakDict`
# because we use a custom hash function based on the `objectid` (this is
# important because it allows efficient use of objects as keys even if
# there is no effective hash function for those objects).
struct WeakRefForWeakDict
    w::WeakRef
    WeakRefForWeakDict(@nospecialize(v)) = new(WeakRef(v))
end

Base.:(==)(wr1::WeakRefForWeakDict, wr2::WeakRefForWeakDict) = wr1.w.value === wr2.w.value
Base.hash(wr::WeakRefForWeakDict, h::UInt) = Base.hash_uint(3h - objectid(wr.w.value))

"""
    WeakKeyIdDict([itr])

`WeakKeyIdDict()` constructs a hash table where the keys are weak references to objects
which may be garbage collected even when referenced in a hash table.

See [`Dict`](https://docs.julialang.org/en/v1/base/collections/#Base.Dict) for further help.
Note, unlike [`Dict`](https://docs.julialang.org/en/v1/base/collections/#Base.Dict),
`WeakKeyIdDict` does not convert keys on insertion, as this would imply the key object was
unreferenced anywhere before insertion.

See also [`WeakRef`](https://docs.julialang.org/en/v1/base/base/#Core.WeakRef),
[`WeakKeyDict`](https://docs.julialang.org/en/v1/base/collections/#Base.WeakKeyDict).
"""
mutable struct WeakKeyIdDict{K,V} <: AbstractDict{K,V}
    ht::Dict{WeakRefForWeakDict,V}
    lock::ReentrantLock
    dirty::Bool

    # Constructors mirror Dict's
    function WeakKeyIdDict{K,V}() where {V} where {K}
        t = new(Dict{WeakRefForWeakDict,V}(), ReentrantLock(), 0)
        return t
    end
end
function WeakKeyIdDict{K,V}(kv) where {V} where {K}
    h = WeakKeyIdDict{K,V}()
    for (k, v) in kv
        h[k] = v
    end
    return h
end
function WeakKeyIdDict{K,V}(p::Pair) where {V} where {K}
    return setindex!(WeakKeyIdDict{K,V}(), p.second, p.first)
end
function WeakKeyIdDict{K,V}(ps::Pair...) where {V} where {K}
    h = WeakKeyIdDict{K,V}()
    sizehint!(h, length(ps))
    for p in ps
        h[p.first] = p.second
    end
    return h
end
WeakKeyIdDict() = WeakKeyIdDict{Any,Any}()

WeakKeyIdDict(kv::Tuple{}) = WeakKeyIdDict()
Base.copy(d::WeakKeyIdDict) = WeakKeyIdDict(d)

WeakKeyIdDict(ps::Pair{K,V}...) where {K,V} = WeakKeyIdDict{K,V}(ps)
WeakKeyIdDict(ps::Pair{K}...) where {K} = WeakKeyIdDict{K,Any}(ps)
WeakKeyIdDict(ps::(Pair{K,V} where {K})...) where {V} = WeakKeyIdDict{Any,V}(ps)
WeakKeyIdDict(ps::Pair...) = WeakKeyIdDict{Any,Any}(ps)

function WeakKeyIdDict(kv)
    try
        Base.dict_with_eltype((K, V) -> WeakKeyIdDict{K,V}, kv, eltype(kv))
    catch
        if !Base.isiterable(typeof(kv)) || !all(x -> isa(x, Union{Tuple,Pair}), kv)
            throw(ArgumentError("WeakKeyIdDict(kv): kv needs to be an iterator of tuples or pairs"))
        else
            rethrow()
        end
    end
end

function _cleanup_locked(h::WeakKeyIdDict)
    if h.dirty
        h.dirty = false
        idx = Base.skip_deleted_floor!(h.ht)
        while idx != 0
            if h.ht.keys[idx].w.value === nothing
                Base._delete!(h.ht, idx)
            end
            idx = Base.skip_deleted(h.ht, idx + 1)
        end
    end
    return h
end

function Base.sizehint!(d::WeakKeyIdDict, newsz)
    d.ht = sizehint!(d.ht, newsz)
    return d
end
Base.empty(d::WeakKeyIdDict, ::Type{K}, ::Type{V}) where {K,V} = WeakKeyIdDict{K,V}()

Base.IteratorSize(::Type{<:WeakKeyIdDict}) = Base.SizeUnknown()

Base.islocked(wkh::WeakKeyIdDict) = islocked(wkh.lock)
Base.lock(wkh::WeakKeyIdDict) = lock(wkh.lock)
Base.unlock(wkh::WeakKeyIdDict) = unlock(wkh.lock)
Base.lock(f, wkh::WeakKeyIdDict) = lock(f, wkh.lock)
Base.trylock(f, wkh::WeakKeyIdDict) = trylock(f, wkh.lock)

# anytime we lookup a key is an opportunity to check to see if that key has been GC'd and to
# then mark the state of the dict as dirty; upon calls to `setindex!` and `length` any
# `nothing` valued keys are removed from the dictionary.
function _getkey_locked(wkh::WeakKeyIdDict, key)
    k = getkey(wkh.ht, WeakRefForWeakDict(key), nothing)
    if !isnothing(key) && !isnothing(k)
        if isnothing(k.w.value)
            wkh.dirty = true
            return nothing
        end
        return k
    end

    return nothing
end

function Base.setindex!(wkh::WeakKeyIdDict{K}, v, key) where {K}
    !isa(key, K) && throw(ArgumentError("$key is not a valid key for type $K"))
    # 'nothing' is not valid because WeakRef's can be set to `nothing` after being finalized
    key === nothing && throw(ArgumentError("`nothing` is not a valid WeakKeyIdDict key"))
    lock(wkh) do
        _cleanup_locked(wkh)
        k = _getkey_locked(wkh, key)
        if k === nothing
            k = WeakRefForWeakDict(key)
        else
            k.w.value = key
        end
        return wkh.ht[k] = v
    end
    return wkh
end
function Base.get!(wkh::WeakKeyIdDict{K,V}, key, default) where {K,V}
    v = lock(wkh) do
        k = _getkey_locked(wkh, key)
        if key !== nothing && !isnothing(k)
            return wkh.ht[k]
        else
            return wkh[key] = convert(V, default)
        end
    end
    return v::V
end
function Base.get!(default::Base.Callable, wkh::WeakKeyIdDict{K,V}, key) where {K,V}
    v = lock(wkh) do
        k = getkey(wkh.ht, WeakRefForWeakDict(key), nothing)
        if key !== nothing && !isnothing(k) && !isnothing(k.w.value)
            return wkh.ht[k]
        else
            return wkh[key] = convert(V, default())
        end
    end
    return v::V
end

function Base.getkey(wkh::WeakKeyIdDict{K}, kk, default) where {K}
    k = lock(wkh) do
        local k = _getkey_locked(wkh, kk)
        k === nothing && return nothing
        return k.w.value
    end
    return k === nothing ? default : k::K
end

Base.map!(f, iter::Base.ValueIterator{<:WeakKeyIdDict}) = Base.map!(f, values(iter.dict.ht))

function Base.get(wkh::WeakKeyIdDict{K}, key, default) where {K}
    key === nothing && throw(KeyError(nothing))
    lock(wkh) do
        k = _getkey_locked(wkh, key)
        k === nothing && return default
        return wkh.ht[k]
    end
end
function Base.get(default::Base.Callable, wkh::WeakKeyIdDict{K}, key) where {K}
    key === nothing && throw(KeyError(nothing))
    lock(wkh) do
        k = _getkey_locked(wkh, key)
        k === nothing && return default()
        return wkh.ht[k]
    end
end
function Base.pop!(wkh::WeakKeyIdDict{K}, key) where {K}
    key === nothing && throw(KeyError(nothing))
    lock(wkh) do
        _getkey_locked(wkh, key)
        return pop!(wkh.ht, WeakRefForWeakDict(key))
    end
end
function Base.pop!(wkh::WeakKeyIdDict{K}, key, default) where {K}
    key === nothing && return default
    lock(wkh) do
        k = _getkey_locked(wkh, key)
        k === nothing && return default
        return pop!(wkh.ht, k, default)
    end
end
function Base.delete!(wkh::WeakKeyIdDict, key)
    key === nothing && return wkh
    lock(wkh) do
        k = _getkey_locked(wkh, key)
        delete!(wkh.ht, k)
        return
    end
    return wkh
end
function Base.empty!(wkh::WeakKeyIdDict)
    lock(wkh) do
        empty!(wkh.ht)
        return
    end
    return wkh
end
function Base.haskey(wkh::WeakKeyIdDict{K}, key) where {K}
    key === nothing && return false
    return lock(wkh) do
        k = _getkey_locked(wkh, key)
        return k !== nothing
    end
end
function Base.getindex(wkh::WeakKeyIdDict{K}, key) where {K}
    key === nothing && throw(KeyError(nothing))
    return lock(wkh) do
        k = _getkey_locked(wkh, key)
        k === nothing && throw(KeyError(key))
        return getindex(wkh.ht, k)
    end
end
Base.isempty(wkh::WeakKeyIdDict) = length(wkh) == 0
function Base.length(t::WeakKeyIdDict)
    return lock(t) do
        _cleanup_locked(t)
        return length(t.ht)
    end
end

function Base.iterate(t::WeakKeyIdDict{K,V}, state...) where {K,V}
    return lock(t) do
        while true
            y = iterate(t.ht, state...)
            y === nothing && return nothing
            wkv, state = y
            k = wkv[1].w.value
            GC.safepoint() # ensure `k` is now gc-rooted
            if k === nothing
                t.dirty = true
                continue # indicates `k` is scheduled for deletion
            end
            kv = Pair{K,V}(k::K, wkv[2])
            return (kv, state)
        end
    end
end

Base.filter!(f, d::WeakKeyIdDict) = Base.filter_in_one_pass!(f, d)

end
