using Tinker, Base.Test, TestImages, GtkReactive

# make sure init_image runs
ctx = Tinker.init_image(testimage("cameraman.tif"); name="Testing")
Reactive.run_till_now()
Tinker.set_mode_all(Tinker.rectangle_mode)

# Test zoom functions
test_zr = ZoomRegion((1:100, 1:200))
sig_zr = Signal(test_zr)
push!(sig_zr, Tinker.zoom_percent(1.8, test_zr))
Reactive.run_till_now()
@test test_zr.fullview == value(sig_zr).fullview
@test test_zr.currentview != value(sig_zr).currentview
push!(sig_zr, Tinker.zoom_percent(1.0, test_zr))
Reactive.run_till_now()
@test test_zr == value(sig_zr)
@test XY(100, 50) == Tinker.find_center(test_zr)
# Test zoom tracking
test_ctx = Tinker.ImageContext()
test_ctx.zr = sig_zr
Tinker.zoom_to(test_ctx, 2.3)
Reactive.run_till_now()
@test Tinker.zpercents[Tinker.next_zoom(test_ctx)] == 2.5
@test Tinker.zpercents[Tinker.prev_zoom(test_ctx)] == 2.0
Tinker.zoom_to(test_ctx, 2.0)
Reactive.run_till_now()
@test Tinker.zpercents[Tinker.next_zoom(test_ctx)] == 2.5
@test Tinker.zpercents[Tinker.prev_zoom(test_ctx)] == 1.5
Tinker.zoom_to(test_ctx, 1.2)
Reactive.run_till_now()
@test Tinker.zpercents[Tinker.next_zoom(test_ctx)] == 1.5
@test Tinker.zpercents[Tinker.prev_zoom(test_ctx)] == 1.0

# Test Rectangle constructors
r1 = Tinker.Rectangle(XY(5.0, 56.8), XY(23.4, 10.0))
r2 = Tinker.Rectangle(5.0, 10.0, 18.4, 46.8)
@test r1 == r2

# Test get_view
img = ctx.image
@test img == Tinker.get_view(img, 1, 1, size(img,2), size(img,1))
@test img == Tinker.get_view(img, -50, -50, size(img,2)+20, size(img,1))
@test view(img, Int(floor(size(img,1)/4)):Int(floor(size(img,1)/2)),
           Int(floor(size(img,2)/4)):Int(floor(size(img,2)/2))) ==
    Tinker.get_view(img,size(img,2)/4,size(img,1)/4,size(img,2)/2,size(img,1)/2)

# Test ispolygon
@test !Tinker.ispolygon([XY(1,2),XY(1,2)])
@test !Tinker.ispolygon([XY(1,2),XY(1,2),XY(1,2),XY(1,2)])
@test !Tinker.ispolygon([XY(1,2),XY(3,4),XY(1,2)])
@test Tinker.ispolygon([XY(1,2),XY(5,6),XY(38,42),XY(1,2)])
@test !Tinker.ispolygon([XY(1,2),XY(5,6),XY(38,42),XY(2,2)])
@test Tinker.ispolygon([XY(4,4),XY(5,5),XY(6,7), XY(4,20),XY(9,9),XY(4,4)])
@test !Tinker.ispolygon([XY(1,2),XY(5,6),XY(38,42),XY(1,2),XY(4,4)])

# Test is_point
@test Tinker.near_vertex(XY(5.4,2.8),[XY(4,4),XY(5,5),XY(6,7), XY(4,20),XY(9,9),XY(4,4)],5.0) == 1
@test Tinker.near_vertex(XY(-4,-9),[XY(4,4),XY(5,5),XY(6,7), XY(4,20),XY(9,9),XY(4,4)],5.0) == -1


## SELECTION_ACTIONS.jl
# Test two_point_rect & two_point_rh
rect1 = Tinker.two_point_rect(XY(8.9,0),XY(2,12.3))
recth1 = Tinker.two_point_rh(XY(8.9,0),XY(2,12.3))
@test rect1[1] == recth1[1]
@test rect1[2] == recth1[3]
@test rect1[3] == recth1[5]
@test rect1[4] == recth1[7]
@test rect1[1].y == recth1[2].y
@test rect1[2].x == recth1[4].x
@test rect1[3].y == recth1[6].y
@test rect1[4].x == recth1[8].x

# Test near_point
p1,p2,p3,p4,p5 = XY(0,0),XY(0.1,-0.1),XY(5.0, 5.0),XY(6,0),XY(0,6) # test pts
@test Tinker.near_point(p1, p2, 5.0) # very close
@test Tinker.near_point(p1, p3, 5.0) # limit of tolerance
@test !Tinker.near_point(p1, p3, 2.5) # not within tolerance
@test !Tinker.near_point(p1, p4, 5.0) # x false, y true
@test !Tinker.near_point(p1, p5, 5.0) # y true, x false
@test Tinker.near_point(p1, p1, 2.0) # same point

# Test near_vertex
p = [XY(0,0), XY(3,5), XY(7,4), XY(6,2), XY(0,0)] # test array
@test Tinker.near_vertex(p1, p, 5.0) == 1 # identical point
@test Tinker.near_vertex(p2, p, 0.1) == 1 # limit of tolerance
@test Tinker.near_vertex(p3, p, 2.0) == 2
@test Tinker.near_vertex(p4, p, 4.9) == 3
@test Tinker.near_vertex(p4, p, 2.0) == 4
@test Tinker.near_vertex(p5, p, 2.9) == -1 # false

# Test get_p1
rh = Tinker.two_point_rh(XY(1,1),XY(5.6,7.8))
@test Tinker.get_p1(1, rh) == rh[5]
@test Tinker.get_p1(3, rh) == rh[7]
@test Tinker.get_p1(5, rh) == rh[1]
@test Tinker.get_p1(7, rh) == rh[3]
@test Tinker.get_p1(2, rh) == rh[5]
@test Tinker.get_p1(4, rh) == rh[1]
@test Tinker.get_p1(6, rh) == rh[1]
@test Tinker.get_p1(8, rh) == rh[5]
@test isnan(Tinker.get_p1(9,rh).x)

# Test get_p2
@test Tinker.get_p2(1, rh, p3) == p3
@test Tinker.get_p2(3, rh, p3) == p3
@test Tinker.get_p2(5, rh, p3) == p3
@test Tinker.get_p2(7, rh, p5) == p5
@test Tinker.get_p2(2, rh, p3) == XY(rh[1].x,p3.y)
@test Tinker.get_p2(4, rh, p3) == XY(p3.x,rh[5].y)
@test Tinker.get_p2(6, rh, p3) == XY(rh[5].x,p3.y)
@test Tinker.get_p2(8, rh, p3) == XY(p3.x,rh[1].y)
@test isnan(Tinker.get_p2(9,rh,p3).x)

# Test init_selection_actions
sa = Tinker.init_selection_actions(ctx)
@test value(sa["enabled"]) == true
@test value(sa["mode"]) == Tinker.freehand_mode
