using CalculusWithJulia, ForwardDiff
using .Threads
using Random
using Plots 
using ProgressBars

Random.seed!(3)

# Define an "ABPsEnsemble" Type
abstract type ABPsEnsemble end

# Define a specific type for 2D ABPsEnsembles (CURRENTLY ASSUMING ALL PARTICLES ARE EQUAL)
mutable struct ABPE2 <: ABPsEnsemble
    Np::Int64                      # number of particles®®
    L::Float64                      # size of observation space (μm)
	R::Float64  # Radius (μm)                                   --> Vector{Float64}(undef,Np)
	v::Float64 	# velocity (μm/s)                               --> Vector{Float64}(undef,Np)
	DT::Float64 # translational diffusion coefficient (μm^2/s)  --> Vector{Float64}(undef,Np)
	DR::Float64 # rotational diffusion coefficient (rad^2/s)    --> Vector{Float64}(undef,Np)
	x::Vector{Float64}    # x position (μm)
	y::Vector{Float64}    # y position (μm)
	θ::Vector{Float64}    # orientation (rad)
end


#---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Initialize ABP ensemble (CURRENTLY ONLY 2D)

#------------------------------------------------------------For ellipse ---------------------------------------------------------------------------------------------------------
function initABPE_ellipse(Np::Int64, L::Float64, R::Float64, v::Float64; T::Float64=300.0, η::Float64=1e-3)
    # translational diffusion coefficient [m^2/s] & rotational diffusion coefficient [rad^2/s] - R [m]
    # Intial condition will be choosen as per the geometry under study
    DT, DR = diffusion_coeff(1e-6R)

    # ONLY 2D!
    k=0.5
    xyθ1 = (rand(Np,3).-k).*repeat([L L 2π],Np) # 3 dim matrix with x, y and θ 
    r = (xyθ1[:,1]).*(xyθ1[:,1]) + (xyθ1[:,2]).*(xyθ1[:,2])
  
    rₚ = sqrt.(r)   
    α =atan.(xyθ1[:,2], xyθ1[:,1]) 
    a= L/2
        b= L/4
    #rₑ = (a*b)./(sqrt.(((a*sin.(xyθ1[:,3])).^2) .+ (b*cos.((xyθ1[:,3]))).^2))  # r value for boundary
    rₑ = (a-R)*(b-R)./(sqrt.((((a-R)*sin.(α)).^2) .+ ((b-R)*cos.((α))).^2))  # r value for boundary
    #rₑ = b/sqrt.(1 .-((e*cos.(rθ)).^2))
    id = (rₚ .< (rₑ))
    xyθ = [xyθ1[id,1] xyθ1[id,2] xyθ1[id,3]]

    Np1= size(xyθ,1)    # number of particles inside the boundary while Np is total number of particles
    #xyθ = (rand(Np,3).-0.0).*repeat([L L 2π],Np)
    xyθ[:,1:2], dists, superpose, uptriang = hardsphere(xyθ[:,1:2],R) #xyθ[:,1:2] gives x and y positions of intitial particles
    abpe = ABPE2( Np1, L, R, v, 1e12DT, DR, xyθ[:,1], xyθ[:,2], xyθ[:,3])

    # println("INIT ELLIPSE")
    return abpe, (dists, superpose, uptriang)
end

#------------------------------------------------------------For square ---------------------------------------------------------------------------------------------------------
function initABPE_square(Np::Int64, L::Float64, R::Float64, v::Float64; T::Float64=300.0, η::Float64=1e-3, N::Integer, M::Integer)
    # translational diffusion coefficient [m^2/s] & rotational diffusion coefficient [rad^2/s] - R [m]
    # Intial condition will be choosen as per the geometry under study
    DT, DR = diffusion_coeff(1e-6R)

    # ONLY 2D!
    k=0.5
    xyθ = (rand(Np,3).-k).*repeat([L L 2π],Np) # 3 dim matrix with x, y and θ 
   

    Np= size(xyθ,1)    # number of particles inside the sqaure
    #xyθ = (rand(Np,3).-0.0).*repeat([L L 2π],Np)
    xyθ[:,1:2], dists_list, superpose_list, uptriang = hardsphere(xyθ[:,1:2],R; N, M) #xyθ[:,1:2] gives x and y positions of intitial particles
    abpe = ABPE2( Np, L, R, v, 1e12DT, DR, xyθ[:,1], xyθ[:,2], xyθ[:,3])

    # println("INIT SQUARE")
    return abpe, (dists_list, superpose_list, uptriang)
