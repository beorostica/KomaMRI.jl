include("ui/ExportMATFunctions.jl")
include("ui/ExportUIFunctions.jl")

# Define observables exported observables
sys_ui = Observable{Scanner}(Scanner())
seq_ui = Observable{Sequence}(Sequence())
obj_ui = Observable{Phantom}(Phantom(x=[0.0]))
raw_ui = Observable{RawAcquisitionData}(setup_raw())
img_ui = Observable{Array}([0.0im 0.; 0. 0.])

"""
    out = KomaUI(; kwargs...)

Launch the Koma's UI.

# Keywords
- `darkmode`: (`::Bool`, `=true`) define dark mode style for the UI
- `frame`: (`::Bool`, `=true`) display the upper frame of the Blink window
- `phantom_mode`: (`::String`, `="2D"`, opts=[`"2D"`, `"3D"`]) load the default phantom as a
    2D or 3D brain example
- `sim`: (`::Dict{String,Any}`, `=Dict{String,Any}()`) simulation parameters dictionary
- `rec`: (`::Dict{Symbol,Any}`, `=Dict{Symbol,Any}()`) reconstruction parameters dictionary
- `dev_tools`: (`::Bool`, `=false`) make the `out` be either 'nothing' or the Blink window,
    depending on whether the `dev_tools` keyword argument is set to true
- `blink_show`: (`::Bool`, `=true`) display the Blink window

# Returns
- `out`: (`::Nothing` or `::Blink.AtomShell.Window`) returns either 'nothing' or the Blink
    window, depending on whether the `dev_tools` keyword argument is set to true.

# Examples
```julia-repl
julia> KomaUI()
```
"""
function KomaUI(; darkmode=true, frame=true, phantom_mode="2D", sim=Dict{String,Any}(), rec=Dict{Symbol,Any}(), dev_tools=false, blink_show=true)

    # For phantom sub-buttons
    fieldnames_obj = [fieldnames(Phantom)[5:end-3]...]
    widgets_button_obj = button.(string.(fieldnames_obj))

    # Setup the Blink window
    w, index = setup_blink_window(; darkmode, frame, dev_tools, blink_show)

    # Setup default simulation inputs (they have observables)
    sys_ui[] = setup_scanner()
    seq_ui[] = setup_sequence(sys_ui[])
    obj_ui[] = setup_phantom(; phantom_mode)
    raw_ui[] = setup_raw()
    img_ui[] = [0.0im 0.; 0. 0.]

    # Define parameters (they are just internal variables)
    sim_params = merge(Dict{String,Any}(), sim)
    rec_params = merge(Dict{Symbol,Any}(:reco=>"direct"), rec)
    mat_folder = tempdir()

    # Boleans to indicate first time for precompilation
    is_first_sim = true
    is_first_rec = true

    # Print GPU information
    @info "Loading GPUs"
    KomaMRICore.print_gpus()

    # Handle "View" sidebar buttons
    handle(w, "index") do _
        content!(w, "div#content", index)
        @js_ w document.getElementById("content").dataset.content = "index"
    end
    handle(w, "pulses_seq") do _
        view_ui!(seq_ui[], w; type="sequence", darkmode)
    end
    handle(w, "pulses_kspace") do _
        view_ui!(seq_ui[], w; type="kspace", darkmode)
    end
    handle(w, "pulses_M0") do _
        view_ui!(seq_ui[], w; type="moment0", darkmode)
    end
    handle(w, "pulses_M1") do _
        view_ui!(seq_ui[], w; type="moment1", darkmode)
    end
    handle(w, "pulses_M2") do _
        view_ui!(seq_ui[], w; type="moment2", darkmode)
    end
    handle(w, "phantom") do _
        view_ui!(obj_ui[], w, seq_ui[], widgets_button_obj; key=:ρ, darkmode)
    end
    handle(w, "scanner") do _
        view_ui!(sys_ui[], w)
    end
    handle(w, "sim_params") do _
        view_ui!(sim_params, w)
    end
    handle(w, "sig") do _
        view_ui!(raw_ui[], w; darkmode)
    end
    handle(w, "rec_params") do _
        view_ui!(rec_params, w)
    end
    handle(w, "reconstruction_absI") do _
        view_ui!(img_ui[], w; type="absi", darkmode)
    end
    handle(w, "reconstruction_angI") do _
        view_ui!(img_ui[], w; type="angi", darkmode)
    end
    handle(w, "reconstruction_absK") do _
        view_ui!(img_ui[], w; type="absk", darkmode)
    end

    # Handle "Save" to mat sidebar buttons
    handle(w, "matfolder") do _
        save_ui!(w, seq_ui[], obj_ui[], sys_ui[], raw_ui[], img_ui[], rec_params, mat_folder; type="all")
    end
    handle(w, "matfolderseq") do _
        save_ui!(w, seq_ui[], obj_ui[], sys_ui[], raw_ui[], img_ui[], rec_params, mat_folder; type="sequence")
    end
    handle(w, "matfolderpha") do _
        save_ui!(w, seq_ui[], obj_ui[], sys_ui[], raw_ui[], img_ui[], rec_params, mat_folder; type="phantom")
    end
    handle(w, "matfoldersca") do _
        save_ui!(w, seq_ui[], obj_ui[], sys_ui[], raw_ui[], img_ui[], rec_params, mat_folder; type="scanner")
    end
    handle(w, "matfolderraw") do _
        save_ui!(w, seq_ui[], obj_ui[], sys_ui[], raw_ui[], img_ui[], rec_params, mat_folder; type="raw")
    end
    handle(w, "matfolderima") do _
        save_ui!(w, seq_ui[], obj_ui[], sys_ui[], raw_ui[], img_ui[], rec_params, mat_folder; type="image")
    end

    # Handle "Simulation" sidebar button
    handle(w, "simulate") do _

        # Display loading and disable simulation button
        msg = "Running simulation ..."
        if is_first_sim
            msg = "Precompiling and running simulation functions ..."
            is_first_sim = false
        end
        display_loading!(w, msg)
        @js_ w document.getElementById("simulate!").setAttribute("disabled", true)

        # Define progress bar in the simulation button
        progressbar = """
            <div class="progress" style="background-color: #27292d;">
            <div id="simul_progress" class="progress-bar" role="progressbar" style="width: 0%; transition:none;" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100">0%</div>
            </div>
        """
        @js_ w (@var progressbar = $progressbar; document.getElementById("simulate!").innerHTML=progressbar)

        # Perform simulation
        raw_aux = simulate(obj_ui[], seq_ui[], sys_ui[]; sim_params, w)

        # After simulation, display the text on the simulation button (not the progress bar)
        @js_ w document.getElementById("simulate!").innerHTML="Simulate!"

        # Save the raw signal to a file in the temporal directory
        rawfile = tempdir()*"/Koma_signal.mrd"
        @info "Exporting to ISMRMRD file: $rawfile"
        KomaMRICore.save(ISMRMRDFile(rawfile), raw_aux)

        # Display message on UI
        sim_time = raw_aux.params["userParameters"]["sim_time_sec"]
        @js_ w (
            @var sim_time = $sim_time;
            @var name = $(obj_ui[].name);
            document.getElementById("rawname").innerHTML = "Koma_signal.mrd";
            Toasty(
                "1",
                """Simulation successfull<br>Time: <a id="sim_time"></a> s""",
                """
                    <ul>
                        <li>
                            <button class="btn btn-dark btn-circle btn-circle-sm m-1" onclick="Blink.msg('sig', 1)"><i class="fa fa-search"></i></button>
                            Updating <b>Raw signal</b> plots ...
                        </li>
                        <li>
                            <button class="btn btn-primary btn-circle btn-circle-sm m-1" onclick="Blink.msg('recon', 1)"><i class="bi bi-caret-right-fill"></i></button>
                            Ready to <b>reconstruct</b>?
                        </li>
                    </ul>
                """
            );
            document.getElementById("sim_time").innerHTML = sim_time;
        )

        # Set the dataset content and enable simulation and reconstruction buttons
        @js_ w document.getElementById("content").dataset.content = "simulation"
        @js_ w document.getElementById("simulate!").removeAttribute("disabled");
        @js_ w document.getElementById("recon!").removeAttribute("disabled");

        # Update the value of the raw signal observable
        # this calls the view_ui to display the raw signal
        raw_ui[] = raw_aux
    end

    # Handle "Reconstruction" sidebar button
    handle(w, "recon") do _

        # Display loading
        msg = "Running reconstruction ..."
        if is_first_rec
            msg = "Precompiling and running reconstruction functions ..."
            is_first_rec = false
        end
        display_loading!(w, msg)

        # Update loading icon for button
        buffericon = """
            <div class="spinner-border spinner-border-sm text-light" role="status"></div>
        """
        @js_ w (@var buffericon = $buffericon; document.getElementById("recon!").innerHTML = buffericon)

        # Get the value of the raw signal and prepare for reconstruction
        raw_aux = raw_ui[]
        raw_aux.profiles = raw_aux.profiles[getproperty.(getproperty.(raw_aux.profiles, :head), :flags) .!= 268435456] #Extra profile in JEMRIS simulations
        acq_data = AcquisitionData(raw_aux)
        acq_data.traj[1].circular = false #Removing circular window
        acq_data.traj[1].nodes = acq_data.traj[1].nodes[1:2,:] ./ maximum(2*abs.(acq_data.traj[1].nodes[:])) #Normalize k-space to -.5 to .5 for NUFFT
        Nx, Ny = raw_aux.params["reconSize"][1:2]
        rec_params[:reconSize] = (Nx, Ny)
        rec_params[:densityWeighting] = true

        # Perform reconstruction
        @info "Running reconstruction ..."
        rec_aux = @timed reconstruction(acq_data, rec_params)
        image  = reshape(rec_aux.value.data, Nx, Ny, :)

        # After Recon go to Image
        recon_time = rec_aux.time
        @js_ w (document.getElementById("recon!").innerHTML = "Reconstruct!")
        @js_ w (
            @var recon_time = $recon_time;
            Toasty(
                "2",
                """Reconstruction successfull<br>Time: <a id="recon_time"></a> s""",
                """
                    <ul>
                        <li>
                            <button class="btn btn-dark btn-circle btn-circle-sm m-1" onclick="Blink.msg('reconstruction_absI', 1)"><i class="fa fa-search"></i></button>
                            Updating <b>Reconstruction</b> plots ...
                        </li>
                    </ul>
                """
            );
            document.getElementById("recon_time").innerHTML = recon_time;
        )
        @js_ w document.getElementById("content").dataset.content = "reconstruction"

        # Update the value of the image observable
        # this calls the view_ui to display the image
        img_ui[] = image
    end

    # Define functionality of sequence filepicker widget
    widget_filepicker_seq = filepicker(".seq (Pulseq)/.seqk (Koma)"; accept=".seq,.seqk")
    map!((filename) -> callback_filepicker(filename, w, seq_ui[]), seq_ui, widget_filepicker_seq)
    on((seq) -> view_ui!(seq, w; type="sequence", darkmode), seq_ui)

    # Define functionality of phantom filepicker widget and sub-buttons
    widget_filepicker_obj = filepicker(".phantom (Koma)/.h5 (JEMRIS)"; accept=".phantom,.h5")
    map!((filename) -> callback_filepicker(filename, w, obj_ui[]), obj_ui, widget_filepicker_obj)
    on((obj) -> view_ui!(obj, w, seq_ui[], widgets_button_obj; key=:ρ, darkmode), obj_ui)
    for (widget_button, key) in zip(widgets_button_obj, fieldnames_obj)
        on((cnt) -> view_ui!(cnt, w, obj_ui[], seq_ui[], widgets_button_obj; key, darkmode), widget_button)
    end

    # Define functionality when scanner observable changes
    on((sys) -> view_ui!(sys, w), sys_ui)

    # Define functionality of raw filepicker widget
    widget_filepicker_raw = filepicker(".h5/.mrd (ISMRMRD)"; accept=".h5,.mrd")
    map!((filename) -> callback_filepicker(filename, w, raw_ui[]), raw_ui, widget_filepicker_raw)
    on((raw) -> view_ui!(raw, w; darkmode), raw_ui)

    # Define functionality when image observable changes (after reconstruction)
    on((img) -> view_ui!(img, w; type="absi", darkmode), img_ui)

    # Add filepicker widgets to the UI
    content!(w, "#seqfilepicker", widget_filepicker_seq, async=false)
    content!(w, "#phafilepicker", widget_filepicker_obj, async=false)
    content!(w, "#sigfilepicker", widget_filepicker_raw, async=false)

    # Update Koma version on UI
    version = string(KomaMRICore.__VERSION__)
    content!(w, "#version", version, async=false)
    @info "Currently using KomaMRICore v$version"

    # Return the Blink Window or not
    (dev_tools) && return w
    return nothing
end

"""
Auxiliary function to updates KomaUI's simulation progress bar.
"""
function update_blink_window_progress!(w::Window, block, Nblocks)
    progress = string(floor(Int, block / Nblocks * 100))
    @js_ w (@var progress = $progress;
    document.getElementById("simul_progress").style.width = progress + "%";
    document.getElementById("simul_progress").innerHTML = progress + "%";
    document.getElementById("simul_progress").setAttribute("aria-valuenow", progress))
    return nothing
end
