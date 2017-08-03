# Returns the handle near click or an empty handle
function nearby_handle(pt::XY, rh::RectHandle, t::Float64)
    for i in 1:length(rh.h)
        if (rh.h[i].x-t <= pt.x <= rh.h[i].x+t &&
            rh.h[i].y-t <= pt.y <= rh.h[i].y+t)
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
    tol = get_tolerance(ctx)

    # Build rectangle & points array
    pts = Signal((XY{UserUnit}(-1.0,-1.0),XY{UserUnit}(-1.0,-1.0)))
    rect = map(p->Rectangle(p[1],p[2]),pts)
    recthandle = map(r->RectHandle(r),rect) # this -> ctx.shape
    ctx.points = map(rect) do r
        [XY(r.x,r.y),XY(r.x+r.w,r.y),XY(r.x+r.w,r.y+r.h),XY(r.x,r.y+r.h),
         XY(r.x,r.y)]
    end

    # Set of signals used for mouse action logic
    enabled = Signal(true)
    modifying = Signal(false)
    moving = Signal(false)
    initializing = Signal(false)
    modhandle = Signal(Handle()) # handle that was clicked
    diff = Signal(XY(0.0,0.0)) # difference b/t click & rect pos

    # Mouse action signals
    dummybtn = MouseButton{UserUnit}()
    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        hn = nearby_handle(btn.position,value(recthandle),tol)
        if !isempty(value(rect)) && !isempty(hn)
            # Handle actions
            push!(modifying,true)
            push!(moving,false)
            push!(initializing,false)
            push!(modhandle,hn)
            push!(pts, (get_p1(hn, value(recthandle)),
                        get_p2(hn, value(recthandle),btn)))
        elseif (!isempty(value(rect)) && Float64(value(rect).x) <
                Float64(btn.position.x) < Float64(value(rect).x+value(rect).w)
                && Float64(value(rect).y) < Float64(btn.position.y) <
                Float64(value(rect).y+value(rect).h))
            # Motion actions
            push!(moving,true)
            push!(modifying,false)
            push!(initializing,false)
            push!(diff, XY(btn.position.x-value(rect).x,
                           btn.position.y-value(rect).y))
        elseif isempty(value(rect)) || !(Float64(value(rect).x) <
               Float64(btn.position.x) < Float64(value(rect).x+value(rect).w)
               && Float64(value(rect).y) < Float64(btn.position.y) <
                                         Float64(value(rect).y+value(rect).h))
            # Build actions
            push!(initializing,true)
            push!(moving,false)
            push!(modifying,false)
            push!(pts,(btn.position,btn.position))
        end
        nothing
    end

    # Modifies rectangle by handle
    sigmod = map(filterwhen(modifying, dummybtn, c.mouse.motion)) do btn
        if !isempty(value(modhandle))
            push!(pts, (value(pts)[1],
                        get_p2(value(modhandle),value(recthandle),btn)))
        end
        nothing
    end

    # Moves rectangle
    sigmove = map(filterwhen(moving, dummybtn, c.mouse.motion)) do btn
        # move
        push!(pts,(XY(btn.position.x-value(diff).x,
                      btn.position.y-value(diff).y),
                   XY((btn.position.x-value(diff).x)+value(rect).w,
                      (btn.position.y-value(diff).y)+value(rect).h)))
        nothing
    end

    # Builds rectangle
    siginit = map(filterwhen(initializing,dummybtn,c.mouse.motion)) do btn
        # init
        push!(pts, (value(pts)[1],btn.position))
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

    append!(c.preserved, [sigstart, sigmod, sigmove, siginit, sigend])
    Dict("enabled"=>enabled)
end
