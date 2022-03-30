####################
## Phantom OBJECT ##
####################
"""
    Phantom(x,y,ρ,T2,Δw,Dλ1,Dλ2,Dθ,ux,uy)

Phantom object.

# Arguments
 - `name::String` := Name of the Phantom
 - `x`            := Spins x-coordinates.
 - `y`            := Spins y-coordinates.
 - `z`            := Spins z-coordinates.
 - `ρ::Matrix`    := Proton density.
 - `T1::Matrix`   := T1 map.
 - `T2::Matrix`   := T2 map.
 - `Δw::Matrix`   := Off-resonace map;
 - `D::Matrix`    := Diffusion model.
 - `ux::Function` := Displacement field x.
 - `uy::Function` := Displacement field y.
 - `uz::Function` := Displacement field z.
"""
@with_kw mutable struct Phantom
	name::String = "spin" #Name of the Phantom
	x::Vector #x-coordinates of spins
	y::Vector = zeros(size(x)) #y-coordinates of spins
	z::Vector = zeros(size(x)) #z-coordinates of spins
	ρ::Vector = ones(size(x)) #proton density
	T1::Vector = Inf*ones(size(x)) #T1 map
	T2::Vector = Inf*ones(size(x)) #T2 map
	T2s::Vector = T2
	#Off-resonance related
	Δw::Vector = zeros(size(x)) #Off-resonace map
	#χ::Vector{SusceptibilityModel}
	#Diffusion
	Dλ1::Vector = zeros(size(x))
	Dλ2::Vector = zeros(size(x))
	Dθ::Vector = zeros(size(x))
	#Diff::Vector{DiffusionModel}  #Diffusion map
	#Motion
	ux::Function = (x,y,z,t)->0 #Displacement field x
	uy::Function = (x,y,z,t)->0 #Displacement field y
	uz::Function = (x,y,z,t)->0 #Displacement field z
end

# Phantom() = Phantom(name="spin",x=zeros(1,1))
size(x::Phantom) = size(x.ρ)
"""Separate object spins in a sub-group."""
Base.getindex(obj::Phantom, p::UnitRange{Int}) = begin
	Phantom(name=obj.name,
			x=obj.x[p],
			y=obj.y[p],
			z=obj.z[p],
			ρ=obj.ρ[p],
			T1=obj.T1[p],
			T2=obj.T2[p],
			T2s=obj.T2s[p],
			Δw=obj.Δw[p],
			#Diff=obj.Diff[p], #TODO!
			Dλ1=obj.Dλ1[p],
			Dλ2=obj.Dλ2[p],
			Dθ=obj.Dθ[p],
			#Χ=obj.Χ[p], #TODO!
			ux=obj.ux,
			uy=obj.uy,
			uz=obj.uz
			)
end
# Compartment enabling routines:
# Addition of compartments
+(s1::Phantom,s2::Phantom) =begin
	Phantom(name=s1.name*"+"*s2.name,
		x=[s1.x;s2.x],
		y=[s1.y;s2.y],
		z=[s1.z;s2.z],
		ρ=[s1.ρ;s2.ρ],
		T1=[s1.T1;s2.T1],
		T2=[s1.T2;s2.T2],
		T2s=[s1.T2s;s2.T2s],
		Δw=[s1.Δw;s2.Δw],
		#Diff=obj.Diff[p], #TODO!
		Dλ1=[s1.Dλ1;s2.Dλ1],
		Dλ2=[s1.Dλ2;s2.Dλ2],
		Dθ=[s1.Dθ;s2.Dθ],
		#Χ=obj.Χ[p], #TODO!
		ux=s1.ux,
		uy=s1.uy,
		uz=s1.uz
	)
end
#Fraction of compartments
*(α::Real,obj::Phantom) = begin
	Phantom(name=obj.name,
		x=obj.x,
		y=obj.y,
		z=obj.z,
		ρ=α*obj.ρ, #Only affects the proton density
		T1=obj.T1,
		T2=obj.T2,
		T2s=obj.T2s,
		Δw=obj.Δw,
		#Diff=obj.Diff[p], #TODO!
		Dλ1=obj.Dλ1,
		Dλ2=obj.Dλ2,
		Dθ=obj.Dθ,
		#Χ=obj.Χ[p], #TODO!
		ux=obj.ux,
		uy=obj.uy,
		uz=obj.uz
	)
