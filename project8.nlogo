airports-own [destination-turtles destinations airport-name capacity landed_num available_slots destroyed? isairport? ]
planes-own [ start_fuel moved? my-heat-map target landed? last_dest dest dest_icao fuel dest_destroyed? cruise altitude target-altitude sep-incidents have-got-gradients speed]
links-own [ frequency distance-between-airports weighted-distance pop]
globals [ percentage_efficiency mouse-was-down? crashed_planes extra_fuel redirects_num scaling total-patch-sep total-plane-sep list_of_airports]
extensions [ csv stats ]
patches-own[wall mygradient obstacle sep-incs]
breed [planes plane]
breed [airports airport]

;;
;; Setups the map and the airplanes
;;
to setup
  clear-all
  create_map
  airport_routes
  place_planes
  reset-ticks
  set crashed_planes 0
  set redirects_num 0
  set extra_fuel 0
  set percentage_efficiency []
end

to reset
  reset_map
  clear-turtles
  clear-all-plots
  create_map
  airport_routes
  place_planes
  reset-ticks
  set crashed_planes 0
  set redirects_num 0
  set extra_fuel 0
  set total-plane-sep 0
end

;;
;; Go
;;
to go
  mouse-manager
  move_planes
  find_destinations
  altitude-change
  seperation
  tick
end

to weather
  mouse-manager
end

;;
;; Creates airports on the map
;;
to create_map
  let _airport_count 0
  let data csv:from-file "airports.csv"

  print scaling


  let id "temp"
  let ident "temp"
  let types "temp"
  let name "temp"
  let lat "temp"
  let long "temp"

    ;; While not all airports placed
  foreach data [ a -> let counter 0 foreach a [ [b] ->

      if counter = 0 [set id b]
      if counter = 1 [set ident b]
      if counter = 2 [set types b]
      if counter = 3 [set name b]
      if counter = 4 [set lat b * 1]
      if counter = 5 [set long b * 1]
      set counter counter + 1
    ] ;print (ident)

    carefully[
    ask patch long lat [
        sprout-airports 1
        [
        setxy precision long 3 precision lat 3
        set size .4
        set isairport? true
        set color yellow
        set destroyed? false
        set shape "circle"
        set airport-name name
        set label (word ident)

        ]
      set _airport_count (_airport_count + 1)
      ]
  ] []]
end

to airport_routes

  let index_airports csv:from-file "routeindex.csv"
  let airport_dests csv:from-file "routes.csv"
  foreach index_airports [ a ->
    ask airports [if position label a != false [
    let index position label a
    set destinations item index airport_dests

    ]]
  ]
  let singular_airports_list []
  ask airports [set singular_airports_list lput label singular_airports_list]
  show singular_airports_list

  ask airports [let newlist [] carefully [foreach destinations [a -> if a != "" and member? a singular_airports_list [set newlist lput a newlist] ]] [] set destinations newlist]
  ask airports [let newlist [] carefully [foreach destinations [b -> set newlist lput airports with [label =  b ] newlist ] ][] set destination-turtles newlist]
  ask airports [if length destinations = 0 [die]]
end



to reset_map
  ask airports [
    set color yellow
    set destroyed? false
  ]
end

;;
;; Destroys the clicked airport
;;
to airport_destroyed
  ask airports with [round xcor = round mouse-xcor and round ycor = round mouse-ycor] [
    ifelse color = yellow
    [
      set color red
      set destroyed? true
    ]
    [
      if color = red[
      set color yellow
      set destroyed? false
      set available_slots (capacity - landed_num)
      ]
    ]
  ]

  if patchcontrol = true [ask patch mouse-xcor mouse-ycor [ ask patches in-radius 3 [set pcolor red set obstacle 1 set mygradient 9999 ] ask airports-on patches in-radius 3 [
      set color red
      set destroyed? true
    ]
  ]]

  ask planes [
    ;; if i've put on a storm on them they die
    let instorm False
    ask patch-here [if pcolor = red [set instorm True]]
    if instorm = True [die]
    if dest != nobody and dest != 0 [  ;one day this just broke but putting dest != 0 fixed it
      get-gradient-no-heat]]
end

to experimental_destroyed ; for running from behaviour space as experiments
  let experix random 30
  let experiy (random 25) + 35

  ask airports with [round xcor = experix and round ycor = experiy] [
    ifelse color = yellow
    [
      set color red
      set destroyed? true
    ]
    [
      if color = red[
      set color yellow
      set destroyed? false
      set available_slots (capacity - landed_num)
      ]
    ]
  ]

  if patchcontrol = true [ask patch experix experiy [ ask patches in-radius 6 [set pcolor red set obstacle 1 set mygradient 9999 ] ask airports-on patches in-radius 6 [
      set color red
      set destroyed? true
    ]
  ]]

  ask planes [
    ;; if i've put on a storm on them they die
    let instorm False
    ask patch-here [if pcolor = red [set instorm True]]
    if instorm = True [die]
    if dest != nobody and dest != 0 [  ;one day this just broke but putting dest != 0 fixed it
      get-gradient-no-heat]]
