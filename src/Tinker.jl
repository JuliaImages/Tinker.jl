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
Base.isempty(R::Rectangle) = R.w <= 0 || R.h <= 0

# Creates a Rectangle out of any two points
function Rectangle(p1::XY,p2::XY)
    x, w = min(p1.x, p2.x), abs(p2.x - p1.x)
    y, h = min(p1.y, p2.y), abs(p2.y - p1.y)
    return Rectangle(x, y, w, h)
    (p1.x == p2.x) || (p1.y == p2.y) && return Rectangle()
end

# rectangle draw function
function drawrect(ctx, rect, color)
    set_source(ctx, color)
    rectangle(ctx, rect.x, rect.y, rect.w, rect.h)
    stroke(ctx)
end;

# Handles modify rectangles (extend to other shapes later)
struct Handle
    r::Rectangle
    pos::String # refers to which side or corner of rectangle handle is on
    x::Float64
    y::Float64
end

Handle() = Handle(Rectangle(),"",0,0)
Base.isempty(H::Handle) = isempty(H.r)

# Creates handle given a Rectangle and a position
function Handle(r::Rectangle, pos::String)
    # Position of handle refers to center coordinate of handle based on rect
    position_coord = Dict("tlc"=>(r.x,r.y),"ts"=>(r.x+(r.w/2),r.y),
                          "trc"=>(r.x+r.w,r.y),"rs"=>(r.x+r.w,r.y+(r.h/2)),
                          "brc"=>(r.x+r.w,r.y+r.h),"bs"=>(r.x+(r.w/2),r.y+r.h),
                          "blc"=>(r.x,r.y+r.h),"ls"=>(r.x,r.y+(r.h/2)))
    xy = get(position_coord, pos, (-Inf,-Inf))
    if xy == (-Inf,-Inf)
        println("Not a valid Handle position.")
        return Handle()
    else
        x = position_coord[pos][1]
        y = position_coord[pos][2]
        return Handle(r,pos,xy[1],xy[2])
    end
end

# Draws a handle
function drawhandle(ctx, handle::Handle, color)
    if !isempty(handle)
        set_source(ctx,color)
        d = 8 # physical dimension of handle
        rectangle(ctx, handle.x-(d/2), handle.y-(d/2),
                  d, d)
        stroke(ctx)
    end
end; # like drawrect, but makes x,y refer to center of handle

# Returns true if a handle is clicked
function is_clicked(pt::XY, handle::Handle)
    return (handle.x - 5 < pt.x < handle.x + 5) &&
        (handle.y - 5 < pt.y < handle.y + 5)
end

# A rectangle with handles at all 8 positions
struct RectHandle
    r::Rectangle
    h::NTuple{8,Handle}
end

RectHandle() = RectHandle(Rectangle())
Base.isempty(RH::RectHandle) = isempty(RH.r)

# Creates a RectHandle given just a Rectangle
function RectHandle(r::Rectangle)
    # derive all 8 handles from r
    # numbered 1-8, 1=tlc, moving clockwise around rectangle
    h = (Handle(r, "tlc"), Handle(r, "ts"), Handle(r, "trc"), Handle(r, "rs"),
         Handle(r, "brc"), Handle(r, "bs"), Handle(r, "blc"), Handle(r, "ls"))
    return RectHandle(r,h)
end

# Draws RectHandle
function drawrecthandle(ctx, rh::RectHandle, color1, color2)
    drawrect(ctx, rh.r, color1)
    for n in 1:length(rh.h)
        drawhandle(ctx, rh.h[n], color2)
    end
end

# Given a RectHandle and a position, returns the corresponding Handle
function get_handle(rh::RectHandle, pos::String)
    for i in 1:8
        pos == rh.h[i].pos && return rh.h[i]
    end
    println("Not a valid position")
    return Handle()
end

# Gets anchor point for modification by handle
function get_p1(h::Handle, rh::RectHandle)
    opposite_dict = Dict('b'=>"t", 't'=>"b", 'l'=>"r", 'r'=>"l")
    if h.pos[end] == 'c' # 'h' is a corner
        opp_pos = ""
        # build pos string for opposite corner
        opp_pos *= opposite_dict[h.pos[1]]
        opp_pos *= opposite_dict[h.pos[2]]
        opp_pos *= "c"
        # set p1
        opposite = get_handle(rh, opp_pos) # Handle object
        p1 = XY{UserUnit}(opposite.x,opposite.y) # XY object
    elseif h.pos[end] == 's' # 'h' is a side
        if h.pos == "ts"
            # modify top
            p1 = XY{UserUnit}(rh.h[5].x,rh.h[5].y)
        elseif h.pos == "rs"
            # modify right
            p1 = XY{UserUnit}(rh.r.x, rh.r.y)
        elseif h.pos == "bs"
            # modify bottom
            p1 = XY{UserUnit}(rh.r.x, rh.r.y)
        elseif h.pos == "ls"
            # modify left
            p1 = XY{UserUnit}(rh.h[5].x,rh.h[5].y)
        end
    else
        println("Invalid position in get_p1")
        p1 = XY{UserUnit}(0,0)
    end
    return p1