end

# Movement related commands
# StartAt(s::Phantom,t0::Float64) = Phantom(s.name,s.x,s.y,s.ρ,s.T2,s.Δw,s.Dλ1,s.Dλ2,s.Dθ,(x,y,t)->s.ux(x,y,t.+t0),(x,y,t)->s.uy(x,y,t.+t0))
# FreezeAt(s::Phantom,t0::Float64) = Phantom(s.name*"STILL",s.x.+s.ux(s.x,s.y,t0),s.y.+s.uy(s.x,s.y,t0),s.ρ,s.T2,s.Δw,s.Dλ1,s.Dλ2,s.Dθ,(x,y,t)->0,(x,y,t)->0)

#TODO: jaw-pitch-roll, expand, contract, functions

# Getting maps
# get_DxDy2D(obj::Phantom) = begin
# 	P(i) = rotz(obj.Dθ[i])[1:2,1:2];
# 	D(i) = [obj.Dλ1[i] 0;0 obj.Dλ2[i]]
# 	nx = [1;0]; ny = [0;1]
# 	Dx = [nx'*P(i)'*D(i)*P(i)*nx for i=1:prod(size(obj.Dλ1))]
# 	Dy = [ny'*P(i)'*D(i)*P(i)*ny for i=1:prod(size(obj.Dλ1))]
# 	Dx, Dy
# end

"""
Heart-like LV phantom. The variable `α` is for strech, `β` for contraction, and `γ` for rotation.
"""
heart_phantom(α=1,β=1,γ=1,fat_bool::Bool=false) = begin
	#PARAMETERS
	FOV = 10e-2 #m Diameter ventricule
	N = 21
	Δxr = FOV/(N-1) #Aprox rec resolution, use Δx_pix and Δy_pix
	Ns = 50 #number of spins per voxel
	Δx = Δxr/sqrt(Ns) #spin separation
	#POSITIONS
	x = y = -FOV/2:Δx:FOV/2-Δx #spin coordinates
	x, y = x .+ y'*0, x*0 .+ y' #grid points
	#PHANTOM
	⚪(R) =  (x.^2 .+ y.^2 .<= R^2)*1. #Circle of radius R
	v = FOV/4 #m/s 1/16 th of the FOV during acquisition
	ωHR = 2π/1 #One heart-beat in one second

	# θ(t) = -π/4*γ*(sin.(ωHR*t).*(sin.(ωHR*t).>0)+0.25.*sin.(ωHR*t).*(sin.(ωHR*t).<0) )
	ux(x,y,t) = begin 
		strech = 0 #α * v * (x.^2 .+ y.^2) / (FOV/2)^2 .* sign.(x)
		contract = - β * v * x / (FOV/2)  #expand
		rotate = - γ * v * y / (FOV/2)
		def = (strech .+ contract .+ rotate) .* sin.(ωHR*t)
	end
	uy(x,y,t) = begin 
		strech = 0 #α * v * (x.^2 .+ y.^2) / (FOV/2)^2 .* sign.(y)
		contract = - β * v * y / (FOV/2)
		rotate = γ * v * x / (FOV/2)
		def = (strech .+ contract .+ rotate) .* sin.(ωHR*t)
	end
	# Water spins
	R = 9/10*FOV/2
	r = 6/11*FOV/2
	ring = ⚪(R) .- ⚪(r)
	ρ = ⚪(r) .+ 0.9*ring #proton density
	# Diffusion tensor model
	D = 2e-9 #Diffusion of free water m2/s
	D1, D2 = D, D/20
	Dλ1 = D1*⚪(R) #Diffusion map
	Dλ2 = D1*⚪(r) .+ D2*ring #Diffusion map
	Dθ =  atan.(x,-y) .* ring #Diffusion map
	T1 = (1400*⚪(r) .+ 1026*ring)*1e-3 #Myocardial T1
	T2 = ( 308*⚪(r) .+ 42*ring  )*1e-3 #T2 map [s]
	# Generating Phantoms
	heart = Phantom("LeftVentricle",x,y,ρ,T2,Dλ1,Dλ2,Dθ,ux,uy)
	# Fat spins
	ring2 = ⚪(FOV/2) .- ⚪(R) #outside fat layer
	ρ_fat = .5*ρ.*ring2
	Δw_fat = 2π*220*ring2 #fat should be dependant on B0
	T1_fat = 800*ring2*1e-3
	T2_fat = 120*ring2*1e-3 #T2 map [s]
	fat = Phantom("fat",x,y,ρ_fat,T2_fat,Δw_fat)
	#Resulting phantom
	obj = fat_bool ? heart + fat : heart #concatenating spins
