# WeakKeyIdDicts.jl

[![docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://beacon-biosignals.github.io/WeakKeyIdDicts.jl/dev)
[![docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://beacon-biosignals.github.io/WeakKeyIdDicts.jl/stable)
[![CI](https://github.com/beacon-biosignals/WeakKeyIdDicts.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/beacon-biosignals/WeakKeyIdDicts.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/beacon-biosignals/WeakKeyIdDicts.jl/branch/main/graph/badge.svg?token=IeRxFxQwG8&flag=WeakKeyIdDicts)](https://app.codecov.io/gh/beacon-biosignals/WeakKeyIdDicts.jl/tree/main)

Implements a WeakKeyIdDict which constructs a hash table where the keys are weak
references to objects that may be garbage collected even when referenced in a hash table.
