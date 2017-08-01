function init_freehand_select(ctx::ImageContext)
    c = ctx.canvas
    enabled = Signal(true)
    drawing = Signal(false)
    moving = Signal(false)
    diff = Signal(XY(NaN,NaN))

    dummybtn = MouseButton{UserUnit}()
    
    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        if !ispolygon(value(ctx.points)) || !isinside(Point(btn.position), Point.(value(ctx.points))) # prevents conflict with init_move_polygon
            push!(drawing, true)
            push!(ctx.shape, Rectangle()) # some identifier of type of selection
            push!(ctx.points, [])
            push!(ctx.points, [btn.position])
        elseif ispolygon(value(ctx.points)) && isinside(Point(btn.position), Point.(value(ctx.points)))
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
        push!(ctx.points, move_polygon_to(value(ctx.points),XY(btn.position.x-value(diff).x, btn.position.y-value(diff).y)))
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

    push!(ctx.points, [])

    append!(c.preserved, [sigstart, sigdraw, sigmove, sigend])
    Dict("enabled"=>enabled)
end

function near_vertex(pt::XY, p)
    # returns index of nearby point
    for i in 1:length(p)
        if (p[i].x-5 <= pt.x <= p[i].x+5) && (p[i].y-5 <= pt.y <= p[i].y+5)
            return i
        end
    end
    return -1
end

function init_polygon_select(ctx::ImageContext)
    enabled = Signal(false)
    c = ctx.canvas

    dummybtn = MouseButton{UserUnit}()
    building = Signal(false)
    moving = Signal(false)
    modifying = Signal(false)
    num_pts = Signal(0)
    modhandle = Signal(-1)
    diff = Signal(XY(NaN,NaN))
    mouse_motion = map(enabled,building) do e,b
        #@show e,b
        if e == true && b == true
            true
        else
            false
        end
    end

    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        #println("Polygon enabled")
        if (ispolygon(value(ctx.points)) &&
            near_vertex(btn.position, value(ctx.points)) != -1)
            # modification actions
            #println("Modifying")
            push!(modifying,true)
            push!(building,false)
            push!(moving,false)
            push!(modhandle,near_vertex(btn.position,value(ctx.points)))
        elseif (ispolygon(value(ctx.points)) &&
                isinside(Point(btn.position),Point.(value(ctx.points))))
            # moving actions
            #println("Moving")
            push!(moving,true)
            push!(building,false)
            push!(modifying,false)
            push!(diff, XY(btn.position.x-value(ctx.points)[1].x,
                           btn.position.y-value(ctx.points)[1].y))
        elseif (ispolygon(value(ctx.points)) &&
                !isinside(Point(btn.position),Point.(value(ctx.points))))
            #println("Resetting")
            push!(building,true)
            # resets ctx.points
            push!(ctx.points,[])
            push!(num_pts, 0)
        elseif isempty(value(ctx.points)) # adds first point
            #println("First point")
            push!(building,true)
            push!(ctx.points, [btn.position])
            push!(num_pts,1)
        elseif !ispolygon(value(ctx.points)) # adds to polygon
            if (length(value(ctx.points)) > 3 &&
                value(ctx.points)[1].x - 5 <= btn.position.x <=
                value(ctx.points)[1].x + 5 && value(ctx.points)[1].y - 5
                <= btn.position.y <= value(ctx.points)[1].y + 5)
                # finishes polygon if click near start
                #println("Finishing")
                push!(ctx.points,
                      push!(value(ctx.points)[1:end-1],value(ctx.points)[1]))
                push!(num_pts, length(value(ctx.points)))
            else # adds to polygon
                #println("Adding")
                push!(ctx.points,push!(value(ctx.points)[1:end-1],btn.position))
                push!(num_pts, length(value(ctx.points)))
            end
        end
        nothing
    end

    # When building the polygon, makes working point
    sigbuild = map(filterwhen(mouse_motion,dummybtn, c.mouse.motion)) do btn
        #println(".")
        if !isempty(value(ctx.points)) && !ispolygon(value(ctx.points))
            push!(ctx.points,
                  push!(value(ctx.points)[1:value(num_pts)], btn.position))
        end
        nothing
    end

    # Moves polygon
    sigmove = map(filterwhen(moving,dummybtn,c.mouse.motion)) do btn
        # move polygon
        push!(ctx.points, move_polygon_to(value(ctx.points),XY(btn.position.x-value(diff).x,btn.position.y-value(diff).y)))
        nothing
    end

    # Modifies polygon by handle
    sigmodify = map(filterwhen(modifying,dummybtn,c.mouse.motion)) do btn
        # moves clicked point
        if value(modhandle) != 1 && value(modhandle) != -1
            # move a middle point
            A = value(ctx.points)
            splice!(A, value(modhandle), [btn.position])
            push!(ctx.points,A)
        elseif value(modhandle) != -1
            # move both first and last point
            A = value(ctx.points)[2:end-1]
            unshift!(A,btn.position)
            push!(A,btn.position)
            push!(ctx.points,A)
        end
        nothing
    end

    # Resets signals
    sigend = map(filterwhen(enabled,dummybtn,c.mouse.buttonrelease)) do btn
        #println(".")
        #@show value(moving)
        #@show value(modifying)
        #@show value(mouse_motion)
        # resets signals
        push!(moving,false)
        push!(modifying,false)
        push!(diff, XY(NaN,NaN))
        push!(modhandle, -1)
    end
    
    push!(ctx.points, [])
    
    append!(c.preserved, [sigstart, sigbuild, sigmove, sigmodify, sigend])
    Dict("enabled"=>enabled)
end

# figure out the VertexException for isinside

# draw square around region near start
# draw handles
