module Tinker

using Gtk.ShortNames, GtkReactive, Graphics, Colors, Images, IntervalSets

img_ctxs = Signal([])

abstract type Shape end

# Rectangle structure
struct Rectangle <: Shape
    x::Number
    y::Number
    w::Number
    h::Number
    pts::AbstractArray
end

Rectangle() = Rectangle(0,0,-1,-1, [])
Base.isempty(R::Rectangle) = R.w <= 0 || R.h <= 0

mutable struct ImageContext{T}
    image
    canvas::GtkReactive.Canvas
    zr::Signal{ZoomRegion{T}}
    zl::Int # for tracking zoom level
    pandrag::Signal{Bool} # pandrag enabled for this context
    zoomclick::Signal{Bool} # zoomclick enabled for this context
    rectselect::Signal{Bool} # etc
    freehand::Signal{Bool}
    shape::Signal{<:Shape} # Tracks type of selection in the environment
    points::Signal{<:AbstractArray} # Holds points that define shape outline
    rectview::Signal{<:AbstractArray} # Holds rectangular region corresponding to outline
end

ImageContext() = ImageContext(nothing, canvas(), Signal(ZoomRegion((1:10, 1:10))), -1, Signal(false), Signal(false), Signal(false), Signal(false), Signal(Rectangle()), Signal([]), Signal([]))

function get_view(image,x_min,y_min,x_max,y_max)
    xleft,yleft = Int(floor(Float64(x_min))),Int(floor(Float64(y_min)))
    xright,yright = Int(floor(Float64(x_max))),Int(floor(Float64(y_max)))
    (xleft < 1) && (xleft = 1)
    (yleft < 1) && (yleft = 1)
    (xright > size(image,2)) && (xright = size(image,2))
    (yright > size(image,1)) && (yright = size(image,1))
    return view(image, yleft:yright, xleft:xright)
end

# Creates a Rectangle out of x,y,w,h
function Rectangle(x,y,w,h)
    pts = [XY(x,y), XY(x+w,y), XY(x+w,y+h), XY(x,y+h), XY(x,y)]
    return Rectangle(x,y,w,h,pts)
end

# Creates a Rectangle out of any two points
function Rectangle(p1::XY,p2::XY)
    x, w = min(p1.x, p2.x), abs(p2.x - p1.x)
    y, h = min(p1.y, p2.y), abs(p2.y - p1.y)
    return Rectangle(x, y, w, h)
    (p1.x == p2.x) || (p1.y == p2.y) && return Rectangle()
end

# rectangle draw function
function drawrect(ctx, rect, color, width)
    set_source(ctx, color)
    set_line_width(ctx, width)
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
function drawhandle(ctx, handle::Handle, d)
    if !isempty(handle)
        rectangle(ctx, handle.x-(d/2), handle.y-(d/2),
                  d, d)
        set_source(ctx,colorant"white")
        fill_preserve(ctx)
        set_source(ctx,colorant"black")
        set_line_width(ctx,1.0)
        stroke_preserve(ctx)
    end
end; # like drawrect, but makes x,y refer to center of handle

# Returns true if a handle is clicked
function is_clicked(pt::XY, handle::Handle, d)
    return (handle.x - d/2 < pt.x < handle.x + d/2) &&
        (handle.y - d/2 < pt.y < handle.y + d/2)
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
function drawrecthandle(ctx, rh::RectHandle, d, color1, width)
    drawrect(ctx, rh.r, color1, width)
    for n in 1:length(rh.h)
        drawhandle(ctx, rh.h[n], d)
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