end

# Gets dynamic point for modification by handle
function get_p2(h::Handle, rh::RectHandle, btn)
    if h.pos[end] == 'c' # 'h' is a corner
        p2 = XY{UserUnit}(btn.position.x, btn.position.y)
    elseif h.pos[end] == 's' # 'h' is a side
        if h.pos == "ts"
            # modify top
            p2 = XY{UserUnit}(rh.r.x, btn.position.y)
        elseif h.pos == "rs"
            # modify right
            p2 = XY{UserUnit}(btn.position.x, rh.h[5].y)
        elseif h.pos == "bs"
            # modify bottom
            p2 = XY{UserUnit}(rh.h[5].x, btn.position.y)
        elseif h.pos == "ls"
            # modify left
            p2 = XY{UserUnit}(btn.position.x, rh.r.y)
        end
    else
        println("Invalid position in get_p2")
        p2 = XY{UserUnit}(0,0)
    end
    return p2
end

# Zooms zr to the decimal % entered; view centered around center XY
function zoom_percent(z::Float64, zr::ZoomRegion, center::XY{Int})
    # Calculate size of new view
    fsize = XY(zr.fullview.x.right,zr.fullview.y.right) # full size
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
    return zoom_percent(z,zr,find_center(zr))
end

# Finds rounded center point of the current view of given ZoomRegion
function find_center(zr::ZoomRegion)
    range = zr.currentview
    csize = XY(range.x.right-range.x.left,range.y.right-range.y.left)
    center = XY(range.x.left+Int(floor(csize.x/2)),
                range.y.left+Int(floor(csize.y/2)))
    return center
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

    # Returns index of next zoom level after current in zpercents,
    # even if current zoom level is not in zpercents
    function next_zoom()
        index = 1
        for n in zpercents
            if n > value(xzoom)
                break
            end
            index += 1
        end
        return index
    end
    
    # Returns index of zoom level before current in zpercents
    function prev_zoom()
        index = length(zpercents)
        for n in zpercents[end:-1:1] # loop backwards      
            if n < value(xzoom) 
                break
            end
            index -= 1
        end
        return index
    end

    # performs proportional zoom in
    function zoom_in(center::XY{Int})
        global i
        if 1 <= i <= length(zpercents)
            if i < length(zpercents)
                i += 1
                push!(zr, zoom_percent(zpercents[i],value(zr),center))
            end
        else
            i = next_zoom()
            push!(zr, zoom_percent(zpercents[i],value(zr),center))
        end
    end

    # Automatically centered zoom_in
    function zoom_in()
        zoom_in(find_center(value(zr)))
    end

    # Performs proportional zoom out; centers on given XY
    function zoom_out(center::XY{Int})
        global i
        if 1 <= i <= length(zpercents)
            if i > 1
                i -= 1
                push!(zr, zoom_percent(zpercents[i],value(zr),center))
            end
        else
            i = prev_zoom()
            push!(zr, zoom_percent(zpercents[i],value(zr),center))
        end
    end

    # Automatically centered zoom_out
    function zoom_out()
        zoom_out(find_center(value(zr)))
    end

    # performs proportional, centered zoom to level entered
    function zoom_to(z::Float64)
        global i
        i = -1
        push!(zr, zoom_percent(z,value(zr)))
        nothing
    end

    # Mouse actions for zoom
    function zoom_clicked{T}(c::GtkReactive.Canvas,
                             zr::Signal{ZoomRegion{T}})
        enabled = Signal(true)
        # Left click calls zoom_in() centered on pixel clicked
        # Right click calls zoom_out() centered on pixel clicked
        dragging = Signal(false)
        moved = Signal(false)
        start = Signal(XY{UserUnit}(-1,-1))
        start_view = Signal(ZoomRegion((1:1,1:1)))

        dummybtn = MouseButton{UserUnit}()
        sigclick = map(filterwhen(enabled,dummybtn,c.mouse.buttonpress)) do btn
            push!(dragging,true)
            push!(moved,false)
            push!(start,btn.position)
            push!(start_view,value(zr))
        end

        sigdrag = map(filterwhen(dragging, dummybtn, c.mouse.motion)) do btn
            # modify this so it only pushes if the view actually shifted
            # (fractions of pixels don't cause view to move)
            push!(moved,true)
        end

        sigend = map(filterwhen(dragging,dummybtn,c.mouse.buttonrelease)) do btn
            if !value(moved)
                #println("modifiers=",btn.modifiers)
                if btn.button == 1 && btn.modifiers == 256 #if left click & no modifiers
                    center = XY(Int(round(Float64(btn.position.x))),
                                Int(round(Float64(btn.position.y))))
                    zoom_in(center) 
                elseif btn.button == 3 || btn.modifiers == 260 # right click/ctrl
                    center = XY(Int(round(Float64(btn.position.x))),
                                Int(round(Float64(btn.position.y))))
                    zoom_out(center)
                end
            end
            push!(dragging,false) # no longer dragging
            push!(moved,false) # reset moved
        end
        append!(c.preserved, [moved, sigclick, sigdrag, sigend])
        Dict("enabled"=>enabled)
    end

