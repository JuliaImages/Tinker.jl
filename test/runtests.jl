using Tinker, Base.Test, TestImages, GtkReactive

# make sure init_gui runs
Tinker.init_gui(testimage("cameraman.tif"); name="Testing")

test_zr = ZoomRegion((1:10, 1:20))
sig_zr = Signal(test_zr)
push!(sig_zr, Tinker.zoom_percent(1.8, test_zr))
@test test_zr.fullview == value(sig_zr).fullview
@test test_zr.currentview != value(sig_zr).currentview
push!(sig_zr, Tinker.zoom_percent(1.0, test_zr))
@test test_zr == value(sig_zr)
@test XY(10, 5) == Tinker.find_center(test_zr)
# tests fail because of delay in push!()