end


#---------------------------------------------------------------------------------------------------------------------------------------------------------------------
##Calculate diffusion coefficient

function diffusion_coeff(R::Float64, T::Float64=300.0, η::Float64=1e-3)
    # Boltzmann constant [J/K]
    kB = 1.38e-23
    # friction coefficient [Ns/m]
    γ = 6*pi*R*η
    # translational diffusion coefficient [m^2/s]
    DT = kB*T/γ
    # rotational diffusion coefficient [rad^2/s]
    DR = 6*DT/(8*R^2)
    return DT, DR
end;


#---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Functions to simulate multiple spherical particles

function multiparticleE(;Np::Integer, L::Float64, R::Float64, v::Float64, Nt::Int64=2, δt::Float64=1e-3, N::Integer=16, M::Integer=16)
    (Nt isa Int64) ? Nt : Nt=convert(Int64,Nt)
    
    ABPE = Vector{ABPE2}(undef,Nt+1) # Nt is number of time steps
    ABPE[1], matrices = initABPE_square( Np, L, R, v; N, M) # including initial hardsphere correction
    
    simulate!(ABPE, matrices, Nt, δt; N, M)

    return position.(ABPE), orientation.(ABPE)
end


function simulate!(ABPE, matrices, Nt, δt; N, M)
    # PΘ = [ (position(abpe), orientation(abpe)) ]
    # pθ = PΘ[1]
    
    for nt in ProgressBar(1:Nt)
        ABPE[nt+1] = update(ABPE[nt],matrices,δt; N, M) #updating information at every step
        # println("Step $nt")
    end
    return nothing
end

position(abpe::ABPE2) = [ abpe.x abpe.y ]
orientation(abpe::ABPE2) = abpe.θ


#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Functions to update particles for the next step

function update(abpe::ABPE, matrices::Tuple{Vector{Matrix{Float64}}, Vector{BitMatrix}, BitMatrix}, δt::Float64; N::Integer, M::Integer) where {ABPE <: ABPsEnsemble}
    pθ = ( position(abpe), orientation(abpe) ) .+ step(abpe,δt)

    periodic_BC_array!(pθ[1], abpe.L, abpe.R)
    #circular_wall_condition!(pθ[1],L::Float64, R, step_mem::Array{Float64,2})
    hardsphere!(pθ[1], matrices[1], matrices[2], matrices[3], abpe.R; N=N, M=M)
    # @btime hardsphere!($p[:,1:2], $matrices[1], $matrices[2], $matrices[3], $params.R)
    new_abpe = ABPE2( abpe.Np, abpe.L, abpe.R, abpe.v, abpe.DT, abpe.DR, pθ[1][:,1], pθ[1][:,2], pθ[2] )

    return new_abpe
end


function step(abpe::ABPE, δt::Float64) where {ABPE <: ABPsEnsemble}
    
    if size(position(abpe),2) == 2
        δp = sqrt.(2*δt*abpe.DT)*randn(abpe.Np,2) .+ abpe.v*δt*[cos.(abpe.θ) sin.(abpe.θ)]
        δθ = sqrt(2*abpe.DR*δt)*randn(abpe.Np)
    else
        println("No step method available")
    end
    #if nt == 1 
        #println("lo step vero di questo giro è: $δp") 
    #end
    return (δp, δθ)
end


#---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Functions for the hard sphere corrections