end

;;
;; Mouse click event
;;
to-report mouse-clicked?
  report (mouse-was-down? = true and not mouse-down?)
end

;;
;; Handles mouse clicks
;;
to mouse-manager
  let mouse-is-down? mouse-down?

  if mouse-clicked? [
    airport_destroyed
  ]
  set mouse-was-down? mouse-is-down?
end

;;
;; Assigns planes to the airports
;;
to place_planes

  if randomplacement = true [

  let _assigned_planes airplane_num
  let _plane_batch (round ( airplane_num / (count airports)) + 1)
  let _planes 0


  ask airports [
    let tempx xcor
    let tempy ycor
    ifelse _assigned_planes < _plane_batch [set _planes _assigned_planes] [set _planes _plane_batch]
    ask patch-here [sprout-planes _planes [set shape "airplane" set xcor tempx set ycor tempy set cruise 0 set speed random-normal airplane_speed 0.05]]
    set landed_num _planes
    set capacity (_planes + 2)
    set _assigned_planes (_assigned_planes - _planes)
    set available_slots (capacity - landed_num)
  ]]

  if randomplacement = false [

  set list_of_airports []
  let temp 0
    ask airports [if destination-turtles != 0 [foreach destination-turtles [ x -> if any? x [set list_of_airports lput x list_of_airports]]]]
  let _planes 0
  let airporttospawn 0

  repeat airplane_num [
    set airporttospawn one-of list_of_airports
    ask airporttospawn [
    let tempx xcor
    let tempy ycor
      ask patch-here [sprout-planes 1 [set shape "airplane" set xcor tempx set ycor tempy set cruise 0 set speed random-normal 0.3 0.05]]
    set landed_num _planes
    set capacity (_planes + 2)
    set available_slots (capacity - landed_num)
      ]

    ]

  ]

  ask planes [
    ;;set last_dest (one-of airports-at 0 0)
    set landed? true
    set dest_destroyed? false
    set size 1
]
end

;;
;; Finds destinations for each airplane
;;

to find_destinations
  ask planes with [landed?]
  [
    set have-got-gradients false
    let random_override false
    let _destination "None"
    let _curr_airport min-one-of airports-here [distance myself]  ;;closest airport on patch
    let templinker dest
    if links? [
      ;;check if link already exists, if so add pop
    carefully[
      ask last_dest [ask link-with templinker [set pop pop + 1]]
      ][]
      ;;create link
    carefully[
        let temp-distance 0
        let temp-weighting ((start_fuel - fuel) / start_fuel)
        ifelse directional? = true [
          ask last_dest [set temp-distance distance templinker create-link-to templinker [set pop pop + 1 set distance-between-airports temp-distance set weighted-distance (temp-distance * temp-weighting)]]]
        [ ask last_dest [set temp-distance distance templinker create-link-with templinker [set pop pop + 1 set distance-between-airports temp-distance set weighted-distance (temp-distance * temp-weighting)]]  ]
      ][]
    ]
    set last_dest dest



    if randomrouting = false [                    ;; non-random routing
    let _possible_destination "none"
    ask _curr_airport [ifelse length destination-turtles = 0 [set random_override true][set _possible_destination item random (length destination-turtles) destination-turtles set _destination one-of _possible_destination]]
    if _destination = nobody or _destination = 0 [set random_override true ]  ;;this is because sometimes there is no agent in _possible_destinations
    ]


    if (randomrouting = true) or (random_override = true ) or (_destination = "None") [   ;; random routing
    ;; Get random airport
    let _possible_destinations (airports with [ destroyed? = false and self != _curr_airport])
    if not any? _possible_destinations [stop]
    set _destination (one-of _possible_destinations)
    ]


    let open true
    ask _destination [if destroyed? = true [set open false]]


    ;; Check if airport is open
    if open = true [
       ;; Set destination
      set dest _destination
      ;;get-gradient-no-heat ;; planes now only calculate this if they can't go in straight line
      set landed? false
      face dest
      set fuel ((distance dest) + fuel_redundancy)
      set start_fuel fuel ;;for efficiency purposes

      ;;Cruise altitude selection
      let temprandom random 1001
      if heading > 179 [ifelse temprandom < 33 [set cruise 30000] [ifelse temprandom < 565 [set cruise 32000] [ifelse temprandom < 801 [set cruise 34000] [ifelse temprandom < 934 [set cruise 36000] [ifelse temprandom < 1001 [set cruise 38000][]]]]]]
      if heading < 180 [ifelse temprandom < 63 [set cruise 29000] [ifelse temprandom < 341 [set cruise 31000] [ifelse temprandom < 806 [set cruise 33000] [ifelse temprandom < 917 [set cruise 35000] [ifelse temprandom < 1001 [set cruise 37000][]]]]]]

      set target-altitude cruise
      set altitude 0
      ;; Reserve spot in airport
      ask _destination [ set available_slots (available_slots - 1)

      ]

      ask _curr_airport [
        set available_slots (available_slots + 1)
        set landed_num (landed_num - 1)
      ]
      set_dest_icao]]
