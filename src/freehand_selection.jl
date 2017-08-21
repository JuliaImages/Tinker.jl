# Functions for selecting freehand shapes and polygons.

function init_freehand_select(ctx::ImageContext)
    c = ctx.canvas
    enabled = Signal(true)
    drawing = Signal(false)
    moving = Signal(false)
    diff = Signal(XY(NaN,NaN))
    polygon = map(p->Polygon(p),ctx.points)

    dummybtn = MouseButton{UserUnit}()

    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        local isp
        local isin
        isp = ispolygon(value(ctx.points))
        try isin = isinside(Point(btn.position),Point.(value(ctx.points)))
        catch isin = false end
        if !isp || !isin
            # Initializing
            push!(drawing, true)
            push!(ctx.points, [btn.position])
            push!(ctx.shape,Polygon()) # shape is a polygon
        elseif isp && isin
            # Moving
            push!(moving,true)
            push!(diff, XY(btn.position.x-value(ctx.points)[1].x,
                           btn.position.y-value(ctx.points)[1].y))
        end
        nothing
    end

    sigdraw = map(filterwhen(drawing, dummybtn, c.mouse.motion)) do btn
        push!(ctx.points, push!(value(ctx.points), btn.position))
        nothing
    end

    sigmove = map(filterwhen(moving, dummybtn, c.mouse.motion)) do btn
        #push!(ctx.points, move_polygon_to(value(ctx.points),XY(btn.position.x-value(diff).x, btn.position.y-value(diff).y)))
        nothing
    end

    sigend = map(filterwhen(enabled, dummybtn, c.mouse.buttonrelease)) do btn
        # end
        push!(drawing,false)
        push!(moving,false)
        push!(diff, XY(NaN,NaN))
        if !isempty(value(ctx.points))
            push!(ctx.points, push!(value(ctx.points), value(ctx.points)[1]))
        end
        nothing
    end

    push!(ctx.points, Vector{XY{Float64}}[])

    append!(c.preserved, [sigstart, sigdraw, sigmove, sigend])
    Dict("enabled"=>enabled)
end

function near_vertex(pt::XY, p::Array, t::Float64)
    # returns index of nearby point
    for i in 1:length(p)
        if (p[i].x-t <= pt.x <= p[i].x+t) && (p[i].y-t <= pt.y <= p[i].y+t)
            return i
        end
    end
    return -1
end

function init_polygon_select(ctx::ImageContext)
    enabled = Signal(false)
    c = ctx.canvas
    tol = get_tolerance(ctx)

    dummybtn = MouseButton{UserUnit}()
    building = Signal(false)
    moving = Signal(false)
    modifying = Signal(false)
    num_pts = Signal(0)
    modhandle = Signal(-1)
    diff = Signal(XY(NaN,NaN))
    mouse_motion = map(&,enabled,building)
    polyhandle = map(ctx.points) do pts # this -> ctx.shape
      if !isempty(pts)
        PolyHandle(pts)
      else
        PolyHandle()
      end
    end

    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        pts = value(ctx.points)
        local isp
        local isin
        isp = ispolygon(pts)
        try isin = isinside(Point(btn.position),Point.(pts))
        catch isin = false end
        if (isp && near_vertex(btn.position,pts,tol) != -1)
            # modification actions
            push!(modifying,true)
            push!(building,false)
            push!(moving,false)
            push!(modhandle,near_vertex(btn.position,pts,tol))
        elseif (isp && isin)
            # moving actions
            push!(moving,true)
            push!(building,false)
            push!(modifying,false)
            push!(diff, XY(btn.position.x-pts[1].x,btn.position.y-pts[1].y))
        elseif (isp && !isin)
            push!(building,true)
            # reset ctx.points
            push!(ctx.points,Vector{XY{Float64}}[])
            push!(num_pts, 0)
        elseif isempty(pts) # adds first point
            push!(building,true)
            push!(ctx.points, [btn.position])
            push!(num_pts,1)
            push!(ctx.shape, PolyHandle()) # set up ctx.shape to track ph
        elseif !isp # adds to polygon
            if (length(pts) > 3 && pts[1].x-tol <= btn.position.x <=
                pts[1].x+tol && pts[1].y-tol <= btn.position.y <= pts[1].y+tol)
                # finishes polygon if click near start
                pts[end] = pts[1]
                push!(ctx.points,pts)
                push!(num_pts, length(pts))
            else # add to polygon
                value(ctx.points)[end] = btn.position
                push!(num_pts, length(pts))
            end
        end
        nothing
    end

    # When building the polygon, makes working point
    sigbuild = map(filterwhen(mouse_motion,dummybtn, c.mouse.motion)) do btn
        if !isempty(value(ctx.points)) && !ispolygon(value(ctx.points))
            push!(ctx.points,
                  push!(value(ctx.points)[1:value(num_pts)], btn.position))
        end
        nothing
    end

    # Moves polygon
    sigmove = map(filterwhen(moving,dummybtn,c.mouse.motion)) do btn
        #=push!(ctx.points, move_polygon_to(value(ctx.points),XY(btn.position.x-
              value(diff).x,btn.position.y-value(diff).y)))=#
        nothing
    end

    # Modifies polygon by handle
    sigmodify = map(filterwhen(modifying,dummybtn,c.mouse.motion)) do btn
        # moves clicked point
        #=pts = value(ctx.points)
        if value(modhandle) != 1 && value(modhandle) != -1
            # move a middle point
            pts[value(modhandle)] = btn.position
            push!(ctx.points, pts)
        elseif value(modhandle) != -1
            # move both first and last point
            pts[1] = btn.position
            pts[end] = btn.position
            push!(ctx.points,pts)
        end=#
        nothing
    end

    # Resets signals
    sigend = map(filterwhen(enabled,dummybtn,c.mouse.buttonrelease)) do btn
        push!(moving,false)
        push!(modifying,false)
        push!(diff, XY(NaN,NaN))
        push!(modhandle, -1)
    end

    push!(ctx.points, Vector{XY{Float64}}[])

    append!(c.preserved, [sigstart, sigbuild, sigmove, sigmodify, sigend])
    Dict("enabled"=>enabled)
