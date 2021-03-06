using Colors, Luxor, Dates, JSON3, DataFrames

# read data from a dwonloaded copy https://svs.gsfc.nasa.gov/vis/a000000/a004800/a004874/mooninfo_2021.json
# saved as "nasa-moon-2021-data.json"

function lefthemi(pt, r, col)         # draw a left hemisphere
    gsave()
    sethue(col)
    newpath()
    arc(pt, r, pi / 2, -pi / 2, :fill)    # positive clockwise from x axis in radians
    grestore()
end

function righthemi(pt, r, col)
    gsave()
    sethue(col)
    newpath()
    arc(pt, r, -pi / 2, pi / 2, :fill)    # positive clockwise from x axis in radians
    grestore()
end

function elliptical(pt, r, col, horizscale)
    gsave()
    sethue(col)
    Luxor.scale(horizscale + 0.00000001, 1) # cairo doesn't like 0 scale :)
    circle(pt, r, :fill)
    grestore()
end

function getdata()
    json_string = read("nasa-moon-2021-data.json", String)
    data = JSON3.read(json_string)
    df = DataFrame(data)
    df.isotime = map(dt -> DateTime(replace(dt, r" UT$" => ""), "d u y HH:MM"), df.time)
    return df
end

function moon(pt::Point, r, age, positionangle,
        foregroundcolour = "darkblue",
        backgroundcolour = "gray")
    # draw a moon by superimposing three circles or ellipticals
    # phase is moon's age normalized to 0 - 1, 0 = new moon, 0.5 = 14 days/full, 1.0 = dead moon
    # elliptical is scaled horizontally to render phases
    gsave()
    translate(pt)
    setopacity(1)
    if 0 <= age < 0.25
        righthemi(pt, r, foregroundcolour)
        moonwidth = 1 - (age * 4) # goes from 1 down to 0 width (for half moon)
        setopacity(0.5)
        elliptical(O, r + 0.02, RGB(25 / 255, 25 / 255, 100 / 255), moonwidth + 0.02)
        setopacity(1.0)
        elliptical(O, r, backgroundcolour, moonwidth)
        lefthemi(O, r, backgroundcolour)
    elseif 0.25 <= age < 0.50
        lefthemi(O, r, backgroundcolour)
        righthemi(O, r, foregroundcolour)
        moonwidth = (age - .25) * 4
        elliptical(O, r, foregroundcolour, moonwidth)
    elseif .50 <= age < .75
        lefthemi(O, r, foregroundcolour)
        righthemi(O, r, backgroundcolour)
        moonwidth = 1 - ((age - 0.5) * 4)
        elliptical(O, r, foregroundcolour, moonwidth)
    elseif .75 <= age <= 1.00
        lefthemi(O, r, foregroundcolour)
        moonwidth = ((age - 0.75) * 4)
        setopacity(0.5)
        elliptical(O, r + 0.02, RGB(25 / 255, 25 / 255, 100 / 255), moonwidth + 0.02)
        setopacity(1.0)
        elliptical(O, r, backgroundcolour, moonwidth)
        righthemi(O, r, backgroundcolour)
    end
    grestore()
end

function spiral_calendar(theyear, currentwidth, currentheight)
    currentyear = theyear
    x = y = 0.0
    centerX = centerY = 0
    radius = 50.0 # starting radius
    moonsize = 16
    rotation = pi
    away = 0
    # How far to step away from center.
    awayStep = moonsize * 0.9
    chord = moonsize * 2.5 # distance between centers (should be more than twice the moon radius...)
    theta = chord / awayStep
    sethue("yellow")

    daterange = collect(Date(currentyear, 12, 31):-Dates.Day(1):Date(currentyear, 1, 1))
    df = getdata()

    for everyday in daterange
        d = (Dates.year(everyday), Dates.month(everyday), Dates.day(everyday))

        away = radius + (awayStep * theta)
        around = mod2pi(rotation - theta)
        x = centerX + (cos(around) * away)
        y = centerY + (sin(around) * away)


        thetime = DateTime(everyday) + Dates.Hour(12)
        age = first(df[df[:, :isotime] .== thetime, :age])

        # draw moon and dayname
        gsave()
        translate(x, y)
        rotate(around + pi / 2) # rotate and then get text baseline

        moon(O, moonsize, age / 29.530589, -pi / 2, "lightyellow", darkblue)

        fontface("EurostileLTStd")
        sethue("white")
        fontsize(7)
        # dayname
        textcentred(Dates.dayname(everyday), 0, - (moonsize + 6))
        grestore()

        # day number isn't rotated!
        gsave()
        a = atan(y, x) - 0.01 # adjust for optical
        x1, y1 = (away - (moonsize * 1.85)) * cos(a), (away - (moonsize * 1.85)) * sin(a)
        translate(x1, y1)
        fontface("EurostileLTStd-Bold")
        sethue("white")
        fontsize(11)
        textcentred(string(d[3])) # day number
        grestore()

        # month text needs special handling
        if d[3] == 1
            fontsize(20)
            fontface("ChunkFive")
            m = string(titlecase(Dates.monthname(everyday)))
            te = textextents(m)
            sethue("white")
            twwidth = te[3]
            r = away + (moonsize * 2.2)
            θ = atan(y, x)
            pt = polar(r, θ)
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
    move(0, 0)
    rect(-(currentwidth / 2) + 6, -(currentheight / 2) + 6, currentwidth - 12, currentheight - 12, :stroke)
    setline(1)
    rect(-(currentwidth / 2) + 12, -(currentheight / 2) + 12, currentwidth - 24, currentheight - 24, :stroke)

    gsave()
    for i in 1:4
        gsave()
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

        # orbit elliptical
        gsave()
        Luxor.scale(1, 0.2)
        circle(O, 45, :stroke)
        grestore()

        # planet and moon
        gsave()
        setline(.7)
        sethue(darkblue)
        circle(0, -3, 7, :stroke)
        grestore()
        circle(0, -3, 7, :fill) # planet
        circle(45, 0, 3, :fill) # moon
        grestore()
        rotate(pi / 2)
    end
    grestore()

    # and finally an email address
    setopacity(0.8)
    fontsize(4)
    sethue(35 / 255, 35 / 255, 150 / 255)
    translate(0, -70 + (currentheight + 100) / 2)
    textcentred("cormullion@mac.com")
end

# start here

theyear = 2021

currentwidth = 1500
currentheight = 1500


darkblue = RGB(20 / 255, 20 / 255, 80 / 255)
Drawing(currentwidth + 100, currentheight + 100, "/tmp/$(theyear)-moon-phase-calendar.pdf")
origin()
background(darkblue)
spiral_calendar(theyear, currentwidth, currentheight)
finish()
preview()
