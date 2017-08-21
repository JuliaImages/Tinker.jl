# All mouse actions in one function

# For point-based modification
function get_p1(index::Int, rh::Array)
    if isodd(index)
        index == 1 && return rh[5]
        index == 3 && return rh[7]
        index == 5 && return rh[1]
        index == 7 && return rh[3]
    else
        (index == 2 || index == 8) && return rh[5]
        (index == 4 || index == 6) && return rh[1]
    end
end

# For point-based modification
function get_p2(index::Int, rh::Array, p::XY)
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
    r =  Rectangle(p1,p2)
    x,y,w,h = r.x,r.y,r.w,r.h
    return [XY(x,y),XY(x+w,y),XY(x+w,y+h),XY(x,y+h),XY(x,y)]
end

# Returns array of all points that form rectangle, plus midpoints on sides
function two_point_rh(p1,p2)
    r =  Rectangle(p1,p2)
    x,y,w,h = r.x,r.y,r.w,r.h
    return [XY(x,y),XY(x+(w/2),y),XY(x+w,y),XY(x+w,y+(h/2)),XY(x+r.w,y+h),
    XY(x+(w/2),y+h),XY(x,y+h),XY(x,y+(h/2)),XY(x,y)]
end

# Returns true if two points are within given tolerance of each other
function near_point(p1::XY, p2::XY, t::Float64)
    (p2.x-t<=p1.x<=p2.x+t) && (p2.y-t<=p1.y<=p2.y+t) && return true
    return false
end

# Returns index of point in array that's near a given point
function near_vertex(pt::XY, p::Array, t::Float64)
    # returns index of nearby point
    for i in 1:length(p)
        near_point(pt,p[i],t) && return i
    end
    return -1
end

