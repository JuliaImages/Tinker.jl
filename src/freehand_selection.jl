function init_freehand_select(ctx::ImageContext)
    c = ctx.canvas
    enabled = Signal(true)
    dragging = Signal(false)

    dummybtn = MouseButton{UserUnit}()
    
    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        if !ispolygon(value(ctx.points)) || !isinside(Point(btn.position), Point.(value(ctx.points))) # prevents conflict with init_move_polygon
            push!(dragging, true)
            push!(ctx.shape, Rectangle()) # some identifier of type of selection
            push!(ctx.points, [])
            push!(ctx.points, [btn.position])
        end
    end

    sigdrag = map(filterwhen(dragging, dummybtn, c.mouse.motion)) do btn
        push!(ctx.points, push!(value(ctx.points), btn.position))
    end

    sigend = map(filterwhen(dragging, dummybtn, c.mouse.buttonrelease)) do btn
        # end
        push!(dragging,false)
        #push!(ctx.extrema, (XY(x_min,y_min),XY(x_max,y_max)))
        if !isempty(value(ctx.points))
            push!(ctx.points, push!(value(ctx.points), value(ctx.points)[1]))
        end
    end

    push!(ctx.points, [])

    append!(c.preserved, [sigstart, sigdrag, sigend])
    Dict("enabled"=>enabled)
end

function init_polygon_select(ctx::ImageContext)
    enabled = Signal(true)
    c = ctx.canvas

    dummybtn = MouseButton{UserUnit}()
    num_pts = Signal(0)

    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        if (ispolygon(value(ctx.points)) && !isinside(Point(btn.position),Point.(value(ctx.points)))) # resets ctx.points
            push!(ctx.points,[])
            push!(num_pts, 0)
        elseif isempty(value(ctx.points)) # adds first point
            push!(ctx.points, [btn.position])
            push!(num_pts,1)
        elseif !ispolygon(value(ctx.points)) # adds to polygon
            if (length(value(ctx.points)) > 3) && (value(ctx.points)[1].x - 5 <= btn.position.x <= value(ctx.points)[1].x + 5) && value(ctx.points)[1].y - 5 <= btn.position.y <= value(ctx.points)[1].y + 5 # finishes polygon if click near start
                push!(ctx.points,
                      push!(value(ctx.points)[1:end-1],value(ctx.points)[1]))
                push!(num_pts, length(value(ctx.points)))
            else # adds to polygon
                push!(ctx.points,push!(value(ctx.points)[1:end-1],btn.position))
                push!(num_pts, length(value(ctx.points)))
            end
        end
        nothing
    end

    sigmove = map(filterwhen(enabled,dummybtn, c.mouse.motion)) do btn
        # makes working point
        if !isempty(value(ctx.points)) && !ispolygon(value(ctx.points))
            push!(ctx.points, push!(value(ctx.points)[1:value(num_pts)], btn.position))
        end
        nothing
    end

    push!(ctx.points, [])

    append!(c.preserved, [sigstart, sigmove])
    Dict("enabled"=>enabled)
end

# add handle actions
# draw square around region near start
# draw handles
