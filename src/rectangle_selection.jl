# Returns the handle near click or an empty handle
function nearby_handle(pt::XY, rh::RectHandle, t::Float64)
    for i in 1:length(rh.h)
        if (rh.h[i].x-t<=pt.x<=rh.h[i].x+t && rh.h[i].y-t<=pt.y<=rh.h[i].y+t)
            return rh.h[i]
        end
    end
    return Handle()
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

# For point-based modification
function get_p1(index::Int, rh::Array{XY})
    if isodd(index)
        index > 4 && return rh[index-4] # test this
        index < 4 && return rh[index+4]
    else
        (index == 2 || index == 8) && return rh[5]
        (index == 4 || index == 6) && return rh[1]
    end
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

# For point-based modification
function get_p2(index::Int, rh::Array{XY}, p::XY)
    if isodd(index)
        return p
    else
        index == 2 && return XY(rh[1].x, p.y)
        index == 4 && return XY(p.x, rh[5].y)
        index == 6 && return XY(rh[5].x, p.y)
        index == 8 && return XY(p.x, rh[1].y)
    end
end

# Returns array of all points that form rectangle made out of p1,p2
function two_point_rect(p1,p2)
    r = Rectangle(p1,p2)
    x,y,w,h = r.x,r.y,r.w,r.h
    return [XY(x,y),XY(x+w,y),XY(x+w,y+h),XY(x,y+h),XY(x,y)]
end

# Returns array of all points that form rectangle, plus midpoints on sides
function two_point_rh(p1,p2)
    r = Rectangle(p1,p2)
    x,y,w,h = r.x,r.y,r.w,r.h
    return [XY(x,y),XY(x+(w/2),y),XY(x+w,y),XY(x+w,y+(h/2)),XY(x+r.w,y+h),
    XY(x+(w/2),y+h),XY(x,y+h),XY(x,y+(h/2)),XY(x,y)]
end

# Mouse actions for rectangular selection creation and modification
function init_rect_select(ctx::ImageContext)
    c = ctx.canvas
    tol = get_tolerance(ctx)

    # Build rectangle & points array
    corners = Signal((XY{UserUnit}(-1.0,-1.0),XY{UserUnit}(-1.0,-1.0)))
    rh = map(c->two_point_rh(c[1],c[2]),corners)

    # Set of signals used for mouse action logic
    enabled = Signal(true)
    modifying = Signal(false)
    moving = Signal(false)
    initializing = Signal(false)
    modind = Signal(-1) # handle that was clicked
    diff = Signal(XY(0.0,0.0)) # difference b/t click & rect pos

    # Mouse action signals
    dummybtn = MouseButton{UserUnit}()
    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        cnr = value(corners)
        # Index of modification point near click, if exists
        local nearpt
        if typeof(value(ctx.shape)) == RectHandle
            nearpt = near_vertex(btn.position,value(rh),tol)
        else nearpt = -1 end
        # Calculates isinside with exception handling
        local isin
        try isin = isinside(Point(btn.position),Point.(value(ctx.points)))
        catch isin = false end
        if cnr[1]!=cnr[2] && nearpt > 0
            # Modification actions
            push!(modifying,true)
            push!(moving,false)
            push!(initializing,false)
            push!(modind,nearpt)
            push!(corners,(get_p1(nearpt,value(rh)),get_p2(nearpt,value(rh),btn.position)))
        elseif (cnr[1]!=cnr[2] && isin)
            # Motion actions
            push!(moving,true)
            push!(modifying,false)
            push!(initializing,false)
            push!(diff, XY{Float64}(btn.position)-XY{Float64}(value(ctx.points)[1]))#XY(btn.position.x-value(ctx.points)[1].x,btn.position.y-value(ctx.points)[1].y))
        elseif (cnr[1]==cnr[2] || !isin)
            # Build actions
            push!(initializing,true)
            push!(moving,false)
            push!(modifying,false)
            push!(corners,(btn.position,btn.position))
            push!(ctx.points,two_point_rect(btn.position,btn.position))
            push!(ctx.shape,RectHandle()) # shape is a RectHandle
        end
        nothing
    end

    # Modifies rectangle by handle
    sigmod = map(filterwhen(modifying, dummybtn, c.mouse.motion)) do btn
        cnr = value(corners)
        if value(modind) > 0
            push!(corners, (cnr[1],get_p2(value(modind),value(rh),btn.position)))
            push!(ctx.points,two_point_rect(cnr[1],get_p2(value(modind),value(rh),btn.position)))
        end
        nothing
    end

    # Moves rectangle
    sigmove = map(filterwhen(moving, dummybtn, c.mouse.motion)) do btn
        # move
        push!(corners, (value(ctx.points)[1],value(ctx.points)[3]))
        push!(ctx.points, move_polygon_to(value(ctx.points),XY(btn.position.x-
              value(diff).x,btn.position.y-value(diff).y)))
        nothing
    end

    # Builds rectangle
    siginit = map(filterwhen(initializing,dummybtn,c.mouse.motion)) do btn
        # init
        cnr = value(corners)
        push!(corners,(cnr[1],btn.position))
        push!(ctx.points,two_point_rect(cnr[1],btn.position))
        nothing
    end

    # Reset signals
    sigend = map(filterwhen(enabled, dummybtn, c.mouse.buttonrelease)) do btn
        push!(moving,false)
        push!(modifying,false)
        push!(initializing,false)
        nothing
    end

    push!(ctx.points, Vector{XY{Float64}}[])

    append!(c.preserved, [sigstart, siginit, sigmod, sigmove, sigend])
    Dict("enabled"=>enabled)
end
