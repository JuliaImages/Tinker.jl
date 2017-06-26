module Tinker

using Gtk.ShortNames, GtkReactive, Graphics, Colors, Images

## Generally useful structs and functions
# Rectangle structure
struct Rectangle
    x::Float64
    y::Float64
    w::Float64
    h::Float64
end

# rectangle draw function
function drawrect(ctx, rect, color)
    set_source(ctx, color)
    rectangle(ctx, rect.x, rect.y, rect.w, rect.h)
    stroke(ctx)
end;

## Sets up an image in a separate window with the ability to adjust view
function init_gui(image::AbstractArray; name="Tinker")
    # set up window
    win = Window(name, size(image,2), size(image,1));
    c = canvas(UserUnit);
    push!(win, c);

    # set up a zoom region
    zr = Signal(ZoomRegion(image))

    # create view
    imagesig = map(zr) do r
        cv = r.currentview
        view(image, UnitRange{Int}(cv.y), UnitRange{Int}(cv.x))
    end;
    
    # create a view diagram
    viewdim = map(zr) do r
        fvx, fvy = r.fullview.x, r.fullview.y # x, y range of full view
        cvx, cvy = r.currentview.x, r.currentview.y # x, y range of currentview
        xfull, yfull =
            (fvx.right-fvx.left),(fvy.right-fvy.left) # width of full view
        xcurrent, ycurrent =
            (cvx.right-cvx.left),(cvy.right-cvy.left) # width of current view
        # scale
        xsc,ysc = 0.1*(xcurrent/xfull), 0.1*(ycurrent/yfull)
        # offset
        x_off,y_off = cvx.left+(0.01*xcurrent),cvy.left+(0.01*ycurrent)
        # represents full view
        rect1 = Rectangle(x_off, y_off, xsc*xfull, ysc*yfull)
        # represents current view
        rect2 = Rectangle(x_off+(cvx.left*xsc), y_off+(cvy.left*ysc),
                          xsc*xcurrent, ysc*ycurrent)
        return [rect1,rect2]
    end

    # draw
    redraw = draw(c, imagesig, zr, viewdim) do cnvs, img, r, vd
        copy!(cnvs, img) # show image on canvas at current zoom level
        set_coordinates(cnvs, r) # set canvas coordinates to zr
        ctx = getgc(cnvs)
        # draw view diagram if zoomed in
        if r.fullview != r.currentview
            drawrect(ctx, vd[1], colorant"blue")
            drawrect(ctx, vd[2], colorant"blue")
        end
    end

    # holds x zoom level
    xzoom = map(zr) do r
        100*r.fullview.x.right/(r.currentview.x.right-(r.currentview.x.left-1))
    end

    # hold y zoom level
    yzoom = map(zr) do r
        100*r.fullview.y.right/(r.currentview.y.right-(r.currentview.y.left-1))
    end

    # performs proportional zoom in (x2 each time)
    function zoomin()
        push!(zr, zoom(value(zr), 0.5))
        println("zoom x%: ", value(xzoom),"\n zoom y%: ", value(yzoom))
        # why doesn't this update after push?
    end

    # performs proportional zoom out (x0.5 each time)
    function zoomout() # doesn't perfectly undo zoomin: problem
        push!(zr, zoom(value(zr), 2.0))
        println("zoom x%: ", value(xzoom),"\n zoom y%: ", value(yzoom))
    end
    
    showall(win);

    # zoom actions
    # remove later and replace with Tinker controls
    rb = init_zoom_rubberband(c, zr) # ctrl+drag zooms; double click to zoom out
    pandrag = init_pan_drag(c, zr) # dragging moves image

    append!(c.preserved, [rb, pandrag])
    nothing
end;

init_gui(file::AbstractString) = init_gui(load(file); name=file)

end # module
