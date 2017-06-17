module Tinker

# package code goes here

using Gtk.ShortNames, GtkReactive, TestImages, Graphics, Colors, Images

function setupfile(file)
    # file info
    image = load(file)

    # set up window
    win = Window(file, size(image,2), size(image,1)); #name of image
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
        fvx = r.fullview.x # x range of image
        fvy = r.fullview.y # y range if image
        cvx = r.currentview.x # the x range of currentview
        cvy = r.currentview.y # the y range of currentview
        xsc = (cvx.right-cvx.left)/(10*(fvx.right-fvx.left)) # x scale
        ysc = (cvy.right-cvy.left)/(10*(fvy.right-fvy.left)) # y scale
        x_off = cvx.left+75*xsc # x offset 
        y_off = cvy.left+75*ysc # y offset
        #RECTANGLES:
        rect1 = [ (0.0 + x_off, 0.0 + y_off),
                  (fvx.right*xsc + x_off, 0.0 + y_off),
                  (fvx.right*xsc + x_off, fvy.right*ysc + y_off),
                  (0.0 + x_off, fvy.right*ysc + y_off),
                  (0.0 + x_off, 0.0 + y_off) ]
        rect2 = [ (x_off + (cvx.left-1)*xsc, y_off + (cvy.left-1)*ysc),
                  (x_off + cvx.right*xsc, y_off + (cvy.left-1)*ysc),
                  (x_off + cvx.right*xsc, y_off + cvy.right*ysc),
                  (x_off + (cvx.left-1)*xsc, y_off + cvy.right*ysc),
                  (x_off + (cvx.left-1)*xsc, y_off + (cvy.left-1)*ysc) ]
        return [rect1, rect2]
    end

    # draw
    redraw = draw(c, imagesig, zr, viewdim) do cnvs, img, r, vd
        copy!(cnvs, img) # show image on canvas at current zoom level
        set_coordinates(cnvs, r) # set canvas coordinates to zr
        # draw view diagram IF zoomed in
        ctx = getgc(cnvs)
        drawrect(ctx, vd[1], colorant"blue")
        drawrect(ctx, vd[2], colorant"blue")
        # draw zoom % above/below view diagram OR put that info in title bar
    end

    # rectangle draw function
    function drawrect(ctx, rect, color)
        move_to(ctx, rect[1][1], rect[1][2])
        set_source(ctx, color)
        for i = 2:length(rect)
            line_to(ctx, rect[i][1], rect[i][2])
        end
        stroke(ctx)
    end;

    showall(win);

    # zoom actions
    # remove later and replace with Tinker controls
    rb = init_zoom_rubberband(c, zr) # ctrl+drag zooms; double click to zoom out
    pandrag = init_pan_drag(c, zr) # dragging moves image

    append!(c.preserved, [rb, pandrag])
    nothing
end;


end # module