end

to set_dest_icao
  let dest_icao_temp "None"   ;; cheeky code to get the destination ICAO from the airport an pass it to the plane
  carefully[
  ask dest [set dest_icao_temp label]
      set dest_icao dest_icao_temp][]
end

to negotiate_dest
  let _dest_list []
  let _possible_destinations (airports with [destroyed? = false])
  let _current_dist 0
  let _airport nobody
  let _min_dist 10000
  ask _possible_destinations [set _dest_list lput self _dest_list]

  foreach _dest_list [ ?1 ->
    set _current_dist (distance ?1)
    if _current_dist < _min_dist [
      set _min_dist _current_dist
      set _airport ?1
    ]
  ]

  set dest _airport
  set dest_destroyed? false
  set redirects_num (redirects_num + 1)

  ask one-of planes with [dest = _airport][
    set dest_destroyed? true
  ]
  face dest
  get-gradient-no-heat
  negotiate_dest
end
;;
;; Finds a destination for a plane on the fly
;;
to on_the_fly_dest
  ask self [
    ;; Get random airport
    let _possible_destinations (airports with [ destroyed? = false and available_slots > 0 ])
    if not any? _possible_destinations  [
      if not tactical [stop]
      negotiate_dest
      stop
    ]

    let _current_dist 0
    let _airport nobody
    let _min_dist 10000
    let _dest_list []
    ask _possible_destinations [set _dest_list lput self _dest_list]

    foreach _dest_list [ ?1 ->
      set _current_dist (distance ?1)
      if _current_dist < _min_dist [
        set _min_dist _current_dist
        set _airport ?1
      ]
    ]
    set dest _airport
    set dest_destroyed? false
    set redirects_num (redirects_num + 1)
    ask dest [
      set available_slots (available_slots - 1)
    ]
    face dest
    get-gradient-no-heat
  ]

end

;;
;; Moves planes towards their destination
;;
to move_planes
  ask planes with [not landed?][
    set moved? false
    ;; check if dest is destroyed
    set dest_destroyed? ([destroyed?] of dest)
    if dest_destroyed? [
      on_the_fly_dest
    ]

    find-lowest-gradient-in-vision   move-forward]
end

to find-lowest-gradient-in-vision  ;;find the patch with lowest gradient in vision

face dest
if check-obstacle distance dest = false [set target dest move-forward stop]
;;  if check-obstacle 20 = false [set target dest move-forward stop]
if have-got-gradients = false [get-gradient-no-heat set have-got-gradients true]
update-gradients  ;;gradient map is different for each agent. agents use this function to ask patches update gradients in its turn to move
let patches-in-vision patches in-radius 25  ;;all patches in a circle with radius = vision, including those behind obstacles
set patches-in-vision  sort-by [ [?1 ?2] -> [mygradient] of ?1 < [mygradient] of ?2 ] patches-in-vision ;;sort them according gradient
;;find the first patch in the list that is not blocked
let i 0
repeat 9999999[
face item i patches-in-vision
ifelse check-obstacle 25 = false [set target item i patches-in-vision move-forward stop][set i i + 1]] ;;move towards a visible target with lowest gradient

end

to-report check-obstacle [view_distance1] ;;check if there is any obstacle ahead. return 0 if not. return the obstacle number if there is any.

  let i 1
  let obs-ahead 0

  while [i <= view_distance1 and obs-ahead = 0][
     if patch-left-and-ahead 0 i != nobody[
     ask patch-left-and-ahead 0 i [
       if obstacle > 0 [set obs-ahead obstacle]
       ]]
     set i i + 1]

  ifelse obs-ahead = 0 [report false][report true]  ;;to return true or false instead
end