end

"""
B. Aubert-Broche, D.L. Collins, A.C. Evans: "A new improved version of the realistic digital brain phantom"
NeuroImage, in review - 2006.
B. Aubert-Broche, M. Griffin, G.B. Pike, A.C. Evans and D.L. Collins: "20 new digital brain phantoms for creation of validation image data bases"
IEEE TMI, in review - 2006

https://brainweb.bic.mni.mcgill.ca/brainweb
"""
function brain_phantom2D(;axis="axial",ss=4)
    path = @__DIR__
    data = MAT.matread(path*"/phantom/brain2D.mat")

    class = data[axis][1:ss:end,1:ss:end]
    Δx = .5e-3*ss
    M, N = size(class)
    FOVx = (M-1)*Δx #[m]
    FOVy = (N-1)*Δx #[m]
    x = -FOVx/2:Δx:FOVx/2 #spin coordinates
    y = -FOVy/2:Δx:FOVy/2 #spin coordinates
    x, y = x .+ y'*0, x*0 .+ y' #grid points

    T2 = (class.==23)*329 .+ #CSF
        (class.==46)*83 .+ #GM
        (class.==70)*70 .+ #WM
        (class.==93)*70 .+ #FAT1
        (class.==116)*47 .+ #MUSCLE
        (class.==139)*329 .+ #SKIN/MUSCLE
        (class.==162)*0 .+ #SKULL
        (class.==185)*0 .+ #VESSELS
        (class.==209)*70 .+ #FAT2
        (class.==232)*329 .+ #DURA
        (class.==255)*70 #MARROW
    T2s = (class.==23)*58 .+ #CSF
        (class.==46)*69 .+ #GM
        (class.==70)*61 .+ #WM
        (class.==93)*58 .+ #FAT1
        (class.==116)*30 .+ #MUSCLE
        (class.==139)*58 .+ #SKIN/MUSCLE
        (class.==162)*0 .+ #SKULL
        (class.==185)*0 .+ #VESSELS
        (class.==209)*61 .+ #FAT2
        (class.==232)*58 .+ #DURA
        (class.==255)*61 .+#MARROW
        (class.==255)*70 #MARROW
    T1 = (class.==23)*2569 .+ #CSF
        (class.==46)*833 .+ #GM
        (class.==70)*500 .+ #WM
        (class.==93)*350 .+ #FAT1
        (class.==116)*900 .+ #MUSCLE
        (class.==139)*569 .+ #SKIN/MUSCLE
        (class.==162)*0 .+ #SKULL
        (class.==185)*0 .+ #VESSELS
        (class.==209)*500 .+ #FAT2
        (class.==232)*2569 .+ #DURA
        (class.==255)*500 #MARROW
    ρ = (class.==23)*1 .+ #CSF
        (class.==46)*.86 .+ #GM
        (class.==70)*.77 .+ #WM
        (class.==93)*1 .+ #FAT1
        (class.==116)*1 .+ #MUSCLE
        (class.==139)*1 .+ #SKIN/MUSCLE
        (class.==162)*0 .+ #SKULL
        (class.==185)*0 .+ #VESSELS
        (class.==209)*.77 .+ #FAT2
        (class.==232)*1 .+ #DURA
        (class.==255)*.77 #MARROW
	Δw_fat = -220*2π
	Δw = (class.==93)*Δw_fat .+ #FAT1
		(class.==209)*Δw_fat    #FAT2
	T1 = T1*1e-3
	T2 = T2*1e-3
	T2s = T2s*1e-3
    phantom = Phantom(name="brain2D_"*axis,
					  x=y[ρ.!=0],
					  y=x[ρ.!=0],
					  z=0*x[ρ.!=0],
					  ρ=ρ[ρ.!=0],
					  T1=T1[ρ.!=0],
					  T2=T2[ρ.!=0],
					  T2s=T2s[ρ.!=0],
					  Δw=Δw[ρ.!=0])
	phantom
