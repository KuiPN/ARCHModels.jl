export GARCH
export _ARCH #ARCH conflicts with module name

"""
    GARCH{p, q, T<:AbstractFloat} <: VolatilitySpec{T}
"""
struct GARCH{p, q, T<:AbstractFloat} <: VolatilitySpec{T}
    coefs::Vector{T}
    function GARCH{p, q, T}(coefs::Vector{T}) where {p, q, T}
        length(coefs) == nparams(GARCH{p, q})  || throw(NumParamError(nparams(GARCH{p, q}), length(coefs)))
        new{p, q, T}(coefs)
    end
end

"""
    GARCH{p, q}(coefs) -> VolatilitySpec
    GARCH{p, q, T}()   -> VolatilitySpec
    GARCH{p, q}()      -> VolatilitySpec

Construct a GARCH specification with the given parameters. When `coefs` is
omitted, the coefficient vector is unititialized, with `T` defaulting to `Float64`.

# Example:
```jldoctest
julia> GARCH{2, 1}([1., .3, .4, .05 ])
GARCH{2,1} specification.

               ω  β₁  β₂   α₁
Parameters:  1.0 0.3 0.4 0.05
```
"""
GARCH{p, q}(coefs::Vector{T}) where {p, q, T}  = GARCH{p, q, T}(coefs)

GARCH{p, q, T}() where {p, q, T} = GARCH{p, q, T}(Vector{Float64}(undef, nparams(GARCH{p, q, T})))

GARCH{p, q}() where {p, q} = GARCH{p, q, Float64}()

"""
    _ARCH{q, T<:AbstractFloat} <: VolatilitySpec{T}
"""
const _ARCH = GARCH{0}

@inline nparams(::Type{<:GARCH{p, q}}) where {p, q} = p+q+1

@inline presample(::Type{<:GARCH{p, q}}) where {p, q} = max(p, q)

@inline function update!(ht, lht, zt, ::Type{<:GARCH{p,q}}, MS::Type{<:MeanSpec},
                         data, garchcoefs, meancoefs, t
                         ) where {p, q}
    mht = garchcoefs[1]
    for i = 1:p
        mht += garchcoefs[i+1]*ht[end-i+1]
    end
    for i = 1:q
        mht += garchcoefs[i+1+p]*(data[t-i]-mean(MS, meancoefs))^2
    end
    push!(ht, mht)
    push!(lht, (mht > 0) ? log(mht) : -mht)
    return nothing
end

@inline function uncond(::Type{<:GARCH{p, q}}, coefs::Vector{T}) where {p, q, T}
    den=one(T)
    for i = 1:p+q
        den -= coefs[i+1]
    end
    h0 = coefs[1]/den
end

function startingvals(::Type{<:GARCH{p,q}}, data::Array{T}) where {p, q, T}
    x0 = zeros(T, p+q+1)
    x0[2:p+1] .= 0.9/p
    x0[p+2:end] .= 0.05/q
    x0[1] = var(data)*(one(T)-sum(x0))
    return x0
end

function constraints(::Type{<:GARCH{p,q}}, ::Type{T}) where {p, q, T}
    lower = zeros(T, p+q+1)
    upper = ones(T, p+q+1)
    upper[1] = T(Inf)
    return lower, upper
end

function coefnames(::Type{<:GARCH{p,q}}) where {p, q}
    names = Array{String, 1}(undef, p+q+1)
    names[1] = "ω"
    names[2:p+1] .= (i -> "β"*subscript(i)).([1:p...])
    names[p+2:p+q+1] .= (i -> "α"*subscript(i)).([1:q...])
    return names
end