# Mouse actions for rectangular selection creation and modification
function init_rect_select(ctx::ImageContext)
    c = ctx.canvas
    #rect = ctx.shape
    # Define limits of rectangle
    p1 = Signal(XY{UserUnit}(-1.0,-1.0))
    p2 = Signal(XY{UserUnit}(-1.0,-1.0))
    
    rect = map(p1,p2) do point1,point2
        Rectangle(point1,point2)
    end
    
    recthandle = map(rect) do r
         RectHandle(r)
    end
    
    # Set of signals used for mouse action logic
    enabled = Signal(true)
    dragging = Signal(false) #true if mouse was pressed down before it was moved
    modifying = Signal(false) # true if !isempty(rect) & user clicked inside it
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
            d = 8*(IntervalSets.width(value(ctx.zr).currentview.x)/IntervalSets.width(value(ctx.zr).fullview.x)) # physical dimension of handle
            for n in 1:length(value(recthandle).h)
                if is_clicked(btn.position, value(recthandle).h[n], d)
                    current = value(recthandle).h[n]
                    push!(modhandle, current)
                    break
                end
            end
            # If the click was on a handle:
            if !isempty(current)
                push!(p1, get_p1(current, value(recthandle)))
                push!(p2, get_p2(current, value(recthandle), btn))
            # If the click was inside the rectangle:
            elseif (Float64(value(rect).x)<Float64(btn.position.x)<Float64(value(rect).x+value(rect).w)) && (Float64(value(rect).y)<Float64(btn.position.y)<Float64(value(rect).y+value(rect).h))
                push!(locmod,true)
                # the difference between click and rectangle corner
                push!(diff, XY(Float64(btn.position.x) - value(rect).x,
                               Float64(btn.position.y) - value(rect).y))            else
                # Destroy rectangle and allow for a new one to be created
                push!(modifying,false)
                push!(ctx.shape, Rectangle())
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
                push!(ctx.shape, value(rect))
            elseif value(locmod) # if modifying the location
                # move rectangle
                push!(p1, XY(btn.position.x-value(diff).x,
                             btn.position.y-value(diff).y))
                push!(p2, XY((btn.position.x-value(diff).x)+value(rect).w,
                             (btn.position.y-value(diff).y)+value(rect).h))
                push!(ctx.shape, value(rect))
            end
            # If we are building a new rectangle:
        else
            push!(p2,btn.position)
            push!(ctx.shape,value(rect))
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
            push!(ctx.shape,value(rect))
        end
        if isempty(value(rect)) # rect hasn't been initialized
            # rectview is the full image
            push!(ctx.rectview, view(ctx.image,
                                     1:size(ctx.image,1), 1:size(ctx.image,2)))
        else # calculate rectview
            push!(ctx.rectview, get_view(ctx.image,
                                         min(value(p1).x,value(p2).x),
                                         min(value(p1).y,value(p2).y),
                                         max(value(p1).x,value(p2).x),
                                         max(value(p1).y,value(p2).y)))
        end
        nothing
    end

    append!(c.preserved, [sigstart, sigdrag, sigend])
    Dict("enabled"=>enabled)
end


function drawline(ctx, l, color, width)
    isempty(l) && return
    p = first(l)
    move_to(ctx, p.x, p.y) 
    set_source(ctx, color)
    set_line_width(ctx, width)
    for i = 2:length(l)
        p = l[i] 
        line_to(ctx, p.x, p.y)
    end
    stroke(ctx)
end