# function indices_per_cell(xy, R, tol, x_min, x_max, y_min, y_max, N, M)
function indices_per_cell(xy, R, tol, N, M)
    # partition xy in order to perform parallel computation
    # the limits of the region to be divided are the maximum values of xy for both dimensions
    # which avoids empty cells (if the region was the entire space)
    indices_partition = [Array{Integer}([]) for _=1:N*M]
    # little margin
    # ϵ = 0.1
    # x_max = maximum(xy[:,1]) + ϵ
    # y_min = minimum(xy[:,2]) - ϵ
    # y_max = maximum(xy[:,2]) + ϵ
    # x_min = minimum(xy[:,1]) - ϵ
    # N_cap = min(N, floor(Int, floor((y_max - y_min) / (4R*(1-tol)))))
    # M_cap = min(M, floor(Int, floor((x_max - x_min) / (4R*(1-tol)))))
    # cell_height = (y_max - y_min) / N_cap
    # cell_width = (x_max - x_min) / M_cap

    # size of the cells given by the considered region and their number
    ϵ = 3
    x_min = -50 - ϵ
    x_max = 50 + ϵ
    y_min = -50 - ϵ
    y_max = 50 + ϵ

    if(N >= (y_max - y_min) / (4R * (1-tol)))
        throw("N must be smaller, possible overlapping between parallel computed regions")
    elseif(M >= (x_max - x_min) / (4R * (1-tol)))
        throw("M must be smaller, possible overlapping between parallel computed regions")
    end

    cell_height = (y_max - y_min) / N
    cell_width = (x_max - x_min) / M

    for i in axes(xy, 1)
        for n=1:N
            for m=1:M
                # we overlap the regions with border 2R*(1-tol), otherwise collisions at the border of the cells will never be detected 
                if((xy[i,1] > x_min + (m-1)*cell_width) && (xy[i,1] < x_min + m*cell_width) && (xy[i,2] > y_min + (n-1)*cell_height) && (xy[i,2] < y_min + n*cell_height))
                # if((xy[i,1] > x_min + (m-1)*cell_width - 2R*(1-tol)) && (xy[i,1] < x_min + m*cell_width + 2R*(1-tol)) && (xy[i,2] > y_min + (n-1)*cell_height - 2R*(1-tol)) && (xy[i,2] < y_min + n*cell_height + 2R*(1-tol)))
                    push!(indices_partition[(n-1)*M + m], i)
                end 
            end
        end
    end
    lx = [x_min + m*cell_width for m=0:M]
    ly = [y_min + n*cell_height for n=0:N]
    return indices_partition, lx, ly
end

function update_superpositions(xy::Array{Float64,2}, cell_index, indices, dists_list::Vector{Matrix{Float64}}, superpose_list::Vector{BitMatrix}, uptriang::BitArray{2}, R::Float64; tol::Float64=1e-3)
    dists_list[cell_index][indices, indices] .= Distances.pairwise(Euclidean(),xy[indices, :],xy[indices, :],dims=1)
    superpose_list[cell_index][indices, indices] .= (dists_list[cell_index][indices, indices] .< 2R*(1-tol)) .* uptriang[indices, indices]
end

function local_hardsphere_correction!(xy::Array{Float64,2}, cell_index, indices, dists_list::Vector{Matrix{Float64}}, superpose_list::Vector{BitMatrix}, R::Float64; tol::Float64=1e-3)
    superpositions = sum(superpose_list[cell_index][indices, indices])
    if(superpositions > 0)
        # Np = size(superpose_list[1][indices, indices],1) # number of particles in the local cell 
        for np1 in indices
            if any(superpose_list[cell_index][np1,indices]) #if at least one value of the np1 row is true 
                # /!\ `findfirst(superpose_list[cell_index][np1,indices])` is giving the np2 position in the matrix
                # restricted to [indices, indices] so we have to take the element at this relative position in indices, hence:
                np2 = indices[findfirst(superpose_list[cell_index][np1,indices])]
                Δp = (xy[np1,:] - xy[np2,:]) .* ( ( (1+tol)*2R / dists_list[cell_index][np1,np2] - 1 ) / 2 )
                xy[np1,:] += Δp
                xy[np2,:] -= Δp
                # dists_list[1][np2,np2+1:Np] = pairwise(Euclidean(), xy[np2:np2,:], xy[np2+1:Np,:], dims=1 )  # distances for the row wise pair operation
                dists_list[cell_index][np2,indices[indices .> np2]] = pairwise(Euclidean(), xy[np2:np2,:], xy[indices[indices .> np2],:], dims=1 )  # distances for the row wise pair operation
                # superpose_list[1][np2,np2+1:Np] = (dists_list[1][np2,np2+1:Np] .< 2R*(1-tol))   
                superpose_list[cell_index][np2,indices[indices .> np2]] = (dists_list[cell_index][np2,indices[indices .> np2]] .< 2R*(1-tol))   
                # dists[np1+1:np2,np2] = pairwise(Euclidean(), xy[np2:np2,:], xy[np1+1:np2,:], dims=1 )  # distances for the row wise pair operation
                # superpose[np1+1:np2,np2] = (dists[np1+1:np2,np2] .< 2R*(1-tol))   
            end
        end
    end
    return superpositions
