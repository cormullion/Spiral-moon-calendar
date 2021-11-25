using Colors, Luxor, Dates, JSON3, DataFrames, Downloads

#=
download moon data file from NASA, draw a spiral calendar
=#

function lefthemi(pt, r, col)             # draw a left hemisphere
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

function getdata()
    json_string = read("nasa-moon-2022-data.json", String)
    data = JSON3.read(json_string)
    df = DataFrame(data)
    df.isotime = map(dt -> DateTime(replace(dt, r" UT$" => ""), "d u y HH:MM"), df.time)
    return df
end

# draw a moon by superimposing three circles or ellipticals

function moon(pt::Point, r, age, positionangle)
    # use moon synodic period
    age = rescale(age, 0, 29.53059)
    # elliptical is scaled horizontally to render phases
    @layer begin
        translate(pt)
        rotate(deg2rad(positionangle/30)) # reduce apparent rotation for aesthetic
        setopacity(1)
        if 0 <= age < 0.25
            righthemi(pt, r, foregroundwhite)
            moonwidth = 1 - (age * 4) # goes from 1 down to 0 width (for half moon)
            setopacity(0.5)
            elliptical(O, r + 0.02, RGB(25 / 255, 25 / 255, 100 / 255), moonwidth + 0.02)
            setopacity(1.0)
            elliptical(O, r, backgroundblue, moonwidth)
            lefthemi(O, r, backgroundblue)
        elseif 0.25 <= age < 0.50
            lefthemi(O, r, backgroundblue)
            righthemi(O, r, foregroundwhite)
            moonwidth = (age - .25) * 4
            elliptical(O, r, foregroundwhite, moonwidth)
        elseif .50 <= age < .75
            lefthemi(O, r, foregroundwhite)
            righthemi(O, r, backgroundblue)
            moonwidth = 1 - ((age - 0.5) * 4)
            elliptical(O, r, foregroundwhite, moonwidth)
        elseif .75 <= age <= 1.00
            lefthemi(O, r, foregroundwhite)
            moonwidth = ((age - 0.75) * 4)
            setopacity(0.5)
            elliptical(O, r + 0.02, RGB(25 / 255, 25 / 255, 100 / 255), moonwidth + 0.02)
            setopacity(1.0)
            elliptical(O, r, backgroundblue, moonwidth)
            righthemi(O, r, backgroundblue)
        end
    end
end

function spiral_calendar(theyear, currentwidth, currentheight)
    currentyear = theyear
    x = y = 0.0
    centerX = centerY = 0
    radius = 50.0 # starting radius
    moonsize = 16 # pixels
    rotation = π
    away = 0
    # spiral stuff
    # How far to step away from center.
    awayStep = moonsize * 0.9
    chord = moonsize * 2.5 # distance between centers (should be more than twice the moon radius...)
    theta = chord / awayStep
    sethue(foregroundwhite)

    daterange = collect(Date(currentyear, 12, 31):-Dates.Day(1):Date(currentyear, 1, 1))
    df = getdata()

    for everyday in daterange
        d = (Dates.year(everyday), Dates.month(everyday), Dates.day(everyday))

        away = radius + (awayStep * theta)
        around = mod2pi(rotation - theta)
        x = centerX + (cos(around) * away)
        y = centerY + (sin(around) * away)

        thetime = DateTime(everyday) + Dates.Hour(12)
        age   = first(df[df[:, :isotime] .== thetime, :age])
        positionangle = first(df[df[:, :isotime] .== thetime, :posangle])

        # draw moon and dayname
        @layer begin
            translate(x, y)
            rotate(around + pi / 2) # rotate and then get text baseline

            moon(O, moonsize, age, positionangle)

            # dayname
            fontface("EurostileLT")
            sethue(foregroundwhite)
            fontsize(7)
            text(Dates.dayname(everyday), 0, - (moonsize + 6), halign=:center)
        end

        sethue(foregroundwhite)
        fontface("EurostileLT-Bold")

        # day number isn't rotated!
        @layer begin
            a = atan(y, x) - 0.01 # adjust for optical
            x1, y1 = (away - (moonsize * 1.85)) * cos(a), (away - (moonsize * 1.85)) * sin(a)
            translate(x1, y1)
            fontsize(11)
            text(string(d[3]), halign=:center) # day number
        end

        # month text needs special handling
        if d[3] == 1
            fontsize(20)
            m = string(titlecase(Dates.monthname(everyday)))
            te = textextents(m)
            r = away + (moonsize * 2.2)
            θ = atan(y, x)
            pt = polar(r, θ)

            # you could use this for circular text curve
            # textcurve(m, θ, r, O)

            # but this follows the spiral better

            for ch in m
                te = textextents(string(ch))
                twwidth = te[1] + te[3] + te[5]
                pt = polar(r, θ)
                θ += atan(twwidth, r)/2
                @layer begin
                    translate(pt)
                    rotate(π/2 + θ)
                    text(string(ch), O, halign=:left)
                end
                r -= 0.5
            end

        end
        theta += chord / away
    end

    # decoration
    setline(4)
    move(O)
    rect(-(currentwidth / 2) + 6, -(currentheight / 2) + 6, currentwidth - 12, currentheight - 12, :stroke)
    setline(1)
    rect(-(currentwidth / 2) + 12, -(currentheight / 2) + 12, currentwidth - 24, currentheight - 24, :stroke)

    @layer begin
        for i in 1:4
            @layer begin
                # large title
                translate(-(currentwidth / 2) + 40, -(currentwidth / 2) + 110)
                fontsize(81)
                fontface("EurostileLT-Bold")
                text(string(currentyear))

                fontsize(21)
                fontface("EurostileLT-Bold")
                text("moon phase calendar", 5, 22)

                # orbital logo
                setline(.3)
                shift = textextents("moon phase calendar")[5]
                translate(shift / 2, 60)

                # elliptical orbit
                @layer begin
                    Luxor.scale(1, 0.2)
                    circle(O, 45, :stroke)
                end

                # planet and moon
                @layer begin
                    setline(.7)
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
        fontsize(2)
        sethue(35 / 255, 35 / 255, 150 / 255)
        translate(0, -70 + (currentheight + 100) / 2)
        text("cormullion@mac.com", halign=:center)
    end
end

# start here

# download data from NASA
# data_url = "https://svs.gsfc.nasa.gov/vis/a000000/a004900/a004955/mooninfo_2022.json"
# Downloads.download(data_url, "nasa-moon-2022-data.json")

const theyear = 2022
const currentwidth = 1500
const currentheight = 1500

const backgroundblue = RGB(16 / 255, 16 / 255, 80 / 255)
const foregroundwhite = RGB(1, 1, 0.87)

Drawing(currentwidth + 100, currentheight + 100, "/tmp/$(theyear)-moon-phase-calendar.pdf")
origin()
background(backgroundblue)
spiral_calendar(theyear, currentwidth, currentheight)
finish()
preview()
