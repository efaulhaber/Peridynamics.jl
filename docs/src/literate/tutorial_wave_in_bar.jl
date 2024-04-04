# # Pressure wave in bar

# In this tutorial, a cuboid bar is created.
# A velocity pulse in the form of one period of a sine wave is applied to create
# a pressure wave that propagates through the bar.
#
# First import the Peridynamics.jl package:
using Peridynamics

# To get started, some parameters used to for this simulation are defined.
# These are the length of the bar `lx`, the width and height `lyz` and the number of
# points in the width `npyz`.

lx = 0.2
lyz = 0.002
npyz = 4

# With these parameters the point spacing can be calculated:
Δx = lyz / npyz
# A cuboid body according to the ordinary state-based model with the specified dimensions
# and point spacing is then created:
pos, vol = uniform_box(lx, lyz, lyz, Δx)
body = Body(OSBMaterial(), pos, vol)
# Failure is prohibited throughout the body:
failure_permit!(body, false)
# Following material parameters are specified:

# | material parameter | value |
# |:--------|:-------------|
# | Horizon $ δ $ | $3.015 \cdot Δx$ |
# | Density $ρ$ | $ 7850\,\mathrm{kg}\,\mathrm{m}^{-3}$ |
# | Young's modulus $E$ | $ 210 \, \mathrm{GPa}$ |
# | Poisson's ratio $ν$ | $0.25$ |
# | critical strain $ε_c$ | $0.01$ |
material!(body, horizon=3.015Δx, rho=7850.0, E=210e9, nu=0.25, epsilon_c=0.01)
# Point set `:left` including the first row of points in x-direction is created:
point_set!(x -> x < -lx / 2 + 1.2Δx, body, :left)
# The velocity boundary condition of the form
# ```math
#     {v}_x (t) =
#     \begin{cases}
#         v_\mathrm{max} \cdot \sin(2\pi \cdot \frac{t}{T}) \qquad
#         & \forall \; 0 \leq t \leq T \\
#         0 &\text{else}
#     \end{cases}
# ```
# is applied to point set `:left`. The parameters used for this excitation are period
# length `T` and amplitude `vmax`.
T, vmax = 1.0e-5, 2.0
velocity_bc!(t -> t < T ? vmax * sin(2π / T * t) : 0.0, body, :left, :x)
# ![](../assets/impact_velocity.png)
# The Velocity Verlet algorithm is used as time integration method and 2000 time steps
# are calculated:
vv = VelocityVerlet(steps=2000)
# Then the storage path is defined:
path = joinpath(@__DIR__, "results", "xwave", "xwave_osb")
# The job is now defined and returned with the specified settings and parameters.
job = Job(body, vv; path=path)

# The last step is submitting the job to start the simulation.
#md # ```julia
#md # submit(job);
#md # ```
