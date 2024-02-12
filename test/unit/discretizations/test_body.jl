using Peridynamics, Test

@inline material_type(::Peridynamics.PointSetHandler{M}) where {M} = M

##
let
    # setup
    n_points = 10
    position, volume = rand(3, n_points), rand(n_points)
    body = Body(position, volume)

    # test body creation
    @test body.n_points == n_points
    @test body.position == position
    @test body.volume == volume
    @test body.failure_allowed == BitVector(fill(true, n_points))
    @test body.single_dim_bcs == Vector{Peridynamics.SingleDimBC}()
    @test body.single_dim_ics == Vector{Peridynamics.SingleDimIC}()
    @test body.point_sets_precracks == Vector{Peridynamics.PointSetsPreCrack}()
    @test isa(body.psh, Peridynamics.PointSetHandler{Peridynamics.AbstractMaterial})
end

## point sets
let
    # setup
    position = [0.0 1.0 0.0 0.0
                0.0 0.0 1.0 0.0
                0.0 0.0 0.0 1.0]
    volume = [1, 1, 1, 1]
    body = Body(position, volume)

    # test body creation
    @test body.n_points == 4
    @test body.position == position
    @test body.volume == volume
    @test body.failure_allowed == BitVector(fill(true, 4))
    @test isa(body.psh, Peridynamics.PointSetHandler{Peridynamics.AbstractMaterial})

    # add point set
    point_set!(body, :a, 1:2)
    @test body.psh.point_sets == Dict(:a => 1:2)

    # add another point set via function definition
    point_set!(x -> x > 0.5, body, :b)
    @test body.psh.point_sets == Dict(:a => 1:2, :b => [2])

    # add point set with do syntax
    point_set!(body, :c) do p
        p[3] > 0.0
    end
    @test body.psh.point_sets == Dict(:a => 1:2, :b => [2], :c => [4])

    # point_set!
    @test_throws BoundsError point_set!(body, :d, 1:5)
end

## bond-based material
let
    # setup
    position = [0.0 1.0 0.0 0.0
                0.0 0.0 1.0 0.0
                0.0 0.0 0.0 1.0]
    volume = [1, 1, 1, 1]
    body = Body(position, volume)

    # test body creation
    @test body.n_points == 4
    @test body.position == position
    @test body.volume == volume
    @test body.failure_allowed == BitVector(fill(true, 4))
    @test isa(body.psh, Peridynamics.PointSetHandler{Peridynamics.AbstractMaterial})

    # add point set
    point_set!(body, :a, 1:2)
    @test body.psh.point_sets == Dict(:a => 1:2)

    # add material
    mat = BBMaterial(horizon=1, E=1, rho=1, Gc=1)
    material!(body, mat)
    @test isa(body.psh, Peridynamics.PointSetHandler{Peridynamics.BBMaterial})
    @test material_type(body.psh) == Peridynamics.BBMaterial
    @test body.psh.materials == Dict(:__all__ => BBMaterial(horizon=1, E=1, rho=1, Gc=1))

    # add material to set
    mat2 = BBMaterial(horizon=2, E=2, rho=2, Gc=2)
    material!(body, :a, mat2)
    @test isa(body.psh, Peridynamics.PointSetHandler{Peridynamics.BBMaterial})
    @test material_type(body.psh) == Peridynamics.BBMaterial
    @test body.psh.materials == Dict(:__all__ => BBMaterial(horizon=1, E=1, rho=1, Gc=1),
               :a => BBMaterial(horizon=2, E=2, rho=2, Gc=2))
end

## velocity boundary conditions
let
    # setup
    position = [0.0 1.0 0.0 0.0
                0.0 0.0 1.0 0.0
                0.0 0.0 0.0 1.0]
    volume = [1, 1, 1, 1]
    body = Body(position, volume)

    # test body creation
    @test body.n_points == 4
    @test body.position == position
    @test body.volume == volume
    @test body.failure_allowed == BitVector(fill(true, 4))
    @test isa(body.psh, Peridynamics.PointSetHandler{Peridynamics.AbstractMaterial})

    # add point set
    point_set!(body, :a, 1:2)
    @test body.psh.point_sets == Dict(:a => 1:2)

    # add another point set via function definition
    point_set!(x -> x > 0.5, body, :b)
    @test body.psh.point_sets == Dict(:a => 1:2, :b => [2])

    # add point set with do syntax
    point_set!(body, :c) do p
        p[3] > 0.0
    end
    @test body.psh.point_sets == Dict(:a => 1:2, :b => [2], :c => [4])

    # point_set!
    @test_throws BoundsError point_set!(body, :d, 1:5)

    # add material
    mat = BBMaterial(horizon=1, E=1, rho=1, Gc=1)
    material!(body, mat)
    @test isa(body.psh, Peridynamics.PointSetHandler{Peridynamics.BBMaterial})
    @test material_type(body.psh) == Peridynamics.BBMaterial

    # velocity bc 1
    velocity_bc!(t -> 1, body, :a, 1)
    @test length(body.single_dim_bcs) == 1
    bc1 = body.single_dim_bcs[1]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc1.fun(t) == 1
    end
    @test bc1.field === :velocity_half
    @test bc1.point_set === :a
    @test bc1.dim == 0x01

    # velocity bc 2
    velocity_bc!(t -> 2, body, :a, 2)
    @test length(body.single_dim_bcs) == 2
    bc2 = body.single_dim_bcs[2]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc2.fun(t) == 2
    end
    @test bc2.field === :velocity_half
    @test bc2.point_set === :a
    @test bc2.dim == 0x02

    # velocity bc 3
    velocity_bc!(t -> 3, body, :a, 3)
    @test length(body.single_dim_bcs) == 3
    bc3 = body.single_dim_bcs[3]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc3.fun(t) == 3
    end
    @test bc3.field === :velocity_half
    @test bc3.point_set === :a
    @test bc3.dim == 0x03

    # velocity bc 4
    velocity_bc!(t -> 4, body, :b, :x)
    @test length(body.single_dim_bcs) == 4
    bc4 = body.single_dim_bcs[4]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc4.fun(t) == 4
    end
    @test bc4.field === :velocity_half
    @test bc4.point_set === :b
    @test bc4.dim == 0x01

    # velocity bc 5
    velocity_bc!(t -> 5, body, :b, :y)
    @test length(body.single_dim_bcs) == 5
    bc5 = body.single_dim_bcs[5]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc5.fun(t) == 5
    end
    @test bc5.field === :velocity_half
    @test bc5.point_set === :b
    @test bc5.dim == 0x02

    # velocity bc 6
    velocity_bc!(t -> 6, body, :b, :z)
    @test length(body.single_dim_bcs) == 6
    bc6 = body.single_dim_bcs[6]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc6.fun(t) == 6
    end
    @test bc6.field === :velocity_half
    @test bc6.point_set === :b
    @test bc6.dim == 0x03
