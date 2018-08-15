
# NOTE: Below are the packages needed to run all of this notebook.
# You really need ApplicationBuilder. The rest are optional.
Pkg.clone("https://github.com/NHDaly/ApplicationBuilder.jl")  # Necessary for whole notebook
Pkg.add("PrintFileTree")  # Not necessary (you can use unix `find` as a decent replacement).
Pkg.add("UnicodePlots")  # Only needed for the demo application.
Pkg.add("Plots");  # Only needed for the GUI example at the end.
Pkg.add("Blink"); using Blink; Blink.AtomShell.install()  # Only needed if you want to run the GUI example at the end.

mkpath("OurProject")

mkpath("OurProject/src")  # For OurProject's source code

write("OurProject/src/project.jl",
 """
    using UnicodePlots

    println("**** Hello From Julia! ****")
    r = rand(0:2π)
    println(lineplot(1:100, sin.(linspace(r, r+2π, 100))))
    
    println("Current working directory:", pwd())
 """
)

using PrintFileTree
printfiletree("OurProject")

include("OurProject/src/project.jl")

 using ApplicationBuilder

build_app_bundle("OurProject/src/project.jl")

write("OurProject/src/project.jl",
 """
    using UnicodePlots
    
    println("**** Hello from the outside! ****")
    
    Base.@ccallable function julia_main(ARGS::Vector{String})::Cint
        println("**** Hello From Julia! ****")
        r = rand(0:2π)
        println(lineplot(1:100, sin.(linspace(r, r+2π, 100))))
    
        println("Current working directory:", pwd())

        return 0
    end
 """
)

build_app_bundle("OurProject/src/project.jl",
                 appname="HelloWorld",
                 builddir="OurProject/builds",
                 commandline_app=true)

run(`open ./OurProject`)

using Blink

win = Window(); sleep(2)

body!(win, """
    <input id="mySlider" type="range" min="1" max="100" value="50">
    <script> 
        var mySlider = document.getElementById("mySlider")
    </script>
"""); sleep(2)
tools(win)

Blink.@js_ win console.log("HELLO!")
Blink.@js_ win mySlider.oninput = 
    (e) -> (Blink.msg("sliderChange", mySlider.value);
            console.log("sent msg to julia!"); e.returnValue=false)
Blink.handlers(win)["sliderChange"] = (val) -> (println("msg from js: $val"))

using Plots
plotly()

r = rand(0:0.1:2π)
p = plot(r:2π/100:r+2π, sin)

# Let's draw that plot as an SVG and show it in our html window!
buf = IOBuffer()
show(buf, MIME("text/html"), p)
plothtml = String(take!(buf))

body!(win, """<script>var Plotly = require('$(Plots._plotly_js_path)');</script>
              <div id="plotHolder"></div>"""); sleep(3)
content!(win, "#plotHolder", plothtml);

using Blink, Plots
plotly()

win = Window(); sleep(2)
body!(win, """
    <input id="mySlider" type="range" min="1" max="100" value="50">
    <div id="plotHolder">
        plot goes here...
    </div>
    <script>
        mySlider = document.getElementById("mySlider")
        var Plotly = require('$(Plots._plotly_js_path)');
    </script>
"""); sleep(2)
tools(win)

Blink.@js win console.log("HELLO!")
Blink.@js win mySlider.oninput = 
    (e) -> (Blink.msg("sliderChange", mySlider.value);
            console.log("sent msg to julia!"); e.returnValue=false)

function sliderChange(val)
    r = parse(val)
    p = Plots.plot(r:2π/100:r+2π, sin)
    buf = IOBuffer()
    show(buf, MIME("text/html"), p)
    plothtml = String(take!(buf))

    content!(win, "#plotHolder", plothtml, fade=false)
end

Blink.handlers(win)["sliderChange"] = sliderChange

write("OurProject/src/project.jl",
 raw"""
    using Blink, Plots
    plotly()

    Base.@ccallable function julia_main(ARGS::Vector{String})::Cint
        win = Blink.Window(); sleep(2)
        Blink.body!(win, \"\"\"
            <input id="mySlider" type="range" min="1" max="100" value="50">
            <div id="plotHolder">
                plot goes here...
            </div>
            <script>
                mySlider = document.getElementById("mySlider")
                var Plotly = require('$(Plots._plotly_js_path)');
            </script>
        \"\"\"); sleep(2)
        Blink.tools(win)

        Blink.@js_ win console.log("HELLO!")
        Blink.@js_ win mySlider.oninput = 
            (e) -> (Blink.msg("sliderChange", mySlider.value);
                    console.log("sent msg to julia!"); e.returnValue=false)

        function sliderChange(val)
            r = parse(val)
            p = Plots.plot(r:2π/100:r+2π, sin);  # Don't forget this ';' to prevent it opening a plot window!
            buf = IOBuffer()
            # invokelatest b/c show compiles more functions, and fails due to world age (https://discourse.julialang.org/t/running-in-world-age-x-while-current-world-is-y-errors/5871/5)
            Base.invokelatest(show, buf, MIME("text/html"), p);
            plothtml = String(take!(buf))

            Blink.content!(win, "#plotHolder", plothtml, fade=false)
        end

        Blink.handlers(win)["sliderChange"] = sliderChange
    
        # Keep the process alive until the window is closed!
        while Blink.active(win)
            sleep(1)
        end

        return 0
    end
 """
)

