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
