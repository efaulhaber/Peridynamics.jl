#TODO: remove @kwdef and do it manually with value warnings / errors.
"""
    NOSBMaterial <: AbstractMaterial

Material type for non-ordinary state-based peridynamic simulations

# Allowed material parameters

- `horizon::Float64`: Radius of point interactions
- `rho::Float64`: Density
- `E::Float64`: Young's modulus
- `nu::Float64`: Poisson's ratio
- `Gc::Float64`: Critical energy release rate
- `epsilon_c::Float64`: Critical strain

# Allowed export fields

- `position::Matrix{Float64}`: Position of each point
- `displacement::Matrix{Float64}`: Displacement of each point
- `velocity::Matrix{Float64}`: Velocity of each point
- `velocity_half::Matrix{Float64}`: Velocity parameter for Verlet time solver
- `acceleration::Matrix{Float64}`: Acceleration of each point
- `b_int::Matrix{Float64}`: Internal force density of each point
- `b_ext::Matrix{Float64}`: External force density of each point
- `damage::Vector{Float64}`: Damage of each point
- `n_active_bonds::Vector{Int}`: Number of intact bonds for each point
"""
Base.@kwdef struct NOSBMaterial <: AbstractBondSystemMaterial{NoCorrection}
    maxdmg::Float64 = 0.95
    maxjacobi::Float64 = 1.03
    corr::Float64 = 100.0
end

struct NOSBPointParameters <: AbstractPointParameters
    δ::Float64
    rho::Float64
    E::Float64
    nu::Float64
    G::Float64
    K::Float64
    λ::Float64
    μ::Float64
    Gc::Float64
    εc::Float64
    bc::Float64
end

function NOSBPointParameters(::NOSBMaterial, p::Dict{Symbol,Any})
    δ = get_horizon(p)
    rho = get_density(p)
    E, nu, G, K, λ, μ = get_elastic_params(p)
    Gc, εc = get_frac_params(p, δ, K)
    bc = 18 * K / (π * δ^4) # bond constant
    return NOSBPointParameters(δ, rho, E, nu, G, K, λ, μ, Gc, εc, bc)
end

@params NOSBMaterial NOSBPointParameters

struct NOSBVerletStorage <: AbstractStorage
    position::Matrix{Float64}
    displacement::Matrix{Float64}
    velocity::Matrix{Float64}
    velocity_half::Matrix{Float64}
    acceleration::Matrix{Float64}
    b_int::Matrix{Float64}
    b_ext::Matrix{Float64}
    damage::Vector{Float64}
    bond_active::Vector{Bool}
    n_active_bonds::Vector{Int}
end

function NOSBVerletStorage(::NOSBMaterial, ::VelocityVerlet, system::BondSystem, ch)
    n_loc_points = length(ch.loc_points)
    position = copy(system.position)
    displacement = zeros(3, n_loc_points)
    velocity = zeros(3, n_loc_points)
    velocity_half = zeros(3, n_loc_points)
    acceleration = zeros(3, n_loc_points)
    b_int = zeros(3, length(ch.point_ids))
    b_ext = zeros(3, n_loc_points)
    damage = zeros(n_loc_points)
    bond_active = ones(Bool, length(system.bonds))
    n_active_bonds = copy(system.n_neighbors)
    s = NOSBVerletStorage(position, displacement, velocity, velocity_half, acceleration,
                          b_int, b_ext, damage, bond_active, n_active_bonds)
    return s
end

@storage NOSBMaterial VelocityVerlet NOSBVerletStorage

@loc_to_halo_fields NOSBVerletStorage :position
@halo_to_loc_fields NOSBVerletStorage :b_int