function init_selection_actions(c, points, shape, tol)
    # For conditionals:
    enabled = Signal(true)
    mode = Signal( freehand_mode)
    building = Signal(false)
    following = Signal(false)
    num_pts = Signal(0)
    moving = Signal(false)
    diff = Signal(XY(NaN,NaN))
    modifying = Signal(false)
    index = Signal(0)

    # For rectangle:
    corners = Signal((XY(-1.0,-1.0),XY(-1.0,-1.0)))
    rh = map(c->two_point_rh(c[1],c[2]),corners)

    dummybtn = MouseButton{UserUnit}()
    sigstart = map(filterwhen(enabled,dummybtn,c.mouse.buttonpress)) do btn
        # conditionals
        pts = value(points)
        isp = ispolygon(value(points))
        nearpt = near_vertex(btn.position,value(rh),tol)
        local isin
        try isin = isinside(Point(btn.position),Point.(pts)) catch isin = false end
        if (isp && typeof(value(shape)) == PolyHandle &&
            near_vertex(btn.position,pts,tol) != -1)
            # go to modifying poly by handle
            println("start: modifying poly")
            push!(modifying,true)
            push!(index,near_vertex(btn.position,pts,tol))
        elseif (isp && typeof(value(shape)) == RectHandle && nearpt != -1)
            # go to modifying rect by handle
            println("start: modifying rect")
            push!(modifying,true)
            push!(index,nearpt)
            push!(corners,(get_p1(nearpt,value(rh)),get_p2(nearpt,value(rh),btn.position)))
        elseif isp && isin
            # go to moving
            println("start: moving shape")
            push!(moving,true)
            push!(diff,XY{Float64}(btn.position)-XY{Float64}(pts[1]))
        else
            # Build new shape
            if value(mode) ==  rectangle_mode
                # start rect actions
                println("start: building rect")
                push!(building,true)
                push!(corners,(btn.position,btn.position))
                push!(points,two_point_rect(btn.position,btn.position))
                push!(shape, RectHandle())
            elseif value(mode) ==  freehand_mode
                # start freehand actions
                println("start: building freehand")
                push!(building,true)
                push!(points,Vector{XY{Float64}}[])
                push!(shape, Polygon())
            elseif value(mode) ==  polygon_mode
                # start polygon actions
                println("start: building polygon")
                if isempty(pts)
                    # add first point
                    println("first point")
                    push!(following,true)
                    push!(points, [btn.position])
                    push!(num_pts,1)
                    push!(shape,  PolyHandle())
                elseif !value(following)
                    # clears points
                    println("clearing")
                    push!(points, Vector{XY{Float64}}[])
                    push!(num_pts,0)
                elseif !isp
                    if (length(pts) > 3 && near_point(pts[1],btn.position,tol)) #pts[1].x-tol <= btn.position.x <=
                        #pts[1].x+tol && pts[1].y-tol <= btn.position.y <= pts[1].y+tol)
                        # finishes polygon if click near start
                        println("finishing")
                        pts[end] = pts[1]
                        push!(points,pts)
                        push!(num_pts, length(pts))
                        push!(following,false)
                    else
                        # adds to polygon
                        println("adding")
                        value(points)[end] = btn.position
                        push!(num_pts, length(pts))
                    end
                end
            else
                # ???
                println("Select actions are enabled in a non-select mode!")
            end
        end
        nothing
    end

    sigbuild = map(filterwhen(building,dummybtn,c.mouse.motion)) do btn
        if value(mode) ==  rectangle_mode
            # build rect actions
            #println("move: building rect")
            cnr = value(corners)
            push!(corners,(cnr[1],btn.position))
            push!(points,two_point_rect(cnr[1],btn.position))
        elseif value(mode) ==  freehand_mode
            # build freehand actions
            #println("move: building freehand")
            push!(points, push!(value(points),btn.position))
        end
        nothing
    end


    sigfollow = map(filterwhen(following,dummybtn,c.mouse.motion)) do btn
        # creates working point when building polygon
        if !isempty(value(points)) && !ispolygon(value(points))
            push!(points,push!(value(points)[1:value(num_pts)], btn.position))
        end
        nothing
    end

    sigmove = map(filterwhen(moving,dummybtn,c.mouse.motion)) do btn
        # move polygon
        push!(points,move_polygon_to(value(points),XY{Float64}(btn.position)-value(diff)))
        if typeof(value(shape)) ==  RectHandle
            push!(corners, (value(points)[1],value(points)[3]))
        end
    end

    sigmodify = map(filterwhen(modifying,dummybtn,c.mouse.motion)) do btn
        pts = value(points)
        if value(index) > 0 && typeof(value(shape)) ==  PolyHandle
            if value(index) != 1
                # move a middle point
                pts[value(index)] = btn.position
                push!(points, pts)
            else
                # move both first and last point
                pts[1] = btn.position
                pts[end] = btn.position
                push!(points,pts)
            end
        elseif value(index) > 0 && typeof(value(shape)) ==  RectHandle
            # modify rect by handles
            cnr = value(corners)
            push!(corners, (cnr[1],get_p2(value(index),value(rh),btn.position)))
            push!(points,two_point_rect(cnr[1],get_p2(value(index),value(rh),btn.position)))
        end
    end

    sigend = map(filterwhen(enabled,dummybtn,c.mouse.buttonrelease)) do btn
        if value(building) && value(mode) ==  freehand_mode
            # end freehand actions
            #println("end: ending freehand")
            length(value(points)) > 0 && push!(points,push!(value(points),value(points)[1]))
        elseif value(building) && value(mode) ==  polygon_mode
            # end polygon actions
            #println("end: ending poly")
        end
        # reset signals
        push!(building,false)
        push!(moving,false)
        push!(modifying,false)
        nothing
    end

    push!(points, Vector{XY{Float64}}[])

    signals = [sigstart,sigbuild,sigfollow,sigmove,sigmodify,sigend]

    append!(c.preserved, signals)

    dc = Dict("enabled"=>enabled,"mode"=>mode)
    return dc
end

function init_selection_actions(ctx)
    c = ctx.canvas
    points = ctx.points
    shape = ctx.shape
    tol = get_tolerance(ctx)
    init_selection_actions(c,points,shape,tol)
end