end

function hardsphere!(
    xy::Array{Float64,2},
    dists_list::Vector{Matrix{Float64}}, superpose_list::Vector{BitMatrix}, uptriang::BitArray{2}, 
    R::Float64; 
    tol::Float64=1e-3, 
    #x_min, x_max, y_min, y_max, 
    N::Integer, M::Integer
    )

    # partition the particles w.r.t. the cells
    # indices_partition, lx, ly = indices_per_cell(xy, R, tol, x_min, x_max, y_min, y_max, N, M)
    indices_partition, lx, ly = indices_per_cell(xy, R, tol, N, M)
    # println(indices_partition)
    # keep a trace of the number of superpositions per cell in the partition
    # (the threads will access it separately)
    superposition_partition = zeros(Int, length(indices_partition))
    # initialized as 1 to pass the while loop condition at first iteration
    superpositions = 1
    # set a limit to avoid to much hardsphere correction iterations
    counter = 0
    # @time begin
    even_even_cells_indices = [] 
    even_odd_cells_indices = []
    odd_even_cells_indices = [] 
    odd_odd_cells_indices = []
    for i in eachindex(indices_partition)
        # to switch from linear to row / colum indexing and then check parity of vertical / horizontal index
        if (iseven(((i-1) ÷ M) + 1) && iseven(((i-1) % M) + 1)) 
            push!(even_even_cells_indices,i)
        elseif (iseven(((i-1) ÷ M) + 1) && isodd(((i-1) % M) + 1)) 
            push!(even_odd_cells_indices,i)
        elseif (isodd(((i-1) ÷ M) + 1) && iseven(((i-1) % M) + 1)) 
            push!(odd_even_cells_indices,i)
        else push!(odd_odd_cells_indices,i) 
        end
    end

    # # Particles indices in the different partity groups 
    # ee = collect(Iterators.flatten(indices_partition[even_even_cells_indices]))
    # eo = collect(Iterators.flatten(indices_partition[even_odd_cells_indices]))
    # oe = collect(Iterators.flatten(indices_partition[odd_even_cells_indices]))
    # oo = collect(Iterators.flatten(indices_partition[odd_odd_cells_indices]))

    # println(even_even_cells_indices)
    # println(even_odd_cells_indices)
    # println(odd_even_cells_indices)
    # println(odd_odd_cells_indices)
    # println(indices_partition)

    # # verify that there are no particles in to regions with different parities at the same time 
    # println("intersection ee eo : $(intersect(ee, eo))\n")
    # println("intersection ee oe : $(intersect(ee, oe))\n")
    # println("intersection ee oo : $(intersect(ee, oo))\n")
    # println("intersection eo oe : $(intersect(eo, oe))\n")
    # println("intersection eo oo : $(intersect(eo, oo))\n")
    # println("intersection oe oo : $(intersect(oe, oo))\n")
    
    # to visualize cells division
    # scatter(xy[:,1], xy[:,2], aspect_ratio=:equal, lims=(-100/2, 100/2), markersize=350*R/100., marker =:circle, series_annotations = text.(1:length(xy[:,1]), :bottom), legend=false, title = nothing, show=true)
    # scatter(xy[:,1], xy[:,2], aspect_ratio=:equal, lims=(-100/2, 100/2), markersize=350*R/100., legend=false, title = nothing, show=true)
    # hline!(ly, color=:red)
    # hline!(ly .+ 2R*(1-tol), color=:orange)
    # hline!(ly .- 2R*(1-tol), color=:orange)
    # vline!(lx, color=:red)
    # vline!(lx .- 2R*(1-tol), color=:orange)
    # vline!(lx .+ 2R*(1-tol), color=:orange)
    
    # display(current())
    # sleep(0.3)

    while superpositions > 0
        # @show(superpositions)
        # reset superpositions count
        superposition_partition = zero(superposition_partition)
        superpositions = 0
        # for cell_index in eachindex(indices_partition) 
        #     # ~ THREADING for the update of the matrices
        #     update_superpositions(xy, cell_index, indices_partition[cell_index], dists_list, superpose_list, uptriang, R; tol=tol)
        # end
        for parity_cell_indices in [even_even_cells_indices, even_odd_cells_indices, odd_even_cells_indices, odd_odd_cells_indices]
            for cell_index in parity_cell_indices
                # superposition_partition[cell_index] += local_hardsphere_correction!(xy, cell_index, indices_partition[cell_index], dists_list, superpose_list, uptriang, R; tol=tol)
                @threads update_superpositions(xy, cell_index, indices_partition[cell_index], dists_list, superpose_list, uptriang, R; tol=tol)
                superposition_partition[cell_index] += local_hardsphere_correction!(xy, cell_index, indices_partition[cell_index], dists_list, superpose_list, R; tol=tol)
            end
        end
        # sum superpositions for each cell   
        superpositions = sum(superposition_partition)  
        counter += 1
        if counter >= 100
            println("$superpositions superpositions remaining after 100 cycles")
            break
        end
        # @show(counter)
    end
    # if(Inf ∈ xy[:,1] || Inf ∈ xy[:,2] || -Inf ∈ xy[:,1] || -Inf ∈ xy[:,2])
    #     println("INF!")
    # end
    
    for i in eachindex(dists_list) dists_list[i] = zero(dists_list[i]) end
    for i in eachindex(superpose_list) superpose_list[i] = zero(superpose_list[i]) end
    
    return nothing