end

## force density boundary conditions
let
    # setup
    position = [0.0 1.0 0.0 0.0
                0.0 0.0 1.0 0.0
                0.0 0.0 0.0 1.0]
    volume = [1, 1, 1, 1]
    body = Body(position, volume)

    # add point set
    point_set!(body, :a, 1:2)
    @test body.psh.point_sets == Dict(:a => 1:2)

    # add another point set via function definition
    point_set!(x -> x > 0.5, body, :b)
    @test body.psh.point_sets == Dict(:a => 1:2, :b => [2])

    # velocity bc 1
    forcedensity_bc!(t -> 1, body, :a, 1)
    @test length(body.single_dim_bcs) == 1
    bc1 = body.single_dim_bcs[1]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc1.fun(t) == 1
    end
    @test bc1.field === :b_ext
    @test bc1.point_set === :a
    @test bc1.dim == 0x01

    # velocity bc 2
    forcedensity_bc!(t -> 2, body, :a, 2)
    @test length(body.single_dim_bcs) == 2
    bc2 = body.single_dim_bcs[2]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc2.fun(t) == 2
    end
    @test bc2.field === :b_ext
    @test bc2.point_set === :a
    @test bc2.dim == 0x02

    # velocity bc 3
    forcedensity_bc!(t -> 3, body, :a, 3)
    @test length(body.single_dim_bcs) == 3
    bc3 = body.single_dim_bcs[3]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc3.fun(t) == 3
    end
    @test bc3.field === :b_ext
    @test bc3.point_set === :a
    @test bc3.dim == 0x03

    # velocity bc 4
    forcedensity_bc!(t -> 4, body, :b, :x)
    @test length(body.single_dim_bcs) == 4
    bc4 = body.single_dim_bcs[4]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc4.fun(t) == 4
    end
    @test bc4.field === :b_ext
    @test bc4.point_set === :b
    @test bc4.dim == 0x01

    # velocity bc 5
    forcedensity_bc!(t -> 5, body, :b, :y)
    @test length(body.single_dim_bcs) == 5
    bc5 = body.single_dim_bcs[5]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc5.fun(t) == 5
    end
    @test bc5.field === :b_ext
    @test bc5.point_set === :b
    @test bc5.dim == 0x02

    # velocity bc 6
    forcedensity_bc!(t -> 6, body, :b, :z)
    @test length(body.single_dim_bcs) == 6
    bc6 = body.single_dim_bcs[6]
    for t in [-1, 0, 1, Inf, NaN]
        @test bc6.fun(t) == 6
    end
    @test bc6.field === :b_ext
    @test bc6.point_set === :b
    @test bc6.dim == 0x03
end

## point sets predefined crack
let
    # setup
    position = [0.0 1.0 0.0 0.0
                0.0 0.0 1.0 0.0
                0.0 0.0 0.0 1.0]
    volume = [1, 1, 1, 1]
    body = Body(position, volume)

    # test body creation
    @test body.n_points == 4
    @test body.position == position
    @test body.volume == volume
    @test body.failure_allowed == BitVector(fill(true, 4))
    @test isa(body.psh, Peridynamics.PointSetHandler{Peridynamics.AbstractMaterial})

    # add point set
    point_set!(body, :a, 1:2)
    @test body.psh.point_sets == Dict(:a => 1:2)

    # add another point set via function definition
    point_set!(x -> x > 0.5, body, :b)
    @test body.psh.point_sets == Dict(:a => 1:2, :b => [2])

    # add point set with do syntax
    point_set!(body, :c) do p
        p[3] > 0.0
    end
    @test body.psh.point_sets == Dict(:a => 1:2, :b => [2], :c => [4])

    # precrack! with set :a and :c
    precrack!(body, :a, :c)
    @test body.point_sets_precracks == [Peridynamics.PointSetsPreCrack(:a, :c)]

    # precrack! with set :a and :c
    @test_throws ArgumentError precrack!(body, :a, :b)
end
