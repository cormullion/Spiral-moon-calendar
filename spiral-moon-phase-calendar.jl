VERSION >= v"0.4.0-dev+6641" && __precompile__()

using Colors

using Luxor, Astro # from http://github.com/cormullion

function lefthemi(x, y, r, col) # draw a left hemisphere
    gsave()
    sethue(col)
    newpath()
    arc(x, y, r, pi/2, -pi/2, :fill)    # positive clockwise from x axis in radians
    grestore()
end

function righthemi(x, y, r, col)
    gsave()
    sethue(col)
    newpath()
    arc(x, y, r, -pi/2, pi/2, :fill)    # positive clockwise from x axis in radians
    grestore()
end

function ellipse(x, y, r, col, horizscale)
    gsave()
    sethue(col)
    Luxor.scale(horizscale + 0.00000001, 1) # cairo doesn't like 0 scale :)
    circle(x, y, r, :fill)
    grestore()
end

function spiraltextcurve(str, x, y, xc, yc, r1, r2, offset=0.0)
    # text on a curve with linearly decreasing radius
    arclength = 0.0
    widths = Float64[]
    for i in 1:length(str)
        extents = textextents(str[i:i])
        x_advance = extents[5]
        push!(widths, x_advance)
    end
    gsave()
    rads = linspace(r1, r2, length(str))
    arclength = rads[1] * atan2(y - yc, x - xc) # starting on line passing through x/y but using radius
    arclength += offset
    for i in 1:length(str)
        gsave()
        theta = arclength/rads[i]  # angle for this character
        delta = widths[i]/rads[i] # amount of turn created by width of this char
        translate(rads[i] * cos(theta), rads[i] * sin(theta)) # move the origin to this point
        rotate(theta + pi/2 + delta/2) # rotate so text baseline perp to center
        text(str[i:i])
        arclength += widths[i] # move on by the width of this character
        grestore()
    end
    grestore()
end

function moon(x, y, r, age, positionangle, foregroundcolour="darkblue", backgroundcolour="gray")
    # draw a moon by superimposing three circles or ellipses
    # phase is moon's age normalized to 0 - 1, 0 = new moon, 0.5 = 14 days/full, 1.0 = dead moon
    # ellipse is scaled horizontally to render phases
    gsave()
    translate(x, y)
    setopacity(1)
    if 0 <= age < 0.25
        righthemi(0, 0, r, foregroundcolour)
        moonwidth = 1 - (age * 4) # goes from 1 down to 0 width (for half moon)
        setopacity(0.5)
        ellipse(0, 0, r+ 0.02, RGB(25/255, 25/255, 100/255), moonwidth+0.02)
        setopacity(1.0)
        ellipse(0, 0, r, backgroundcolour, moonwidth)
        lefthemi(0, 0, r, backgroundcolour)
    elseif 0.25 <= age < 0.50
        lefthemi(0, 0, r, backgroundcolour)
        righthemi(0, 0, r, foregroundcolour)
        moonwidth = (age - .25) * 4
        ellipse(0, 0, r, foregroundcolour, moonwidth)
    elseif .50 <= age < .75
        lefthemi(0, 0, r, foregroundcolour)
        righthemi(0, 0, r, backgroundcolour)
        moonwidth = 1 - ((age-0.5) * 4)
        ellipse(0,0, r, foregroundcolour, moonwidth)
    elseif .75 <= age <= 1.00
        lefthemi(0, 0, r, foregroundcolour)
        moonwidth = ((age - 0.75) * 4)
        setopacity(0.5)
        ellipse(0, 0, r+ 0.02, RGB(25/255, 25/255, 100/255), moonwidth+0.02)
        setopacity(1.0)
        ellipse(0,0, r, backgroundcolour, moonwidth)
        righthemi(0, 0, r, backgroundcolour)
    end
    grestore()
end

function rectangular_calendar(theyear)
   # for testing
    currentyear = theyear
    fontsize(6)
    x = -1400
    y = -1200

    daterange = collect(DateTime(Date(currentyear,1,1)):DateTime.Day(1):DateTime.Date(currentyear,12,31))

    for everyday in daterange
        d = (year(everyday), month(everyday), day(everyday))
        if d[3] == 1
            x = -1400
            y += 60
        end
        jd = apply(cal_to_jd, d)
        moonfrac,moonangle = moon_illuminated_fraction_high(jd) # moonfrac is 1 for full
        moonlat = moon_latitude(jd)
        (age,dist,lat,long) = moon_age_location(jd) # age is 15 for full
        println(d, " moonfrac ", moonfrac,  " moonangle ", moonangle, " age ", age, " moon lat ", moonlat)
        moon(x, y, 20, age/29.530589, moonangle, "lightyellow", "darkblue")
        sethue("white")
        text(string(day(everyday), " ", dayname(everyday)), x, y + 30)
        x += 60
    end