end

function hardsphere(xy::Array{Float64,2}, R::Float64; tol::Float64=1e-3, N::Integer, M::Integer) # called in initABPE
    Np = size(xy,1)
    dists_list = [zeros(Np,Np) for _=1:N*M]
    superpose_list = [falses(Np,Np) for _=1:N*M]
    uptriang = falses(Np,Np)
    for i = 1:Np-1
        uptriang[i,i+1:Np] .= true
    end
    hardsphere!(xy, dists_list, superpose_list, uptriang, R; tol=tol, N=N, M=M)
    return xy, dists_list, superpose_list, uptriang
end
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function periodic_BC_array!(xy::Array{Float64,2},L::Float64, R)   #when a particle crosses an edge it reappears on the opposite side
	# Boundary conditions: horizontal edge
	idx = abs.(xy[:,1]) .> L/2 + R #I create vector idx in which I have 1 where the absolute value of the x coordinate of the particles is outside the observation area
	if any(idx)
		xy[idx,1] .-= sign.(xy[idx,1]).*L   #where I have uni in idx I make the particle reappear on the opposite side of x with respect to 0
	end
	# Boundary conditions: vertical edge
	idy = abs.(xy[:,2]) .> L/2 + R
	if any(idy)
		xy[idy,2] .-= sign.(xy[idy,2]).*L
	end
    # println("I am in periodic")
	return nothing
end


# --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#  Functions for updating reflective boundary AND WALL UPDATE

