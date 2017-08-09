## Functions for handling zoom:
# Zooms zr to the decimal % entered; view centered around center XY
function zoom_percent(z::Float64, zr::ZoomRegion, center::XY{Int})
    # Calculate size of new view
    fsize = XY(zr.fullview.x.right,zr.fullview.y.right) # full size
    csize = XY(Int(round(fsize.x/z)), Int(round(fsize.y/z))) # new current size
    # Calculate center point of new view
    offset = XY(center.x-Int(round(csize.x/2)),
                center.y-Int(round(csize.y/2))) # offset of cv
    # Limit offset
    if offset.x < 0
        y = offset.y
        offset = XY(0, y)
    elseif offset.x > (fsize.x-csize.x)
        y = offset.y
        offset = XY(fsize.x-csize.x, y)
    end
    if offset.y < 0
        x = offset.x
        offset = XY(x, 0)
    elseif offset.y > (fsize.y-csize.y)
        x = offset.x
        offset = XY(x, fsize.y-csize.y)
    end

    return (offset.y+1..offset.y+csize.y, offset.x+1..offset.x+csize.x)
end # return value can be pushed to a zr

# Sets default center to be the middle of the cv
function zoom_percent(z::Float64, zr::ZoomRegion)
    # Calculate cv
    return zoom_percent(z,zr,find_center(zr))
end

# Finds rounded center point of the current view of given ZoomRegion
function find_center(zr::ZoomRegion)
    range = zr.currentview
    csize = XY(range.x.right-range.x.left,range.y.right-range.y.left)
    center = XY(range.x.left+Int(floor(csize.x/2)),
                range.y.left+Int(floor(csize.y/2)))
    return center
end

# Zoom tracking
const zpercents = [1.0,1.2,1.5,2.0,2.5,3.0,4.0,8.0]

# For a given zoom region, finds the level that zoom_percent actually zooms to,
# for every item in zpercents. Used in zoom tracking.
function actual_zpercents_x(zr::ZoomRegion)
    levels = zoom_percent.(zpercents, zr) #returns an array of tuples
    zp_actual = []
    for i in 1:length(levels)
        push!(zp_actual, IntervalSets.width(zr.fullview.x)/
              IntervalSets.width(levels[i][2]))
    end
    return zp_actual
end

# Returns index of next zoom level after current zoom level in zpercents.
function next_zoom(ctx::ImageContext)
    xzoom=IntervalSets.width(value(ctx.zr).fullview.x)/IntervalSets.width(value(ctx.zr).currentview.x)
    zp_actual = actual_zpercents_x(value(ctx.zr))
    index = 1
    for n in zp_actual
        if n > xzoom
            break
        end
        index += 1
    end
    return index
end

# Returns index of zoom level before current in zpercents.
function prev_zoom(ctx::ImageContext)
    zr = value(ctx.zr)
    xzoom=IntervalSets.width(zr.fullview.x)/IntervalSets.width(zr.currentview.x)
    zp_actual = actual_zpercents_x(value(ctx.zr))
    index = length(zpercents)
    for n in zp_actual[end:-1:1] # loop backwards
        if n < xzoom
            break
        end
        index -= 1
    end
    return index
end

# Performs proportional zoom in and tracks zoom level using zpercents.
function zoom_in(ctx::ImageContext, center::XY{Int})
    i = ctx.zl
    zr = ctx.zr
    if 1 <= i <= length(zpercents)
        if i < length(zpercents)
            i += 1
            push!(zr, zoom_percent(zpercents[i],value(zr),center))
        end
    else
        i = next_zoom(value(zr))
        push!(zr, zoom_percent(zpercents[i],value(zr),center))
    end
    ctx.zl = i
    ctx.zr = zr
end

# Automatically centered zoom_in
function zoom_in(ctx::ImageContext)
    zoom_in(ctx, find_center(value(ctx.zr)))
end

# Performs proportional zoom out and tracks zoom level using zpercents.
function zoom_out(ctx::ImageContext, center::XY{Int})
    i = ctx.zl
    zr = ctx.zr
    if 1 <= i <= length(zpercents)
        if i > 1
            i -= 1
            push!(zr, zoom_percent(zpercents[i],value(zr),center))
        end
    else
        i = prev_zoom(value(zr))
        push!(zr, zoom_percent(zpercents[i],value(zr),center))
    end
    ctx.zl = i
    ctx.zr = zr
end

# Automatically centered zoom_out
function zoom_out(ctx::ImageContext)
    zoom_out(ctx, find_center(value(ctx.zr)))
end

# Performs proportional, centered zoom to level entered
function zoom_to(ctx::ImageContext, z::Float64)
    ctx.zl = -1
    push!(ctx.zr, zoom_percent(z,value(ctx.zr)))
    nothing
end

# Mouse actions for zoom
function init_zoom_click(ctx::ImageContext)
    c = ctx.canvas
    zr = ctx.zr
    enabled = Signal(true)
    # Left click calls zoom_in() centered on pixel clicked
    # Right click calls zoom_out() centered on pixel clicked
    dragging = Signal(false)
    moved = Signal(false)
    start = Signal(XY{UserUnit}(-1,-1))
    start_view = Signal(ZoomRegion((1:1,1:1)))

    dummybtn = MouseButton{UserUnit}()
    sigclick = map(filterwhen(enabled,dummybtn,c.mouse.buttonpress)) do btn
        push!(dragging,true)
        push!(moved,false)
        push!(start,btn.position)
        push!(start_view,value(zr))
    end

    sigdrag = map(filterwhen(dragging, dummybtn, c.mouse.motion)) do btn
        value(start_view) != value(zr) && push!(moved,true)
        nothing
    end

    sigend = map(filterwhen(dragging,dummybtn,c.mouse.buttonrelease)) do btn
        if !value(moved)
            #println("modifiers=",btn.modifiers)
            if btn.button == 1 && btn.modifiers == 256 #if left click & no modifiers
                center = XY(Int(round(Float64(btn.position.x))),
                            Int(round(Float64(btn.position.y))))
                zoom_in(ctx, center)
            elseif btn.button == 3 || btn.modifiers == 260 # right click/ctrl
                center = XY(Int(round(Float64(btn.position.x))),
                            Int(round(Float64(btn.position.y))))
                zoom_out(ctx, center)
            end
        end
        push!(dragging,false) # no longer dragging
        push!(moved,false) # reset moved
    end
    append!(c.preserved, [moved, sigclick, sigdrag, sigend])
    Dict("enabled"=>enabled)
end
