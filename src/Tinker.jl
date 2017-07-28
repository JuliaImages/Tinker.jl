module Tinker

using Gtk.ShortNames, GtkReactive, Graphics, Colors, Images, IntervalSets, Luxor.isinside, Luxor.Point

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
    mouseactions::Dict{String,Signal{Bool}}
    shape::Signal{<:Shape} # Tracks type of selection in the environment
    points::Signal{<:AbstractArray} # Holds points that define shape outline
    rectview::Signal{<:AbstractArray} # Holds bounding box of selection
end

ImageContext() = ImageContext(nothing, canvas(), Signal(ZoomRegion((1:10, 1:10))), -1, Dict("dummy"=>Signal(false)), Signal(Rectangle()), Signal([]), Signal([]))

# Returns a view of an image with the given bounding region
function get_view(image,x_min,y_min,x_max,y_max)
    xleft,yleft = Int(floor(Float64(x_min))),Int(ceil(Float64(y_min)))
    xright,yright = Int(floor(Float64(x_max))),Int(ceil(Float64(y_max)))
    min_x, max_x = map(x->x, extrema(indices(image,2)))
    min_y, max_y = map(y->y, extrema(indices(image,1)))
    (xleft < min_x) && (xleft = min_x)
    (yleft < min_y) && (yleft = min_y)
    (xright > max_x) && (xright = max_x)
    (yright > max_y) && (yright = max_y)
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

# Connects an array of points
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

# Checks if an array of points qualifies as a polygon
function ispolygon(p::AbstractVector)
    length(p) < 4 && return false
    p[1] != p[end] && return false
    for i in 1:(length(p)-1)
        p[i]!=p[i+1] && return true
    end
    return false
end

# Moves polygon to a given location
function move_polygon_to(p::AbstractArray, pt::XY)
    # find diff b/t start & pt; add diff to all in p
    diff = XY(pt.x-p[1].x,pt.y-p[1].y)
    map(n -> XY(n.x+diff.x,n.y+diff.y),p)
end

# Converts an XY to a Point
function Point(p::XY)
    Point(p.x,p.y)
end

# Mouse actions to move any polygon
function init_move_polygon(ctx::ImageContext)
    c = ctx.canvas
    pts = ctx.points
    enabled = Signal(true)
    dragging = Signal(false)
    diff = Signal(XY(NaN,NaN))

    dummybutton = MouseButton{UserUnit}()
    sigstart = map(filterwhen(enabled,dummybutton,c.mouse.buttonpress)) do btn
        if ispolygon(value(ctx.points)) # prevents conflict with init_freehand_select
            if isinside(Point(btn.position), Point.(value(pts)))
                push!(dragging,true)
                #push!(ctx.points, move_polygon_to(value(ctx.points),
                                                  #btn.position))
                push!(diff, XY(btn.position.x-value(ctx.points)[1].x,
                               btn.position.y-value(ctx.points)[1].y))
            end
        end
        nothing
    end

    sigdrag = map(filterwhen(dragging,dummybutton,c.mouse.motion)) do btn
        push!(ctx.points, move_polygon_to(value(ctx.points),XY(btn.position.x-value(diff).x, btn.position.y-value(diff).y)))
        nothing
    end

    sigend = map(filterwhen(dragging,dummybutton,c.mouse.buttonrelease)) do btn
        push!(dragging,false)
        push!(diff, XY(NaN,NaN))
        nothing
    end
    
    append!(c.preserved, [sigstart, sigdrag, sigend])
    Dict("enabled"=>enabled)
end

include("zoom_interaction.jl")
include("rectangle_selection.jl")
include("freehand_selection.jl")

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

    # Context
    imagectx = ImageContext(image, c, zr, 1, Dict("dummy"=>Signal(false)),
                            rect, points, Signal(view(image,1:size(image,2),
                                                      1:size(image,1))))

    rectview = map(imagectx.points) do pts
        if ispolygon(pts)
            x_min,x_max = minimum(map(n->n.x,pts)),maximum(map(n->n.x,pts))
            y_min,y_max =minimum(map(n->n.y,pts)),maximum(map(n->n.y,pts))
            get_view(image,x_min,y_min,x_max,y_max)
        else
            view(image,1:size(image,2),1:size(image,1))
        end
    end
    imagectx.rectview = rectview
        
    
    # Mouse actions
    pandrag = init_pan_drag(c, zr) # dragging moves image
    zoomclick = init_zoom_click(imagectx) # clicking zooms image
    rectselect = init_rect_select(imagectx) # click + drag modifies rect selection
    freehand = init_freehand_select(imagectx)
    movepol = init_move_polygon(imagectx)
    polysel = init_polygon_select(imagectx)
    push!(pandrag["enabled"],false)
    push!(zoomclick["enabled"],false)
    push!(rectselect["enabled"],false)
    push!(freehand["enabled"],false)
    push!(movepol["enabled"],false)
    push!(polysel["enabled"],false)

    imagectx.mouseactions = Dict("pandrag"=>pandrag["enabled"],"zoomclick"=>zoomclick["enabled"],"rectselect"=>rectselect["enabled"],"freehand"=>freehand["enabled"],"movepol"=>movepol["enabled"],"polysel"=>polysel["enabled"])
    
    append!(c.preserved, [pandrag, zoomclick, rectselect, freehand, movepol])

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
    push!(ctx.mouseactions["pandrag"], false)
    push!(ctx.mouseactions["zoomclick"], false)
    push!(ctx.mouseactions["rectselect"], false)
    push!(ctx.mouseactions["freehand"], false)
    push!(ctx.mouseactions["movepol"],false)
    push!(ctx.mouseactions["polysel"],false)
    if mode == 1 # turn on zoom controls
        println("Zoom mode")
        push!(ctx.mouseactions["pandrag"], true)
        push!(ctx.mouseactions["zoomclick"], true)
    elseif mode == 2 # turn on rectangular region selection controls
        println("Rectangle mode")
        push!(ctx.mouseactions["rectselect"], true)
    elseif mode == 3 # freehand select
        println("Freehand mode")
        push!(ctx.mouseactions["freehand"],true)
        println("Move mode")
        push!(ctx.mouseactions["movepol"],true)
    elseif mode == 4 # polygon select
        println("Polygon mode")
        push!(ctx.mouseactions["polysel"],true)
        push!(ctx.mouseactions["movepol"],true)
    end
end

set_mode(sig::Signal, mode) = set_mode(value(sig), mode)

end # module