end

"""
B. Aubert-Broche, D.L. Collins, A.C. Evans: "A new improved version of the realistic digital brain phantom"
NeuroImage, in review - 2006.
B. Aubert-Broche, M. Griffin, G.B. Pike, A.C. Evans and D.L. Collins: "20 new digital brain phantoms for creation of validation image data bases"
IEEE TMI, in review - 2006

https://brainweb.bic.mni.mcgill.ca/brainweb
"""
function brain_phantom3D(;ss=4)
    path = @__DIR__
    data = MAT.matread(path*"/phantom/brain3D.mat")

    class = data["data"][1:ss:end,1:ss:end,160:ss:200]
    Δx = .5e-3*ss
    M, N, Z = size(class)
    FOVx = (M-1)*Δx #[m]
    FOVy = (N-1)*Δx #[m]
	FOVz = (Z-1)*Δx #[m]
    xx = reshape(-FOVx/2:Δx:FOVx/2,M,1,1) #spin coordinates
    yy = reshape(-FOVy/2:Δx:FOVy/2,1,N,1) #spin coordinates
	zz = reshape(-FOVz/2:Δx:FOVz/2,1,1,Z) #spin coordinates
    x = 1*xx .+ 0*yy .+ 0*zz
	y = 0*xx .+ 1*yy .+ 0*zz
	z = 0*xx .+ 0*yy .+ 1*zz

    T2 = (class.==23)*329 .+ #CSF
        (class.==46)*83 .+ #GM
        (class.==70)*70 .+ #WM
        (class.==93)*70 .+ #FAT1
        (class.==116)*47 .+ #MUSCLE
        (class.==139)*329 .+ #SKIN/MUSCLE
        (class.==162)*0 .+ #SKULL
        (class.==185)*0 .+ #VESSELS
        (class.==209)*70 .+ #FAT2
        (class.==232)*329 .+ #DURA
        (class.==255)*70 #MARROW
    T2s = (class.==23)*58 .+ #CSF
        (class.==46)*69 .+ #GM
        (class.==70)*61 .+ #WM
        (class.==93)*58 .+ #FAT1
        (class.==116)*30 .+ #MUSCLE
        (class.==139)*58 .+ #SKIN/MUSCLE
        (class.==162)*0 .+ #SKULL
        (class.==185)*0 .+ #VESSELS
        (class.==209)*61 .+ #FAT2
        (class.==232)*58 .+ #DURA
        (class.==255)*61 .+#MARROW
        (class.==255)*70 #MARROW
    T1 = (class.==23)*2569 .+ #CSF
        (class.==46)*833 .+ #GM
        (class.==70)*500 .+ #WM
        (class.==93)*350 .+ #FAT1
        (class.==116)*900 .+ #MUSCLE
        (class.==139)*569 .+ #SKIN/MUSCLE
        (class.==162)*0 .+ #SKULL
        (class.==185)*0 .+ #VESSELS
        (class.==209)*500 .+ #FAT2
        (class.==232)*2569 .+ #DURA
        (class.==255)*500 #MARROW
    ρ = (class.==23)*1 .+ #CSF
        (class.==46)*.86 .+ #GM
        (class.==70)*.77 .+ #WM
        (class.==93)*1 .+ #FAT1
        (class.==116)*1 .+ #MUSCLE
        (class.==139)*1 .+ #SKIN/MUSCLE
        (class.==162)*0 .+ #SKULL
        (class.==185)*0 .+ #VESSELS
        (class.==209)*.77 .+ #FAT2
        (class.==232)*1 .+ #DURA
        (class.==255)*.77 #MARROW
	Δw_fat = -220*2π
	Δw = (class.==93)*Δw_fat .+ #FAT1
		(class.==209)*Δw_fat    #FAT2
	T1 = T1*1e-3
	T2 = T2*1e-3
	T2s = T2s*1e-3
    phantom = Phantom(name="brain3D",
					  x=y[ρ.!=0],
					  y=x[ρ.!=0],
					  z=z[ρ.!=0],
					  ρ=ρ[ρ.!=0],
					  T1=T1[ρ.!=0],
					  T2=T2[ρ.!=0],
					  T2s=T2s[ρ.!=0],
					  Δw=Δw[ρ.!=0])
	phantom
end