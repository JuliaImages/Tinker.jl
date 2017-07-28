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

    append!(c.preserved, [sigstart, sigdrag, sigend])
    Dict("enabled"=>enabled)
end

function init_polygon_select(ctx::ImageContext)
    enabled = Signal(true)
    c = ctx.canvas

    dummybtn = MouseButton{UserUnit}()
    push!(ctx.points, [])

    sigstart = map(filterwhen(enabled, dummybtn, c.mouse.buttonpress)) do btn
        if ispolygon(value(ctx.points)) && !isinside(Point(btn.position),Point.(value(ctx.points)))
            push!(ctx.points,[])
            Reactive.run_till_now()
        end
        if !ispolygon(value(ctx.points))
            next = btn.position
            if length(value(ctx.points)) > 3 # and click is near start
                next = value(ctx.points)[1]
            end
            push!(ctx.points, push!(value(ctx.points), next))
        end
    end

    sigmove = map(filterwhen(enabled,dummybtn, c.mouse.motion)) do btn
        
    end

    append!(c.preserved, [sigstart, sigmove])
    Dict("enabled"=>enabled)
end
