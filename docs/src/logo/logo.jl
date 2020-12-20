using Luxor

function logo(s)
    full_radius = 99*s/100
    Δ = full_radius/180
    sethue(Luxor.julia_purple)
    sector(O+(-20Δ,0), 60Δ, 90Δ, -π/2, π/2, :fill)
    sethue(Luxor.julia_red)
    sector(O+(-20Δ,0), 0, 40Δ, -π/2, π/2, :fill)
    sethue(Luxor.julia_green)
    box(Point(-55Δ,0), 30Δ, 180Δ, :fill)
    sethue(Luxor.julia_blue)
    poly(Point.([(-40Δ,90Δ),(-40Δ,60Δ),(-20Δ,60Δ)]), :fill, close=true)
    poly(Point.([(-40Δ,-90Δ),(-40Δ,-60Δ),(-20Δ,-60Δ)]), :fill, close=true)
end

function drawlogo(s, fname)
    Drawing(s, s, fname)
    origin()
    logo(s)
    finish()
end

function drawbanner(w, h, fname)
    Drawing(w, h, fname)
    origin()
    table = Table([h], [h, w - h])
    @layer begin
        translate(table[1])
        logo(h)
    end
    @layer begin
        translate(table[2])
        sethue("black")
        fontface("Julius Sans One")
        fontsize(h/2.35)
        text("iffinDiffs.jl", O+(-h/9,0), halign=:center, valign=:middle)
        fontface("Montserrat")
        fontsize(h/10.5)
        text("A suite of Julia packages for difference-in-differences", O+(-h/10,h/2.5), halign=:center, valign=:middle)
    end
    finish()
end

drawlogo(120, "../assets/logo.svg")
drawbanner(350, 100, "../assets/banner.svg")