# Holds data about rectangular selection
rect = Signal(Rectangle())
# Creates RectHandle object dependent on rect
    recthandle = map(rect) do r
        RectHandle(r)
    end

# Mouse actions for selection creation and modification
function rect_select{T}(c::GtkReactive.Canvas, zr::Signal{ZoomRegion{T}})
    enabled = Signal(true)
    dragging = Signal(false) # true if mouse was pressed down before it was moved
    modifying = Signal(false) # true if there is an existing rectangle &
    # user clicked somewhere on it
    p1 = Signal(XY{UserUnit}(-1.0,-1.0)) # ints or floats? -> make ints
    p2 = Signal(XY{UserUnit}(-1.0,-1.0))
    modhandle = Signal(Handle()) # handle that was clicked
    locmod = Signal(false) # true if modifying rectangle location
    diff = Signal(XY(0.0,0.0)) # difference between btn.position of sigstart &
                        # top left corner of rectangle - used for moving rect

    dummybtn = MouseButton{UserUnit}()
    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        push!(dragging, true)
        # If there is already a rectangle in the environment, begin to modify
        if !isempty(value(recthandle))
            push!(modifying,true)
            # Identify if click is inside handle
            current = Handle()
            for n in 1:length(value(recthandle).h)
                if is_clicked(btn.position, value(recthandle).h[n])
                    current = value(recthandle).h[n]
                    push!(modhandle, current)
                    break
                end
            end
            # If the click was on a handle:
            if !isempty(current)
                push!(p1, get_p1(current, value(recthandle)))
                push!(p2, get_p2(current, value(recthandle), btn))
            elseif (value(rect).x<btn.position.x<value(rect).x+value(rect).w) &&
                    (value(rect).y<btn.position.y<value(rect).y+value(rect).h)
                push!(locmod,true)
                # the difference between click and rectangle corner
                push!(diff, XY(Float64(btn.position.x) - value(rect).x,
                               Float64(btn.position.y) - value(rect).y))
            else
                # Destroy rectangle and allow for a new one to be created
                push!(modifying,false)
                push!(rect, Rectangle())
                push!(p1, btn.position)
                push!(p2, btn.position)
            end
        # If there isn't a rectangle in the environment, begin to build one
        else
            push!(modifying,false)
            push!(p1,btn.position) # get values?
            push!(p2,btn.position)
        end
        nothing
    end

    sigdrag = map(filterwhen(dragging, dummybtn, c.mouse.motion)) do btn
        # If we are modifying an existing rectangle:
        if value(modifying)
            if !isempty(value(modhandle))
                push!(p2, get_p2(value(modhandle), value(recthandle), btn))
                push!(rect, Rectangle(XY(Float64(value(p1).x), Float64(value(p1).y)), XY(Float64(value(p2).x), Float64(value(p2).y)))) #make better
            elseif value(locmod) # if modifying the location
                # move rectangle
                w = value(rect).w
                h = value(rect).h
                push!(rect, Rectangle(btn.position.x-value(diff).x,
                                      btn.position.y-value(diff).y, w,h))
            end
        # If we are building a new rectangle:
        else
            push!(p2,btn.position)
            push!(rect, Rectangle(XY(Float64(value(p1).x), Float64(value(p1).y)), XY(Float64(value(p2).x), Float64(value(p2).y)))) #make better
        end
        nothing
    end

    sigend = map(filterwhen(dragging, dummybtn, c.mouse.buttonrelease)) do btn
        push!(dragging,false)
        # End modification actions
        if value(modifying)
            push!(locmod,false)
            push!(modhandle, Handle())
        # End build actions
        elseif !isempty(value(recthandle))
            push!(p2,btn.position)
            push!(rect, Rectangle(XY(Float64(value(p1).x), Float64(value(p1).y)), XY(Float64(value(p2).x), Float64(value(p2).y)))) #make better
        end
        nothing
    end

    append!(c.preserved, [sigstart, sigdrag, sigend])
    Dict("enabled"=>enabled)
end



    # mouse actions
    pandrag = init_pan_drag(c, zr) # dragging moves image
zoom_ctrl = zoom_clicked(c, zr) # clicking zooms image
rectselect = rect_select(c,zr) # click + drag creates/modifies rect selection
push!(pandrag["enabled"], false)
push!(zoom_ctrl["enabled"], false)
#push!(rectselect["enabled"], false)

# draw
    redraw = draw(c, imagesig, zr, viewdim, recthandle) do cnvs, img, r, vd, rh
        copy!(cnvs, img) # show image on canvas at current zoom level
        set_coordinates(cnvs, r) # set canvas coordinates to zr
        ctx = getgc(cnvs)
        # draw view diagram if zoomed in
        if r.fullview != r.currentview
            drawrect(ctx, vd[1], colorant"blue")
            drawrect(ctx, vd[2], colorant"blue")
        end
        drawrecthandle(ctx, rh, colorant"blue", colorant"white")
    end

showall(win);

append!(c.preserved, [zoom_ctrl, pandrag, rectselect])

end;

init_gui(file::AbstractString) = init_gui(load(file); name=file)

end # module
