# Returns true if a handle is clicked
function is_clicked(pt::XY, handle::Handle, d)
    return (handle.x - d/2 < pt.x < handle.x + d/2) &&
        (handle.y - d/2 < pt.y < handle.y + d/2)
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
        println("Starting")
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
        nothing
    end

    push!(ctx.points, [])

    append!(c.preserved, [sigstart, sigdrag, sigend])
    Dict("enabled"=>enabled)
end
