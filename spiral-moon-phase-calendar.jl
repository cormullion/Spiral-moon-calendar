using Colors, Luxor, Dates, JSON, DataFrames, Downloads

#=
download moon data file from NASA, and draw a spiral calendar

# download data from NASA, uncomment as required

# for 2022 
# data_url = "https://svs.gsfc.nasa.gov/vis/a000000/a004900/a004955/mooninfo_2022.json"
#
# for 2023 
# data_url = "https://svs.gsfc.nasa.gov/vis/a000000/a005000/a005049/mooninfo_2023.json"
# https://svs.gsfc.nasa.gov/5048
# Downloads.download(data_url, "nasa-moon-2023-data.json")
#
# for 2024
# visit https://svs.gsfc.nasa.gov/5187/ 
=#

const theyear = 2024

data_url = "https://svs.gsfc.nasa.gov/vis/a000000/a005100/a005187/mooninfo_2024.json"

if !isfile(string(@__DIR__, "/nasa-moon-$(theyear)-data.json"))
    Downloads.download(data_url, "nasa-moon-2024-data.json")
end

function getdata()
    json_string = read(string(@__DIR__, "/nasa-moon-$(theyear)-data.json"), String)
    data = JSON.parse(json_string)
    df = DataFrame(data)
    df.isotime = map(dt -> DateTime(replace(dt, r" UT$" => ""), "d u y HH:MM"), df.time)
    return df
end

function lefthemi(pt, r, col) # draw a left hemisphere
    @layer begin
        sethue(col)
        newpath()
        arc(pt, r, pi / 2, -pi / 2, :fill)    # positive clockwise from x axis in radians
    end
end

function righthemi(pt, r, col)
    @layer begin
        sethue(col)
        newpath()
        arc(pt, r, -pi / 2, pi / 2, :fill)    # positive clockwise from x axis in radians
    end
end

function elliptical(pt, r, col, horizscale)
    @layer begin
        sethue(col)
        Luxor.scale(horizscale + 0.00000001, 1) # cairo doesn't like 0 scale :)
        circle(pt, r, :fill)
    end
end

function moon(pt::Point, r, age, positionangle)
    # use moon synodic period
    age = rescale(age, 0, 29.53059)
    # elliptical is scaled horizontally to render phases
    @layer begin
        translate(pt)
        rotate(-deg2rad(positionangle))
        setopacity(1)
        if 0 <= age < 0.25
            righthemi(O, r, foregroundwhite)
            moonwidth = 1 - (age * 4) # goes from 1 down to 0 width (for half moon)
            setopacity(0.5)
            elliptical(O, r + 0.02, RGB(25 / 255, 25 / 255, 100 / 255), moonwidth + 0.02)
            setopacity(1.0)
            elliptical(O, r, backgroundmoon, moonwidth)
            lefthemi(O, r, backgroundmoon)
        elseif 0.25 <= age < 0.50
            lefthemi(O, r, backgroundmoon)
            righthemi(O, r, foregroundwhite)
            moonwidth = (age - 0.25) * 4
            elliptical(O, r, foregroundwhite, moonwidth)
        elseif 0.50 <= age < 0.75
            lefthemi(O, r, foregroundwhite)
            righthemi(O, r, backgroundmoon)
            moonwidth = 1 - ((age - 0.5) * 4)
            elliptical(O, r, foregroundwhite, moonwidth)
        elseif 0.75 <= age <= 1.00
            lefthemi(O, r, foregroundwhite)
            moonwidth = ((age - 0.75) * 4)
            setopacity(0.5)
            elliptical(O, r + 0.02, RGB(25 / 255, 25 / 255, 100 / 255), moonwidth + 0.02)
            setopacity(1.0)
            elliptical(O, r, backgroundmoon, moonwidth)
            righthemi(O, r, backgroundmoon)
        end
    end
end

function pt_on_spiral(θ;
    center::Point=O,
    a=150,
    b=1) # 2πb is distance between 
    return Point(
        (a + (b * θ)) * (cos(θ)),
        (a + (b * θ)) * (sin(θ))
    )
end

function spiral_curve(θ₁, θ₂;
    a=150,
    b=0,
    stepby=π / 30)
    pts = Point[]
    for θδ in range(θ₁, θ₂, step=stepby)
        push!(pts, pt_on_spiral(θδ, a=a, b=b))
    end
    return pts
end

