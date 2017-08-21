using Tinker, Base.Test, TestImages, GtkReactive

# make sure init_image runs
Tinker.init_image(testimage("cameraman.tif"); name="Testing")
Reactive.run_till_now()
@test value(Tinker.active_context) == value(Tinker.img_ctxs)[end]
Tinker.set_mode_all(Tinker.rectangle_mode)
#Tinker.set_mode_all(Tinker.freehand_mode)

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
#=# Test get_handle
recth = Tinker.RectHandle(r1)
@test recth.h[3] == Tinker.get_handle(recth, "trc")=#
# Test get_p1
#=@test XY{UserUnit}(23.4, 56.8) == Tinker.get_p1(recth.h[1], recth)
@test XY{UserUnit}(23.4, 56.8) == Tinker.get_p1(recth.h[2], recth)
@test XY{UserUnit}(5.0, 56.8) == Tinker.get_p1(recth.h[3], recth)
@test XY{UserUnit}(5.0, 10.0) == Tinker.get_p1(recth.h[4], recth)
@test XY{UserUnit}(5.0, 10.0) == Tinker.get_p1(recth.h[5], recth)
@test XY{UserUnit}(5.0, 10.0) == Tinker.get_p1(recth.h[6], recth)
@test XY{UserUnit}(23.4, 10.0) == Tinker.get_p1(recth.h[7], recth)
@test XY{UserUnit}(23.4, 56.8) == Tinker.get_p1(recth.h[8], recth)=#
# Create fake buttonpress
struct fake_buttonpress
    position::XY{UserUnit}
end
btn1 = fake_buttonpress(XY{UserUnit}(recth.h[1].x+0.1, recth.h[1].y-0.2))
btn1_1 = fake_buttonpress(XY{UserUnit}(recth.h[1].x+3.2, recth.h[1].y-4.8))
btn2 = fake_buttonpress(XY{UserUnit}(recth.h[2].x+0.1, recth.h[2].y-0.2))
btn3 = fake_buttonpress(XY{UserUnit}(recth.h[3].x+0.1, recth.h[3].y-0.2))
btn4 = fake_buttonpress(XY{UserUnit}(recth.h[4].x+0.1, recth.h[4].y-0.2))
btn5 = fake_buttonpress(XY{UserUnit}(recth.h[5].x+0.1, recth.h[5].y-0.2))
btn6 = fake_buttonpress(XY{UserUnit}(recth.h[6].x+0.1, recth.h[6].y-0.2))
btn7 = fake_buttonpress(XY{UserUnit}(recth.h[7].x+0.1, recth.h[7].y-0.2))
btn8 = fake_buttonpress(XY{UserUnit}(recth.h[8].x+0.1, recth.h[8].y-0.2))
btn9 = fake_buttonpress(XY{UserUnit}(40.5, 80.2)) # not on a handle
btn10 = fake_buttonpress(XY{UserUnit}(recth.h[1].x+3.2, recth.h[1].y-6.8)) #""
#=# Test get_p2
@test XY{UserUnit}(btn1.position.x, btn1.position.y) ==
    Tinker.get_p2(recth.h[1], recth, btn1)
@test XY{UserUnit}(recth.r.x, btn2.position.y) ==
    Tinker.get_p2(recth.h[2], recth, btn2)
@test XY{UserUnit}(btn3.position.x, btn3.position.y) ==
    Tinker.get_p2(recth.h[3], recth, btn3)
@test XY{UserUnit}(btn4.position.x, recth.h[5].y) ==
    Tinker.get_p2(recth.h[4], recth, btn4)
@test XY{UserUnit}(btn5.position.x, btn5.position.y) ==
    Tinker.get_p2(recth.h[5], recth, btn5)
@test XY{UserUnit}(recth.h[5].x, btn6.position.y) ==
    Tinker.get_p2(recth.h[6], recth, btn6)
@test XY{UserUnit}(btn7.position.x, btn7.position.y) ==
    Tinker.get_p2(recth.h[7], recth, btn7)
@test XY{UserUnit}(btn8.position.x, recth.r.y) ==
    Tinker.get_p2(recth.h[8], recth, btn8)=#
# Test nearby_handle
#=@test Tinker.nearby_handle(btn1.position, recth, 5.0) == recth.h[1]
@test Tinker.nearby_handle(btn1_1.position, recth, 5.0) == recth.h[1]
@test Tinker.nearby_handle(btn1.position, recth, 5.0) != recth.h[2]
@test isempty(Tinker.nearby_handle(btn9.position, recth, 5.0))
@test isempty(Tinker.nearby_handle(btn10.position, recth, 5.0))=#

# Test get_view
img = value(Tinker.active_context).image
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
