using Tinker
using Gtk.ShortNames, GtkReactive, Graphics, Colors, Images, IntervalSets

# Opens a second window displaying the current value of rectview for the
# selection. Makes it easier to check if the view is correct.

ctx = value(Tinker.active_context)

win = Window("rectview", size(ctx.image,2), size(ctx.image,1));
c = canvas(UserUnit);
push!(win, c);

redraw = draw(c, ctx.rectview, ctx.zr) do cnvs, rv, zr
    #fill!(cnvs, colorant"white")
    set_coordinates(cnvs, zr)
    bg = fill(colorant"white", (size(ctx.image)))
    bview = view(bg,1:size(rv,1),1:size(rv,2))
    copy!(bview,rv)
    copy!(bg, bview)
    copy!(cnvs,bg) # make this not fill the whole canvas
end


showall(win);

nothing