end

function spiral_calendar(theyear)
    global currentwidth, currentheight
    currentyear = theyear
    x = y = 0.0
    centerX = centerY = 0
    radius = 50.0 # starting radius
    moonsize = 16
    rotation = pi/2
    away = 0
    # How far to step away from center.
    awayStep = moonsize * 0.9
    chord = moonsize * 2.5 # distance between centers (should be more than twice the moon radius...)
    theta = chord/awayStep
    sethue("yellow")

    daterange = collect(Date(currentyear,12,31):-Dates.Day(1):Date(currentyear,1,1))

    for everyday in enumerate(daterange)
        d = (Dates.year(last(everyday)), Dates.month(last(everyday)), Dates.day(last(everyday)))
        away = radius + (awayStep * theta)

        # anticlockwise is minus
        around = mod2pi(rotation - theta)

        x = centerX + (cos(around) * away)
        y = centerY + (sin(around) * away)

        jd = cal_to_jd(d...)
        moonfrac,moonangle = moon_illuminated_fraction_high(jd) # moonfrac is 1 for full
        moonlat = moon_latitude(jd)
        (age,dist,lat,long) = moon_age_location(jd) # age is 15 for full

        # draw moon and dayname
        gsave()
        translate(x, y)
        rotate(around + pi/2) # rotate and then get text baseline
        moon(0, 0, moonsize, age/29.530589, -pi/2, "lightyellow", "midnightblue")
        fontface("EurostileLTStd")
        sethue("white")
        fontsize(7)
        textcentred(Dates.dayname(last(everyday)), 0, - (moonsize + 6)) # dayname
        grestore()

        # day number isn't rotated
        gsave()
        a = atan2(y,x) - 0.01 # adjust for lack of optical
        x1 , y1 = (away - (moonsize * 1.85)) * cos(a), (away - (moonsize * 1.85)) * sin(a)
        translate(x1,y1)
        fontface("EurostileLTStd-Bold")
        sethue("white")
        fontsize(11)
        textcentred(lowercase(string(d[3]))) # day number
        grestore()

        # month text needs special handling
        if d[3]==1
            fontsize(20)
            fontface("EurostileLTStd-Bold")
            m = string("| ", lowercase(Dates.monthname(last(everyday))))
            te = textextents(m)
            sethue("white")
            twwidth = te[5]
            # ought to work out the correct final radius, currently just guessing at 1.5 :(
            spiraltextcurve(m, x, y, 0, 0, away + (moonsize * 2.2), away + (moonsize * 2.2) - 1.5, -(twwidth/4))
        end
        theta += chord/away
    end

    # decoration
    setline(4)
    move(0,0)
    rect(-(currentwidth/2) + 6, -(currentheight/2) + 6, currentwidth - 12, currentheight - 12, :stroke)
    setline(1)
    rect(-(currentwidth/2) + 12, -(currentheight/2) + 12, currentwidth - 24, currentheight - 24, :stroke)

    gsave()
    for i in 1:4
        gsave()
        # large title
        translate(-(currentwidth/2) + 40, -(currentwidth/2) + 110)
        fontsize(81)
        fontface("EurostileLTStd-Bold")
        text(string(currentyear))

        fontsize(22)
        fontface("EurostileLTStd")
        text("moon phase calendar", 5, 22)

        # orbital logo
        setline(.3)
        shift = textextents("moon phase calendar")[5]
        translate(shift/2, 60)

        # orbit ellipse
        gsave()
        Luxor.scale(1, 0.2)
        circle(0, 0, 45, :stroke)
        grestore()
        # planet and moon
        gsave()
        setline(.7)
        sethue("midnightblue")
        circle(0, -3, 7, :stroke)
        grestore()
        circle(0, -3, 7, :fill) # planet
        circle(45, 0, 3, :fill) # moon
        grestore()
        rotate(pi/2)
    end
    grestore()
    # and finally an email address
    setopacity(0.8)
    fontsize(4)
    sethue(25/255, 25/255, 130/255)
    translate(0, -70 + (currentheight + 100)/2)
    textcentred("cormullion@mac.com")
end

# start here

global currentwidth = 1500  # = 56.45 cm
global currentheight = 1500 # = 56.45 cm
Drawing(currentwidth+100, currentheight+100, "/tmp/2015-moon.pdf")

origin()

background(RGB(25/255, 25/255, 100/255))

# rectangular_calendar(2015)
spiral_calendar(2015)
finish()
preview()