function multiparticleE_wall(;Np::Integer, L::Float64, R::Float64, v::Float64, Nt::Int64=2, δt::Float64=1e-3, wall_condition::String)
    (Nt isa Int64) ? Nt : Nt=convert(Int64,Nt)
    
    ABPE = Vector{ABPE2}(undef,Nt+1)
    if(wall_condition=="elliptical")
        ABPE[1], matrices = initABPE_ellipse( Np, L, R, v ) # including initial hardsphere correction
    elseif(wall_condition in ["periodic", "squared"])
        ABPE[1], matrices = initABPE_square( Np, L, R, v ) 
    else
        throw(ArgumentError("please provide a correct argument for wall condition"))
    end

    simulate_wall!(ABPE, matrices, Nt, δt, wall_condition)
    # println("I am in multiwall update")
    return position.(ABPE), orientation.(ABPE)
end

function simulate_wall!(ABPE, matrices, Nt, δt, wall_condition)
    # PΘ = [ (position(abpe), orientation(abpe)) ]
    # pθ = PΘ[1]
    
    for nt in 1:Nt
        ABPE[nt+1] = update_wall(ABPE[nt],matrices,δt, wall_condition)
        #println("Step $nt")
      
    end
    return nothing
end

function update_wall(abpe::ABPE, matrices::Tuple{Matrix{Float64}, BitMatrix, BitMatrix}, δt::Float64, wall_condition::String) where {ABPE <: ABPsEnsemble}
    memory_step = step(abpe,δt)
  
    pθ = ( position(abpe), orientation(abpe) ) .+ memory_step
    
    # wall condition choice
    if(wall_condition == "squared")
        wall_condition!(pθ[1],abpe.L, abpe.R, memory_step[1])    
    elseif(wall_condition == "elliptical")
        elliptical_wall_condition!(pθ[2],pθ[1],abpe.L, abpe.R, memory_step[1])
    else
        throw(ArgumentError("please provide a correct argument for wall condition"))
    #elliptical_wall_condition!(pθ[1],abpe.L, abpe.R, memory_step[1])
    end
    hardsphere!(pθ[1], matrices[1], matrices[2], matrices[3], abpe.R)
    # @btime hardsphere!($p[:,1:2], $matrices[1], $matrices[2], $matrices[3], $params.R)
    new_abpe = ABPE2( abpe.Np, abpe.L, abpe.R, abpe.v, abpe.DT, abpe.DR, pθ[1][:,1], pθ[1][:,2], pθ[2] )

    return new_abpe
end

function wall_condition!(xy::Array{Float64,2},L::Float64, R, step_mem::Array{Float64,2}) # this condition is for square reflective boundary
  
	# Boundary conditions: horizontal edge
	idx = abs.(xy[:,1]) .> (L/2 - R)
	if any(idx)
		xy[idx,1] .-= 2*sign.(xy[idx,1]).*(abs.(xy[idx,1]) .- (L/2 - R)) 
	end
	# Boundary conditions: vertical edge
	idy = abs.(xy[:,2]) .> (L/2 - R)
	if any(idy)
        xy[idy,2] .-= 2*sign.(xy[idy,2]).*(abs.(xy[idy,2]) .- (L/2 - R))
	end
    # println("I am in square wall")
	return nothing
end

function circular_wall_condition!(xy::Array{Float64,2},L::Float64, R, step_mem::Array{Float64,2}) # this condition is for cicular reflective boundary
  # here the condition is calculated w.r.t to r value of the particle and have no edges here
  # this is first method used 
     
    r = (xy[:,1]).*(xy[:,1]) + (xy[:,2]).*(xy[:,2])

    rr = sqrt.(r)

    rθ= atan.(xy[:,2], xy[:,1])   # angle which the particle make with the origin 
     
    id = rr.> (L/2 - R)        # checking the condition for r vector id = 1 when true, 0 when false
    
    Δr = zeros(length(r),1)
    #println("$id")
             
        Δr[id] = rr[id].- (L/2 - R)
        rr.-= 2*(Δr)
        #println(size(rr)) # gives size of an array
        xy[id,1] = rr[id].*(cos.(rθ[id]))
        xy[id,2] = rr[id].*(sin.(rθ[id]))


	
	#println("I am in circular wall")
	return nothing
end

