# Collection of functions and signals for measuring selections

using DataFrames

function avg_gray(selection)
  # returns avg gray value across array
  sum = 0
  for i in 1:length(selection)
    sum += Float64(selection[i])
  end
  sum = sum/length(selection)
  return ColorTypes.Gray{FixedPointNumbers.Normed{UInt8,8}}(sum).val
end

# Initializes a measurements table
function init_measure_tbl()
  return DataFrame(Area = @data([]),Mean = @data([]),Minimum = @data([]),Maximum = @data([]))
end

# Returns a row that can be pushed to a measurements table
function measure(selection) # also saves selection for labeling purposes?
  return @data([length(selection),avg_gray(selection),minimum(selection).val,maximum(selection).val])
end
#=
using TestImages, Gtk.ShortNames

img = testimage("pirate.tif")

rectview = Signal(view(img,1:20,1:40))

dataf = map(rectview) do r
    df = init_measure_tbl()
    push!(df, measure(img))
    push!(df, measure(r))
    df
end

txt = TextView()
push!(txt,string(value(dataf))) # should update when dataf updates...
# monospace font?

win2 = Window("Measure", 300, 200)
nb = Notebook()
push!(nb,txt,"Name")
push!(win2,nb)
showall(win2)
nothing
=#




# Other things:
# Option to write measurements to file (save measurements)


# ROI Manager:
# For every selection: context ID & selection number
# Numbered in order that they're made
# Number displays on image in selection as well as in manager table