to update-gradients  ;;gradient map is different for each agent. agents use this function to ask patches update gradients in its turn to move

  let i 0
  let x -30
  let y 0
  repeat 121[
      repeat 90[
         ask patch x y [set mygradient item i [my-heat-map] of myself]
         set y y + 1
         set i i + 1]
      set x x + 1  set y 0
  ]

  ask patches with [obstacle > 0 or wall = 1 or pycor = 1] [set mygradient 9999 ]  ;;walls and obstacles have gradient = 9999, so no one moves into them
end


to get-gradient-no-heat  ;;calculate gradients map purely based on distance
  ask patches with [wall != 1] [
    set mygradient distance [dest] of myself
    ]

  set my-heat-map []

  let x -30
  let y 0

  repeat 121[
      repeat 90[
         set my-heat-map lput [mygradient] of patch x y my-heat-map
         set y y + 1]
      set x x + 1  set y 0
  ]
end

to move-forward
    ;;ran for all planes in the air moving, called from the gradient
    ;;dest and target are the same agent in some of these cases and used interchangeably
    face target
    set moved? true
    let tempdistdest distance dest       ;;this is just so I don't have to recalculate this value every time
    if tempdistdest < speed [
    face dest
    forward distance dest
    set fuel (fuel - tempdistdest)  ; i use fuel
    if fuel < fuel_redundancy [
      set extra_fuel (extra_fuel + distance dest)
  ]]
    if distance dest > speed[
    forward speed
    set fuel (fuel - speed)  ;  use fuel
    if fuel < fuel_redundancy [
      set extra_fuel (extra_fuel + speed)
  ]]

    if fuel <= 0 [
      set crashed_planes (crashed_planes + 1)
    ]

    ;; For those that arrived
    if not dest_destroyed? [
      if distance dest < 0.00001 [  ;old solution here checked if they were on top, but this adds some leeway - airplanes get stuck otherwise
      let destx 0
      let desty 0
      ask dest [set destx xcor set desty ycor]   ; gotta put the planes on the airports exactly otherwise funky stuff happens and they don't get a new dest
      setxy destx desty
      set landed? true
      if start_fuel > 0 [set percentage_efficiency lput ((start_fuel - fuel) / start_fuel) percentage_efficiency]
      set fuel 0
      ask dest [
      set landed_num (landed_num + 1)

        ]
      ]
    ]

end

to altitude-change
  ask planes [
    if dest != nobody and dest != 0  [
      set target-altitude ((distance dest / speed ) * 1000)]
    if target-altitude > cruise [set target-altitude cruise]

    if target-altitude > altitude [set altitude (altitude + 1000)]
    if target-altitude < altitude [set altitude target-altitude]


  ]
end