function circular_wall_condition1g!(xy::Array{Float64,2},L::Float64, R, step_mem::Array{Float64,2}) # this condition is for cicular reflective boundary
    # here the condition is calculated w.r.t to the normal at the intersection point of the radial distance with the wall
    # this is second method used 
       
      r = (xy[:,1]).*(xy[:,1]) + (xy[:,2]).*(xy[:,2])
  
      rr = sqrt.(r)
  
      rθ= atan.(xy[:,2], xy[:,1])   # angle which the particle make with the origin 
       
      id = rr.> (L/2 - R)        # checking the condition for r vector id = 1 when true, 0 when false
      
      correction = zeros(length(r),1)
      projection = zeros(length(r),1)
      inside = zeros(length(r),1)
      hat_normal = zeros(length(r),1)
      x = [[p[1],p[2]] for p in eachrow(xy)]
      
      function grad(x::Array{Float64},R::Float64)
       f(x) = x[1]^2 + x[2]^2 - (L*L)/4
       df=ForwardDiff.gradient(f, [x[1],x[2]])
       return df
    end
    normal = grad.(x,R)
     
    hat_normal = normal./norm.(normal)  # unit normal vector
   
    correction = (rr.-(L/2 - 2*R)).*[[cos.(θ),sin.(θ)] for θ in rθ]
    
    projection = dot.(correction,hat_normal)
                                  
    
    inside = (0.5*L.-1*projection).*[[cos.(θ),sin.(θ)] for θ in rθ]         # the vector which is inside the boundry now
      #println("$id")

      xpos= [p[1] for p in inside]

      ypos= [p[2] for p in inside]
          
          xy[id,1] = xpos[id,1]
          xy[id,2] = ypos[id,1]
  
        # println("I am in circular wall 1g")
    
      return nothing
  end

function elliptical_wall_condition!(orientation::Array{Float64,1},xy::Array{Float64,2},L::Float64, R, step_mem::Array{Float64,2}) # this condition is for cicular reflective boundary
    # here the condition is calculated w.r.t to the normal at the intersection point of the radial distance with the wall
    # this is second method used 
    # orientation of particle will also change   
        a= L/2
        b= L/4

        a1= a-R
        b1= b-R
         
        #e = sqrt(1-(b/a)^2)
      r = (xy[:,1]).*(xy[:,1]) + (xy[:,2]).*(xy[:,2])
  
      rₚ = sqrt.(r)                # particle r co ordinate
  
      rθ= atan.(xy[:,2], xy[:,1])   # angle which the particle make with the origin 

      rₒ = ((a*b)./(sqrt.(((a*sin.(rθ)).^2) .+ (b*cos.(rθ)).^2)))

      rₑ = rₒ .- R
   
      #rₑ = b/sqrt.(1 .-((e*cos.(rθ)).^2))
      id = (rₚ .> (rₑ))
    
      x = [[p[1],p[2]] for p in eachrow(xy)]
      
      function grad(x::Array{Float64},a::Float64,b::Float64)
        
       f(x) = (x[1]^2)*b^2 + (x[2]^2)*a^2 - (a*b)^2
       df=ForwardDiff.gradient(f, [x[1],x[2]])
       return df
       end
    normal = grad.(x,a1,b1)     # gradient calculated from each particle position onto the ellipse boundary 
     
    hat_normal = normal./norm.(normal)  # unit normal vector

    
    correction_x = (rₚ .- rₑ) .*[(cos.(θ)) for θ in rθ]

    correction_y = (rₚ .- rₑ) .*[(sin.(θ)) for θ in rθ]
    
    c= [correction_x correction_y]

    correction = [[p[1],p[2]] for p in eachrow(c)]
  
    projection = dot.(correction,hat_normal)


    cᵥ = 2*(projection.+0*R).* hat_normal #vector of vector
    # to access this vector I am breaking it in x and y in the following lines

    cᵥx =  [p[1] for p in cᵥ]

    cᵥy =  [p[2] for p in cᵥ]
############################# calculations for orientation vector###############################
###########################3 conversion of vector into matrix was job of this part###########################
        xy[id,1] .-= cᵥx[id]
        xy[id,2] .-= cᵥy[id]

    # println("I am in elliptical wall")
      return nothing
  end
