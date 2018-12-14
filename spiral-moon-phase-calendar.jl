using Colors, Luxor, AstroLib, Dates

function moon_age_location(jd::Float64)
    # pinched from Astro.jl
    earth_equ_radius = 6378.137
    v  = (jd - 2451550.1) / 29.530588853
    ip = v - floor(Integer, v)
    ag = ip * 29.530588853   # Moon's age from new moon in days
    ip = ip * 2pi            # Converts to radian

    # Calculate distance from anomalistic phase
    v= (jd - 2451562.2) / 27.55454988
    dp = v- floor(Integer, v)
    dp = dp * 2pi
    di = 60.4 - 3.3 * cos(dp) - .6 * cos(2 * ip - dp) - .5 * cos(2 * ip)

    # Calculate ecliptic latitude from nodal (draconic) phase
    v = (jd - 2451565.2) / 27.212220817
    np = v - floor(Integer, v)
    np = np * 2pi
    la = 5.1 * sin(np)

    # Calculate ecliptic longitude from sidereal motion
    v = (jd - 2451555.8) / 27.321582241
    rp = v - floor(Integer, v)
    lo = 360 * rp + 6.3 * sin(dp) + 1.3 * sin(2 * ip - dp) + .7 * sin(2 * ip)

    return (ag, di * earth_equ_radius, deg2rad(la), deg2rad(lo))
end

function lefthemi(pt, r, col)         # draw a left hemisphere
    gsave()
    sethue(col)
    newpath()
    arc(pt, r, pi/2, -pi/2, :fill)    # positive clockwise from x axis in radians
    grestore()
end

function righthemi(pt, r, col)
    gsave()
    sethue(col)
    newpath()
    arc(pt, r, -pi/2, pi/2, :fill)    # positive clockwise from x axis in radians
    grestore()
end

function elliptical(pt, r, col, horizscale)
    gsave()
    sethue(col)
    Luxor.scale(horizscale + 0.00000001, 1) # cairo doesn't like 0 scale :)
    circle(pt, r, :fill)
    grestore()
end

function moon(pt::Point, r, age, positionangle,
        foregroundcolour="darkblue",
        backgroundcolour="gray")
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
        elliptical(O, r + 0.02, RGB(25/255, 25/255, 100/255), moonwidth + 0.02)
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
        moonwidth = 1 - ((age-0.5) * 4)
        elliptical(O, r, foregroundcolour, moonwidth)
    elseif .75 <= age <= 1.00
        lefthemi(O, r, foregroundcolour)
        moonwidth = ((age - 0.75) * 4)
        setopacity(0.5)
        elliptical(O, r + 0.02, RGB(25/255, 25/255, 100/255), moonwidth + 0.02)
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
    theta = chord/awayStep
    sethue("yellow")

    daterange = collect(Date(currentyear,12,31):-Dates.Day(1):Date(currentyear,1,1))

    for everyday in enumerate(daterange)
        d = (Dates.year(last(everyday)), Dates.month(last(everyday)), Dates.day(last(everyday)))
        jd = jdcnv(d...)

        away = radius + (awayStep * theta)

        # anticlockwise is minus
        around = mod2pi(rotation - theta)

        x = centerX + (cos(around) * away)
        y = centerY + (sin(around) * away)

        # moonfrac is 1 for full
        moonfrac = mphase(jd)

        # age is 15 for full, 29 for nearly new
        (age, dist, lat, long) = moon_age_location(jd)

        # draw moon and dayname
        gsave()
        translate(x, y)
        rotate(around + pi/2) # rotate and then get text baseline

        moon(O, moonsize, age/29.530589, -pi/2, "lightyellow", "midnightblue")

        fontface("EurostileLTStd")
        sethue("white")
        fontsize(7)
        # dayname
        textcentred(Dates.dayname(last(everyday)), 0, - (moonsize + 6))
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
        if d[3]==1
            fontsize(20)
            fontface("EurostileLTStd-Bold")
            m = string(titlecase(Dates.monthname(last(everyday))))
            te = textextents(m)
            sethue("white")
            twwidth = te[5]

            # ought to work out the correct final radius, currently just guessing at 1.5 :(

            textcurve(m, atan(y, x), away + (moonsize * 2.2), 0, 0,
                spiral_ring_step = -10,
                spiral_in_out_shift = -10,
                letter_spacing=2)

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

        # orbit elliptical
        gsave()
        Luxor.scale(1, 0.2)
        circle(O, 45, :stroke)
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
    sethue(35/255, 35/255, 150/255)
    translate(0, -70 + (currentheight + 100)/2)
    textcentred("cormullion@mac.com")
end

# start here

theyear = 2019

currentwidth = 1500
currentheight = 1500

Drawing(currentwidth + 100, currentheight + 100, "/tmp/$(theyear)-moon-phase-calendar.pdf")
origin()
background(RGB(25/255, 25/255, 100/255))
spiral_calendar(theyear, currentwidth, currentheight)
finish()
preview()