end


function init_modify_shape(ctx::ImageContext)
    c = ctx.canvas
    enabled = Signal(false)
    #=tol = get_tolerance(ctx)
    # General signals
    moving = Signal(false)
    modr,modp = Signal(false),Signal(false)
    modind = Signal(-1)
    diff = Signal(XY(NaN,NaN))
    # Rectangle modification signals
    corners = Signal((XY{UserUnit}(-1.0,-1.0),XY{UserUnit}(-1.0,-1.0)))
    rh = map(c->two_point_rh(c[1],c[2]),corners)

    # Mouse action signals
    dummybtn = MouseButton{UserUnit}()
    # Initialize everything
    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        # conditionals
        pts = value(ctx.points)
        sh = value(ctx.shape)
        local nearpt
        if typeof(sh) == RectHandle
            nearpt = near_vertex(btn.position,value(rh),tol)
        elseif typeof(sh) == PolyHandle
            nearpt = near_vertex(btn.position,pts,tol)
        else nearpt = -1 end
        local isin
        try isin = isinside(Point(btn.position),Point.(pts)) catch isin = false end
        if nearpt > 0
            println("nearpt = $nearpt")
            typeof(sh) == RectHandle && push!(modr,true)
            typeof(sh) == PolyHandle && push!(modp,true)
            push!(moving,false)
            push!(modind,nearpt)
        elseif (ispolygon(pts) && isin)
            push!(moving,true)
            push!(modr,false)
            push!(modp,false)
            push!(diff, XY{Float64}(btn.position)-XY{Float64}(pts[1]))
        end
        nothing
    end

    # Move any shape
    sigmove = map(filterwhen(moving, dummybtn, c.mouse.motion)) do btn
        #push!(corners, (value(ctx.points)[1],value(ctx.points)[3]))
        println("moving")
        push!(ctx.points, move_polygon_to(value(ctx.points),XY(btn.position.x-
              value(diff).x,btn.position.y-value(diff).y)))
        nothing
    end

    # Modify rectangle
    sigrect = map(filterwhen(modr, dummybtn, c.mouse.motion)) do btn
        # modify
        println("modifying $(value(modind)) (r)")
        nothing
    end

    # Modify polygon
    sigpoly = map(filterwhen(modp,dummybtn,c.mouse.motion)) do btn
        # modify
        println("modifying $(value(modind)) (p)")
        nothing
    end

    sigend = map(filterwhen(enabled, dummybtn, c.mouse.buttonrelease)) do btn
        # reset signals
        push!(moving,false)
        push!(modr,false)
        push!(modp,false)
        push!(modind,-1)
        #push!(modpt,XY(NaN,NaN))
        nothing
    end

    append!(c.preserved, [sigstart,sigmove,sigrect,sigpoly,sigend])=#
    Dict("enabled"=>enabled)
end