build_app_bundle(
    "OurProject/src/project.jl",
    appname="SinePlotter",  # New App name
    builddir="OurProject/builds",
)

run(`open OurProject/builds/SinePlotter.app`)

# Apply that to our program, and this is what we have:
write("OurProject/src/project.jl",
 raw"""
    using Blink, Plots

    # THIS IS NEEDED FOR YOUR CODE TO RUN ON ANY COMPUTER
    if get(ENV, "COMPILING_APPLE_BUNDLE", "false") == "true"
        println("Overriding Blink dependency paths.")
        eval(Blink.AtomShell, :(_electron = "Julia.app/Contents/MacOS/Julia"))
        eval(Blink.AtomShell, :(mainjs = "main.js"))
        eval(Blink, :(buzz = "main.html"))
        eval(Blink, :(resources = Dict("spinner.css" => "res/spinner.css",
                                 "blink.js" => "res/blink.js",
                                 "blink.css" => "res/blink.css",
                                 "reset.css" => "res/reset.css")))
        # Clear out Blink.__inits__, since it will attempt to evaluate hardcoded paths.
        # (We've defined all the variables manually, above: `resources` and `port`.)
        eval(Blink, :(empty!(__inits__)))

        eval(HttpParser, :(lib = basename(lib)))
        eval(MbedTLS, :(const libmbedcrypto = basename(libmbedcrypto)))

        using WebSockets
        eval(WebSockets, :(using HttpServer))  # needed to cause @require lines to execute & compile
        eval(WebSockets,
            :(include(joinpath(Pkg.dir("WebSockets"),"src/HttpServer.jl"))))  # Manually load this from the @requires line.

        println("Done changing Blink dependencies.")
        
        println("Overriding Plotly dependency paths.")
        eval(Plots, :(_plotly_js_path = "plotly-latest.min.js"))
        println("Done changing Plotly dependencies.")
    end
    
    Base.@ccallable function julia_main(ARGS::Vector{String})::Cint
        # This must be inside app_main() so it happens at runtime.
        Plots.plotly()

        # Set Blink port randomly before anything else, so it's not compiled with a fixed port.
        eval(Blink, :(const port = get(ENV, "BLINK_PORT", rand(2_000:10_000))))

        win = Blink.Window(); sleep(5)
        Blink.body!(win, \"\"\"
            <input id="mySlider" type="range" min="1" max="100" value="50">
            <div id="plotHolder">
                plot goes here...
            </div>
            <script>
                mySlider = document.getElementById("mySlider")
                var Plotly = require('../../../../../$(Plots._plotly_js_path)');
            </script>
        \"\"\"); sleep(2)
        Blink.tools(win)

        Blink.@js_ win console.log("HELLO!")
        Blink.@js_ win mySlider.oninput = 
            (e) -> (Blink.msg("sliderChange", mySlider.value);
                    console.log("sent msg to julia!"); e.returnValue=false)

        function sliderChange(val)
            r = parse(val)
            p = Plots.plot(r:2π/100:r+2π, sin);  # Don't forget this ';' to prevent it opening a plot window!
            buf = IOBuffer()
            # invokelatest b/c show compiles more functions, and fails due to world age (https://discourse.julialang.org/t/running-in-world-age-x-while-current-world-is-y-errors/5871/5)
            Base.invokelatest(show, buf, MIME("text/html"), p);
            plothtml = String(take!(buf))

            Blink.content!(win, "#plotHolder", plothtml, fade=false)
        end

        Blink.handlers(win)["sliderChange"] = sliderChange
    
        # Keep the process alive until the window is closed!
        while Blink.active(win)
            sleep(1)
        end

        return 0
    end
"""
)

# Build a distributable SinPlotter.app!
using ApplicationBuilder
using Blink, Plots
blinkPkg = Pkg.dir("Blink")
macroToolsPkg = Pkg.dir("MacroTools")

build_app_bundle(
    "OurProject/src/project.jl",
    appname="SinePlotterBundled",
    builddir="OurProject/builds",
    resources = [
        # Blink resources
        joinpath(blinkPkg, "deps","Julia.app"),
        Blink.AtomShell.mainjs,
        joinpath(blinkPkg, "src","content","main.html"),
        joinpath(blinkPkg, "res"),
        # Plots resources
        Plots._plotly_js_path,
    ],
    libraries = [
        HttpParser.lib,
        MbedTLS.libmbedcrypto,
    ],
)

run(`open OurProject/builds/`)