function init_freehand_select(ctx::ImageContext)
    c = ctx.canvas
    enabled = Signal(true)
    dragging = Signal(false)

    dummybtn = MouseButton{UserUnit}()

    min_x = Signal(1.0)
    max_x = Signal(Float64(size(ctx.image,2)))
    min_y = Signal(1.0)
    max_y = Signal(Float64(size(ctx.image,1)))

    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        push!(dragging, true)
        push!(ctx.shape, Rectangle()) # some identifier of type of selection
        push!(ctx.points, [])
        push!(ctx.points, [btn.position])
        # initialize max and min
        push!(min_x,btn.position.x)
        push!(max_x,btn.position.x)
        push!(min_y,btn.position.y)
        push!(max_y,btn.position.y)
    end

    sigdrag = map(filterwhen(dragging, dummybtn, c.mouse.motion)) do btn
        push!(ctx.points, push!(value(ctx.points), btn.position))
        if btn.position.x < value(min_x)
            push!(min_x,btn.position.x)
        elseif btn.position.x > value(max_x)
            push!(max_x,btn.position.x)
        end
        if btn.position.y < value(min_y)
            push!(min_y,btn.position.y)
        elseif btn.position.y > value(max_y)
            push!(max_y,btn.position.y)
        end
    end

    sigend = map(filterwhen(dragging, dummybtn, c.mouse.buttonrelease)) do btn
        # end
        push!(dragging,false)
        #push!(ctx.extrema, (XY(x_min,y_min),XY(x_max,y_max)))
        if !isempty(value(ctx.points))
            push!(ctx.points, push!(value(ctx.points), value(ctx.points)[1]))
        end
        if isempty(value(ctx.points)) # rect hasn't been initialized
            # rectview is the full image
            push!(ctx.rectview, view(ctx.image,
                                     1:size(ctx.image,1), 1:size(ctx.image,2)))
        else # calculate rectview
            push!(ctx.rectview, get_view(ctx.image,value(min_x),value(min_y),
                                         value(max_x),value(max_y)))
        end
    end

    append!(c.preserved, [sigstart, sigdrag, sigend])
    Dict("enabled"=>enabled)
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

    # Holds data about rectangular selection
    rect = Signal(Rectangle())
    points = map(rect) do r
        r.pts
    end
    # Creates RectHandle object dependent on rect
    #=
    recthandle = map(rect) do r
        RectHandle(r)
    end
=#  

    # Context
    imagectx = ImageContext(image, c, zr, 1, Signal(false), Signal(false),
                            Signal(false), Signal(false), rect, points,
                            Signal(view(image,1:size(image,2),1:size(image,1))))
    
    # Mouse actions
    pandrag = init_pan_drag(c, zr) # dragging moves image
    zoomclick = init_zoom_click(imagectx) # clicking zooms image
    rectselect = init_rect_select(imagectx) # click + drag modifies rect selection
    freehand = init_freehand_select(imagectx)
    push!(pandrag["enabled"],false)
    push!(zoomclick["enabled"],false)
    push!(rectselect["enabled"],false)
    push!(freehand["enabled"],false)
    
    imagectx.pandrag = pandrag["enabled"]
    imagectx.zoomclick = zoomclick["enabled"]
    imagectx.rectselect = rectselect["enabled"]
    imagectx.freehand = freehand["enabled"]
    
    append!(c.preserved, [zoomclick, pandrag, rectselect, freehand])

    # draw
    redraw = draw(c, imagesig, zr, viewdim, imagectx.points) do cnvs, img, r, vd, pt
        copy!(cnvs, img) # show image on canvas at current zoom level
        set_coordinates(cnvs, r) # set canvas coordinates to zr
        ctx = getgc(cnvs)
        # draw view diagram if zoomed in
        if r.fullview != r.currentview
            drawrect(ctx, vd[1], colorant"blue", 2.0)
            drawrect(ctx, vd[2], colorant"blue", 2.0)
        end
        #d = 8*(IntervalSets.width(r.currentview.x)/IntervalSets.width(r.fullview.x)) # physical dimension of handle
        drawline(ctx, pt, colorant"yellow", 1.0)
    end

    showall(win);
    
    push!(img_ctxs, push!(value(img_ctxs), imagectx))
    return imagectx
end;

init_gui(file::AbstractString) = init_gui(load(file); name=file)

active_context = map(img_ctxs) do ic # signal dependent on img_ctxs
    if isempty(ic)
        # placeholder value of appropriate type
        ImageContext()
    else
        ic[end] # currently gets last element of img_ctxs
    end
end

function set_mode(ctx::ImageContext, mode::Int)
    push!(ctx.pandrag, false)
    push!(ctx.zoomclick, false)
    push!(ctx.rectselect, false)
    push!(ctx.freehand, false)
    if mode == 1 # turn on zoom controls
        println("Zoom mode")
        push!(ctx.pandrag, true)
        push!(ctx.zoomclick, true)
    elseif mode == 2 # turn on rectangular region selection controls
        println("Rectangle mode")
        push!(ctx.rectselect, true)
    elseif mode == 3 # freehand select
        println("Freehand mode")
        push!(ctx.freehand,true)
    end
end

end # module