function draw_one_day(theyear, theday, start_angle, end_angle, R, b, age, positionangle)
    # generate a spiral curve
    sethue(foregroundwhite)
    fontface("EurostileLT-Bold")
    d = (Dates.year(theday), Dates.month(theday), Dates.day(theday))
    # draw month 
    @layer begin
        if d[3] == 1
            setline(1)
            # draw a thin line to separate the rows
            overline_curve = spiral_curve(start_angle - π / 60, end_angle + π, a=R + 50, b=-b, stepby=π / 120)
            @layer begin
                for i in 1:length(overline_curve)-1
                    setopacity(rescale(i, 1, length(overline_curve), 1, 0))
                    line(overline_curve[i], overline_curve[i+1], :stroke)
                end
            end
            # month spiral is above primary spiral
            m = uppercase(Dates.monthname(theday))
            @layer begin
                # draw the month text on the curve
                baselinecurve = spiral_curve(start_angle - π / 60, end_angle + π / 60, a=R + 33, b=-b, stepby=π / 200)
                fontsize(16)
                sethue(foregroundwhite)
                textonpoly(m, baselinecurve, closed=false)
            end
        end
    end

    @layer begin
        # draw moon
        moonsize = 18 # pixels
        currentyear = theyear
        primarycurve = spiral_curve(start_angle, end_angle + 0.5, a=R, b=-b)

        @layer begin
            sl = slope(O, first(primarycurve))
            translate(first(primarycurve))
            rotate(3π/2 + sl)
            moon(O, moonsize, age, positionangle)
        end
        # draw dayname and daynumber
        @layer begin
            #fontface("EurostileLT")
            fontface("EurostileLT-Bold")
            sethue(foregroundwhite)
            fontsize(12)
            #str = string(Dates.dayname(theday), " ", d[3])
            str = string(d[3])
            baselinecurve = spiral_curve(start_angle - π / 60, end_angle + π / 30, a=R + 20, b=-b, stepby=π / 200)
            textonpoly(str, baselinecurve, closed=false)
        end
    end

    # return point for updating spiral
    return first(primarycurve)
end

function draw_all(currentyear, currentwidth, currentheight)
    daterange = collect(Date(currentyear, 1, 1):(Dates.Day(1)):Date(currentyear, 12, 31))
    df = getdata()
    radius = currentwidth / 2 - 10
    sep = 90 # gap between days
    b = 13 # determines the spacing of the spiral
    rspiral = radius # initial radius
    start_angle = 3π / 2 # start at the top
    n = 1
    # go through every day and draw moon, updating spiral 
    while n <= length(daterange)
        thedate = daterange[n]
        thetime = DateTime(thedate) + Dates.Hour(12)
        age = first(df[df[:, :isotime].==thetime, :age])
        positionangle = first(df[df[:, :isotime].==thetime, :posangle]) # degrees :) 
        θ = sep / rspiral
        end_angle = start_angle + θ
        pt = draw_one_day(currentyear, thedate, start_angle, end_angle, radius, b, age, positionangle)
        start_angle = end_angle
        n += 1
        rspiral = distance(O, pt)
    end
end

function main(fname)
    Drawing(currentwidth + 100, currentheight + 100, fname)
    origin()
    background(backgroundblue)
    draw_all(theyear, currentwidth, currentheight)
    # decoration
    setline(4)
    box(O, 30 + currentwidth, 30 + currentwidth, :stroke)
    setline(1)
    box(O, 10 + currentwidth, 10 + currentwidth, :stroke)

    @layer begin
        for i in 1:4
            @layer begin
                # large title
                translate(-(currentwidth / 2) + 40, -(currentwidth / 2) + 110)
                fontsize(81)
                fontface("EurostileLT-Bold")
                text(string(theyear))

                fontsize(21)
                fontface("EurostileLT-Bold")
                text("moon phase calendar", 5, 22)

                # orbital logo
                setline(0.3)
                shift = textextents("moon phase calendar")[5]
                translate(shift / 2, 60)

                # elliptical orbit
                @layer begin
                    Luxor.scale(1, 0.2)
                    circle(O, 45, :stroke)
                end

                # planet and moon
                @layer begin
                    setline(0.7)
                    circle(45, 0, 3, :fill) # moon
                    sethue(backgroundblue)
                    circle(0, -3, 7, :stroke)
                    sethue(foregroundwhite)
                    circle(0, -3, 7, :fill) # planet
                end
            end
            rotate(pi / 2)
        end # layer
        
        # and finally an email address
        setopacity(0.8)
        fontsize(4)
        sethue(35 / 255, 35 / 255, 150 / 255)
        translate(0, -70 + (currentheight + 100) / 2)
        text("cormullion@mac.com", halign = :center)
    end
    finish()
    preview()
end



const currentwidth = 2000
const currentheight = 2000

const backgroundblue = RGB(16 / 255, 16 / 255, 80 / 255)
const backgroundmoon = RGB(16 / 255, 16 / 255, 50 / 255)
const foregroundwhite = RGB(1, 1, 0.87)

main("/tmp/$(theyear)-spiral-moon-phase-calendar.pdf")