const ELASTIC_KWARGS = (:E, :nu)
const FRAC_KWARGS = (:Gc, :epsilon_c)
const DEFAULT_POINT_KWARGS = (:horizon, :rho, ELASTIC_KWARGS..., FRAC_KWARGS...)

function allowed_material_kwargs(::AbstractMaterial)
    return DEFAULT_POINT_KWARGS
end

"""
    material!(body, set; kwargs...)
    material!(body; kwargs...)

Specifies material parameters used for `body` or point set `set`

# Arguments

- `body::AbstractBody`: Peridynamic body
- `set::Symbol`: Point set on `body`

# Keywords

Allowed keywords depend on the selected material model. See material type documentation.
Default material parameter keywords:

- `horizon::Float64`: Radius of point interactions
- `rho::Float64`: Density
- `E::Float64`: Young's modulus
- `nu::Float64`: Poisson's ratio
- `Gc::Float64`: Critical energy release rate
- `epsilon_c::Float64`: Critical strain

# Throws

- Error if parameter is not eligible for specification in selected material model

# Example

```julia-repl
julia> material!(b; horizon=δ, E=2.1e5, rho=8e-6, Gc=2.7)

julia> b.point_params
1-element Vector{Peridynamics.BBPointParameters}:
 Peridynamics.BBPointParameters(0.0603, 8.0e-6, 210000.0, 0.25, 84000.0, 140000.0, 84000.0,
84000.0, 2.7, 0.013329779199368195, 6.0671037207022026e10)
```
"""
function material! end

function material!(b::AbstractBody, name::Symbol; kwargs...)
    check_if_set_is_defined(b.point_sets, name)

    p = Dict{Symbol,Any}(kwargs)
    check_material_kwargs(b.mat, p)

    points = b.point_sets[name]
    params = get_point_params(b.mat, p)

    _material!(b, points, params)

    return nothing
end

function material!(b::AbstractBody; kwargs...)
    p = Dict{Symbol,Any}(kwargs)
    check_material_kwargs(b.mat, p)

    isempty(b.point_params) || empty!(b.point_params)

    points = 1:b.n_points
    params = get_point_params(b.mat, p)

    _material!(b, points, params)
    return nothing
end

function _material!(b::AbstractBody, points::V, params::P) where {P,V}
    push!(b.point_params, params)
    id = length(b.point_params)
    b.params_map[points] .= id
    return nothing
end

function check_material_kwargs(mat::AbstractMaterial, p::Dict{Symbol,Any})
    allowed_kwargs = allowed_material_kwargs(mat)
    check_kwargs(p, allowed_kwargs)
    return nothing
end

function get_horizon(p::Dict{Symbol,Any})
    if !haskey(p, :horizon)
        throw(UndefKeywordError(:horizon))
    end
    δ::Float64 = float(p[:horizon])
    δ ≤ 0 && throw(ArgumentError("`horizon` should be larger than zero!\n"))
    return δ
end

function get_density(p::Dict{Symbol,Any})
    if !haskey(p, :rho)
        throw(UndefKeywordError(:rho))
    end
    rho::Float64 = float(p[:rho])
    rho ≤ 0 && throw(ArgumentError("`rho` should be larger than zero!\n"))
    return rho
end

function get_elastic_params(p::Dict{Symbol,Any})
    if !haskey(p, :E) || !haskey(p, :nu)
        msg = "insufficient keywords for calculation of elastic parameters!\n"
        msg *= "The keywords `E` (elastic modulus) and `nu` (poisson ratio) are needed!\n"
        throw(ArgumentError(msg))
    end
    E::Float64 = float(p[:E])
    E ≤ 0 && throw(ArgumentError("`E` should be larger than zero!\n"))
    nu::Float64 = float(p[:nu])
    nu ≤ 0 && throw(ArgumentError("`nu` should be larger than zero!\n"))
    nu ≥ 1 && throw(ArgumentError("too high value of `nu`! Condition: 0 < `nu` ≤ 1\n"))
    G = E / (2 * (1 + nu))
    K = E / (3 * (1 - 2 * nu))
    λ = E * nu / ((1 + nu) * (1 - 2nu))
    μ = G
    return E, nu, G, K, λ, μ
end

required_point_parameters() = (:δ, :rho, :E, :nu, :G, :K, :λ, :μ, :Gc, :εc)

#TODO: parameter checks material dependent...
# req_param_material(::AbstractMaterial) = (:δ, :rho, :E, :nu, :G, :K, :λ, :μ)

function log_material_parameters(param::AbstractPointParameters; indentation::Int=2)
    msg = log_qty("horizon", param.δ; indentation=indentation)
    msg *= log_qty("density", param.rho; indentation=indentation)
    msg *= log_qty("Young's modulus", param.E; indentation=indentation)
    msg *= log_qty("Poisson's ratio", param.nu; indentation=indentation)
    msg *= log_qty("shear modulus", param.G; indentation=indentation)
    msg *= log_qty("bulk modulus", param.K; indentation=indentation)
    return msg
end
