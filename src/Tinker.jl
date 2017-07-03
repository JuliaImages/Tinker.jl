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

Rectangle() = Rectangle(0,0,-1,-1)
Base.isempty(R::Rectangle) = R.w < 0 || R.h < 0

# rectangle draw function
function drawrect(ctx, rect, color)
    set_source(ctx, color)
    rectangle(ctx, rect.x, rect.y, rect.w, rect.h)
    stroke(ctx)
end;

# Zooms zr to the decimal % entered; view centered around center XY
function zoom_percent(z::Float64, zr::ZoomRegion, center::XY{Int64})
    # Calculate size of new view
    range = zr.fullview
    fsize = XY(range.x.right,range.y.right) # full size
    csize = XY(Int(round(fsize.x/z)), Int(round(fsize.y/z))) # new current size
    # Calculate center point of new view
    offset = XY(center.x-Int(round(csize.x/2)),
                center.y-Int(round(csize.y/2))) # offset of cv
    # Limit offset
    if offset.x < 0
        y = offset.y
        offset = XY(0, y)
    elseif offset.x > (fsize.x-csize.x)
        y = offset.y
        offset = XY(fsize.x-csize.x, y)
    end
    if offset.y < 0
        x = offset.x
        offset = XY(x, 0)
    elseif offset.y > (fsize.y-csize.y)
        x = offset.x
        offset = XY(x, fsize.y-csize.y)
    end
    
    return (offset.y+1:offset.y+csize.y, offset.x+1:offset.x+csize.x)
end # return value can be pushed to a zr

# Sets default center to be the middle of the cv
function zoom_percent(z::Float64, zr::ZoomRegion)
    # Calculate cv
    range = zr.currentview
    csize = XY(range.x.right-range.x.left,range.y.right-range.y.left)
    center = XY(range.x.left+Int(round(csize.x/2)),
                range.y.left+Int(round(csize.y/2)))
    zoom_percent(z,zr,center)
end

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

    zpercents = [1.0,1.2,1.5,2.0,2.5,3.0,4.0,8.0]
    global i = 1 # or: const i = Ref(1)

    # performs proportional zoom in
    function zoomin(center::XY{Int})
        global i
        if 1 <= i <= length(zpercents)
            if i < length(zpercents)
                i += 1
                push!(zr, zoom_percent(zpercents[i],value(zr),center))
            end
        else
            index = 1
            for n in zpercents
                if n > value(xzoom)
                    break
                end
                index += 1
            end
            i = index
            push!(zr, zoom_percent(zpercents[i],value(zr),center))
        end
    end

    function zoomin()
        global i
        if 1 <= i <= length(zpercents)
            if i < length(zpercents)
                i += 1
                push!(zr, zoom_percent(zpercents[i],value(zr)))
            end
        else
            index = 1
            for n in zpercents
                if n > value(xzoom)
                    break
                end
                index += 1
            end
            i = index
            push!(zr, zoom_percent(zpercents[i],value(zr)))
        end
    end

    # performs proportional zoom out
    function zoomout(center::XY{Int})
        global i
        if 1 <= i <= length(zpercents)
            if i > 1
                i -= 1
                push!(zr, zoom_percent(zpercents[i],value(zr),center))
            end
        else
            index = length(zpercents)
            for n in zpercents[end:-1:1] # loop backwards      
                if n < value(xzoom) 
                    break
                end
                index -= 1
            end
            i = index
            push!(zr, zoom_percent(zpercents[i],value(zr),center))
        end
    end

    function zoomout()
        global i
        if 1 <= i <= length(zpercents)
            if i > 1
                i -= 1
                push!(zr, zoom_percent(zpercents[i],value(zr)))
            end
        else
            index = length(zpercents)
            for n in zpercents[end:-1:1] # loop backwards      
                if n < value(xzoom) 
                    break
                end
                index -= 1
            end
            i = index
            push!(zr, zoom_percent(zpercents[i],value(zr)))
        end
    end

    # performs proportional, centered zoom to level entered
    function zoom_to(z::Float64)
        global i
        push!(zr, zoom_percent(z,value(zr)))
        i = -1
        nothing
    end

    showall(win);

    function zoom_clicked{T}(c::GtkReactive.Canvas,
                          zr::Signal{ZoomRegion{T}})
        # Left click calls zoomin() centered on pixel clicked
        # Right click calls zoomout() centered on pixel clicked
        dragging = Signal(false)
        moved = Signal(false)
        start = Signal(XY{UserUnit}(-1,-1))
        start_view = Signal(ZoomRegion((1:1,1:1)))

        sigclick = map(c.mouse.buttonpress) do btn
            push!(dragging,true)
            push!(moved,false)
            push!(start,btn.position)
            push!(start_view,value(zr))
        end

        dummybtn = MouseButton{UserUnit}()
        sigdrag = map(filterwhen(dragging, dummybtn, c.mouse.motion)) do btn
            # modify this so it only pushes if the view actually shifted
            # (fractions of pixels don't cause view to move)
            push!(moved,true)
        end


        sigend = map(c.mouse.buttonrelease) do btn
            if !value(moved) 
                #println("modifiers=",btn.modifiers)
                if btn.button == 1 && btn.modifiers == 256 #if left click & no modifiers
                    center = XY(Int(round(Float64(btn.position.x))),
                                Int(round(Float64(btn.position.y))))
                    zoomin(center) 
                elseif btn.button == 3 || btn.modifiers == 260 # right click/ctrl
                    center = XY(Int(round(Float64(btn.position.x))),
                                Int(round(Float64(btn.position.y))))
                    zoomout(center)
                end
            end
            push!(dragging,false) # no longer dragging
            push!(moved,false) # reset moved
        end
        append!(c.preserved, [moved, sigclick, sigdrag, sigend])
    end

    # zoom actions
    pandrag = init_pan_drag(c, zr) # dragging moves image
    zoom_ctrl = zoom_clicked(c, zr)

    append!(c.preserved, [zoom_ctrl, pandrag])
    nothing
end;

init_gui(file::AbstractString) = init_gui(load(file); name=file)

end # module
