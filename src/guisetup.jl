## Initializes GUI

# Toolbar
win1 = Window("GUI", 450, 200)
t = Grid()
bz = Button("Zoom Mode")
t[1,1] = bz
br = Button("Rectangle Mode")
t[1,2] = br
bf = Button("Freehand Mode")
t[1,3] = bf
bp = Button("Polygon Mode")
t[1,4] = bp
g = Grid()
g[1,1] = t

# Button actions for mode switches
zoomid = signal_connect(bz, "clicked") do z
  set_mode_all(zm)
end

rectid = signal_connect(br, "clicked") do r
  set_mode_all(rect)
end

freeid = signal_connect(bf, "clicked") do f
  set_mode_all(freehand)
end

polyid = signal_connect(bp, "clicked") do p
  set_mode_all(poly)
end

nb = Notebook()
g[2,1] = nb
# Measurements show for every open window
function display_measure(ctx::ImageContext)
  txt = TextView() # turn off ability for user to enter text
  setproperty!(txt,:expand,true)
  tblsig = map(ctx.canvas.mouse.buttonrelease) do btn
    df = init_measure_tbl()
    push!(df, measure(ctx.image))
    push!(df, measure(value(ctx.rectview)))
    #@show df
    df
  end
  push!(txt,string(value(tblsig))) # make this update w/ every buttonrelease
  push!(nb, txt, "Context $(ctx.id)")
  showall(win1)
  append!(ctx.canvas.preserved, [tblsig])
end

push!(win1,g)
showall(win1)