to seperation

  if vertsep = true [
  let compare-alt 0
    ask planes [set compare-alt altitude ask other planes in-radius sep-radius [if (altitude - compare-alt) < vertical-sep and (altitude - compare-alt) > (vertical-sep * -1) [set sep-incidents sep-incidents + 1 set total-plane-sep total-plane-sep + 1 ask patch-here [set sep-incs sep-incs + 1 set pcolor pcolor + 0.01 ]]] ]
  ]
  if vertsep = false [
  ask planes [ask other planes in-radius sep-radius [set sep-incidents sep-incidents + 1 set total-plane-sep total-plane-sep + 1 ask patch-here [set sep-incs sep-incs + 1 set pcolor pcolor + 0.01 ]] ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
826
10
2044
929
-1
-1
10.0
1
0
1
1
1
0
0
0
1
-30
90
0
90
1
1
1
ticks
30.0

BUTTON
10
17
83
50
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
168
19
231
52
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
11
68
183
101
airport_num
airport_num
2
100
59.0
1
1
NIL
HORIZONTAL

BUTTON
244
19
334
52
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
12
110
184
143
airplane_num
airplane_num
1
5000
1689.0
1
1
NIL
HORIZONTAL

SLIDER
12
157
241
190
fuel_redundancy
fuel_redundancy
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
9
207
300
240
airplane_speed
airplane_speed
0.0001
1
0.203
0.0001
1
NIL
HORIZONTAL

PLOT
13
260
392
544
Planes
Time
Planes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count planes"

BUTTON
89
18
159
51
reset
reset
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
398
261
754
547
Extra fuel consumed
Time
Fuel Units
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot extra_fuel"

PLOT
620
80
820
230
Redirects
Time
Number of redirects
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot redirects_num"

SWITCH
205
69
375
102
tactical
tactical
1
1
-1000

SWITCH
206
110
331
143
patchcontrol
patchcontrol
0
1
-1000

SWITCH
256
157
392
190
randomrouting
randomrouting
0
1
-1000

SWITCH
310
207
413
240
links?
links?
0
1
-1000

BUTTON
345
21
423
54
NIL
weather
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
14
555
392
761
Whole Mean of X efficiencies
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"efficiency" 1.0 0 -16777216 true "" "\nif length percentage_efficiency > 10 [\nplot mean percentage_efficiency]"

PLOT
399
554
753
761
Last 50 mean of x efficiencies
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "let smaller sublist percentage_efficiency (length percentage_efficiency - 100) length percentage_efficiency\n\nplot mean smaller"

MONITOR
15
765
185
810
NIL
mean percentage_efficiency
17
1
11

MONITOR
201
766
779
811
Last 50 mean
mean sublist percentage_efficiency (length percentage_efficiency - 100) length percentage_efficiency
17
1
11

PLOT
19
836
219
986
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot total-plane-sep"

SLIDER
446
21
618
54
sep-radius
sep-radius
0
5
0.13
0.01
1
NIL
HORIZONTAL

SWITCH
631
22
785
55
randomplacement
randomplacement
0
1
-1000

SWITCH
362
114
465
147
vertsep
vertsep
0
1
-1000

SLIDER
410
69
582
102
vertical-sep
vertical-sep
0
3000
3000.0
500
1
NIL
HORIZONTAL

PLOT
252
820
807
1196
Degree Distribution
NIL
NIL
1.0
200.0
0.0
100.0
true
false
"" ""
PENS
"Degree Distribution of Network" 1.0 1 -16777216 true "" "histogram [count my-links] of airports"
"Poisson Distribution" 1.0 0 -2674135 true "" "let a count links / count airports * 2\nplot-pen-reset \n\n\nlet x 1\nrepeat 1000\n[set x x + 0.2\nplotxy x ((stats:incompleteGammaComplement (x + 1) a) - stats:incompleteGammaComplement x a) * (count airports)\n]\nif x > 200 [stop]"

SWITCH
426
209
544
242
directional?
directional?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment23" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>total-plane-sep</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1623"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="airplane_num" first="0" step="1000" last="20000"/>
    <enumeratedValueSet variable="randomrouting">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="RANDOM" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>total-plane-sep</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1623"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="airplane_num" first="0" step="100" last="5000"/>
    <enumeratedValueSet variable="randomrouting">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment tipping" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>total-plane-sep</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1623"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="airplane_num" first="0" step="10" last="2000"/>
    <enumeratedValueSet variable="randomrouting">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment weather2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup
experimental_destroyed</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>total-plane-sep</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1623"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="airplane_num" first="0" step="100" last="1000"/>
    <enumeratedValueSet variable="randomrouting">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomplacement">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertsep">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentRandom" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>[count my-links] of airports</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomplacement">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sep-radius">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="73"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertsep">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="directional?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_num">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertical-sep">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomrouting">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentNonRandomtest2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>[count my-links] of airports</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomplacement">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sep-radius">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="73"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertsep">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="directional?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_num">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertical-sep">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomrouting">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentNonRandomzerocasetest2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>[count my-links] of airports</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomplacement">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sep-radius">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="73"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertsep">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="directional?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_num">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertical-sep">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomrouting">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentforcomplexitscaling2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>total-plane-sep</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomplacement">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sep-radius">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="73"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertsep">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="directional?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="airplane_num" first="0" step="1000" last="20000"/>
    <enumeratedValueSet variable="vertical-sep">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomrouting">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentforcomplexitscaling4" repetitions="1" runMetricsEveryStep="true">
    <setup>setup
experimental_destroyed</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>total-plane-sep</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomplacement">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sep-radius">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="73"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertsep">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="directional?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="airplane_num" first="0" step="100" last="1000"/>
    <enumeratedValueSet variable="vertical-sep">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomrouting">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentforcomplexitscaling5" repetitions="1" runMetricsEveryStep="true">
    <setup>setup
experimental_destroyed</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>total-plane-sep</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomplacement">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sep-radius">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="73"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertsep">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="directional?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="airplane_num" first="0" step="100" last="1000"/>
    <enumeratedValueSet variable="vertical-sep">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomrouting">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentrandomeatn" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>total-plane-sep</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomplacement">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sep-radius">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="73"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertsep">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1638"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="directional?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_num">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertical-sep">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomrouting">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment (copy)" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>total-plane-sep</metric>
    <enumeratedValueSet variable="patchcontrol">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomplacement">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sep-radius">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airport_num">
      <value value="73"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertsep">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fuel_redundancy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_speed">
      <value value="0.1638"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="directional?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tactical">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="airplane_num">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vertical-sep">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomrouting">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