function force_density_point!(storage::NOSBVerletStorage, system::BondSystem,
                              mat::NOSBMaterial, params::NOSBPointParameters, i::Int)
    F, Kinv, ω0 = calc_deformation_gradient(storage, system, params, i)
    if storage.damage[i] > mat.maxdmg || containsnan(F)
        kill_point!(storage, system, i)
        return nothing
    end
    P = calc_first_piola_stress(F, mat, params)
    if iszero(P) || containsnan(P)
        kill_point!(storage, system, i)
        return nothing
    end
    PKinv = P * Kinv
    for bond_id in each_bond_idx(system, i)
        bond = system.bonds[bond_id]
        j, L = bond.neighbor, bond.length

        ΔXij = SVector{3}(system.position[1, j] - system.position[1, i],
                          system.position[2, j] - system.position[2, i],
                          system.position[3, j] - system.position[3, i])
        Δxij = SVector{3}(storage.position[1, j] - storage.position[1, i],
                          storage.position[2, j] - storage.position[2, i],
                          storage.position[3, j] - storage.position[3, i])
        l = sqrt(Δxij.x * Δxij.x + Δxij.y * Δxij.y + Δxij.z * Δxij.z)
        ε = (l - L) / L

        # failure mechanism
        if ε > params.εc && bond.fail_permit
            storage.bond_active[bond_id] = false
        end

        # stabilization
        ωij = (1 + params.δ / L) * storage.bond_active[bond_id]
        Tij = mat.corr .* params.bc * ωij / ω0 .* (Δxij .- F * ΔXij)

        # update of force density
        tij = ωij * PKinv * ΔXij + Tij
        if containsnan(tij)
            tij = zero(SMatrix{3,3})
            storage.bond_active[bond_id] = false
        end
        storage.n_active_bonds[i] += storage.bond_active[bond_id]
        storage.b_int[1, i] += tij.x * system.volume[j]
        storage.b_int[2, i] += tij.y * system.volume[j]
        storage.b_int[3, i] += tij.z * system.volume[j]
        storage.b_int[1, j] -= tij.x * system.volume[i]
        storage.b_int[2, j] -= tij.y * system.volume[i]
        storage.b_int[3, j] -= tij.z * system.volume[i]
    end
    return nothing
end

function calc_deformation_gradient(storage::NOSBVerletStorage, system::BondSystem,
                                   params::NOSBPointParameters, i::Int)
    K = zeros(SMatrix{3,3})
    _F = zeros(SMatrix{3,3})
    ω0 = 0.0
    for bond_id in each_bond_idx(system, i)
        bond = system.bonds[bond_id]
        j, L = bond.neighbor, bond.length
        ΔXij = SVector{3}(system.position[1, j] - system.position[1, i],
                          system.position[2, j] - system.position[2, i],
                          system.position[3, j] - system.position[3, i])
        Δxij = SVector{3}(storage.position[1, j] - storage.position[1, i],
                          storage.position[2, j] - storage.position[2, i],
                          storage.position[3, j] - storage.position[3, i])
        Vj = system.volume[j]
        ωij = (1 + params.δ / L) * storage.bond_active[bond_id]
        ω0 += ωij
        temp = ωij * Vj
        K += temp * ΔXij * ΔXij'
        _F += temp * Δxij * ΔXij'
    end
    Kinv = inv(K)
    F = _F * Kinv
    return F, Kinv, ω0
end

function calc_first_piola_stress(F::SMatrix{3,3}, mat::NOSBMaterial,
                                 params::NOSBPointParameters)
    J = det(F)
    J < eps() && return zero(SMatrix{3,3})
    J > mat.maxjacobi && return zero(SMatrix{3,3})
    C = F' * F
    Cinv = inv(C)
    S = params.G .* (I - 1 / 3 .* tr(C) .* Cinv) .* J^(-2 / 3) .+
        params.K / 4 .* (J^2 - J^(-2)) .* Cinv
    P = F * S
    return P
end

function containsnan(K::T) where {T<:AbstractArray}
    @simd for i in eachindex(K)
        isnan(K[i]) && return true
    end
    return false
end

function kill_point!(s::AbstractStorage, bd::BondSystem, i::Int)
    s.bond_active[each_bond_idx(bd, i)] .= false
    s.n_active_bonds[i] = 0
    return nothing
end
