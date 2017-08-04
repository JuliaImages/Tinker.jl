# Set up GUI
win = Window("GUI")
g = Grid()
bz = Button("Zoom Mode")
g[1,1] = bz
br = Button("Rectangle Mode")
g[1,2] = br
bf = Button("Freehand Mode")
g[1,3] = bf
bp = Button("Polygon Mode")
g[1,4] = bp

# make buttons do things
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

push!(win,g)
showall(win)
