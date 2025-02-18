;each tick is representative of 1 hour

;6264 ticks = 261 days
;model only models working days Mon-Fri (footfall in the City dramatically reduces on weekends)

;singular and plural
;TO NOTE: bicycles and bikes are used interchangably
breed [bikes bike]
breed [thieves thief]
breed [policeofficer police]

;global variables that all agents own
globals[
  count-total
  enforce?
  hide?
  police-thief?
  police-bike?
  bikemarking?
  removeparts?
  recovered
]

;variables that all patches own
patches-own[
  accessible?
  q-val-north
  q-val-south
  q-val-east
  q-val-west
]

;variables that thief agents own
thieves-own[
  crime-probability
  birth-tick
  hidden?
]

;variables that bicycles own
bikes-own[
  desirability
  security
  stolen?
  birth-tick
  show?
  marked?
  advised?
  remove?
]

;creates the map of the City of London
to init-map
  import-pcolors "./london.png"
  ask patches[
    ;set all patches in the image (grid space) as accessible
    set accessible? true
    ;patches that are pinkish in the image are buildings and therefore are inaccessible
    if pcolor = 28.6 [set accessible? false]
  ]
end

;sets bicycles in the model
to setup-bikes
  create-bikes ratio-bikes * population-size [
  spawn-bike

]
end

;sets thieves in the model
to setup-thieves
  create-thieves ratio-thieves * population-size [
    spawn-thief
  ]
end

;sets police in the model
to setup-policeofficer
  create-policeofficer ratio-policeofficer * population-size / 40[
    spawn-police
  ]
end

;setup procedure that is called once the setup button is clicked
to setup
  __clear-all-and-reset-ticks
  init-map
  setup-bikes
  setup-thieves
  setup-policeofficer
  set hide? false
end

;go procedure that is called once the go button is clicked
to go
  ;thieves are not seen in the model at all times, if hidden is false they are seen, if hidden is true they are hidden
  ask thieves with [hidden? = false][
    set hide? false
  ]
  ask bikes[
    ;bicycles leave during 5-7ish
    let leave (8 + random 2)
    ;bicycles arrive during 7-9ish
    let arrive (22 + random 2)

    ;ensures that bicycles come and go during the working day
    ;hides and shows the turtles
    if (ticks - birth-tick = arrive) or (ticks - birth-tick = arrive + 1)[
      ;restarts the time when bicycles arrive
      set birth-tick ticks
      set show? true
      st
    ]
    if (ticks - birth-tick = leave) or (ticks - birth-tick = leave + 1)[
   ; or (ticks - birth-tick = leave + 1)[
      set show? false
      ht
    ]
  ]

  ;thieves move about if they are in the area
  if hide? = false[move-thief]

  ;if the bike marking intervention has been clicked, this is run
  if bikemarking? = true [
    bike-bikemarking
    ask bikes with [bikemarking? = true and show? = true][
      bikes-talk
    ]
  ]
  ;if the advise removal of bicycle parts intervention has been clicked, this is run
  if removeparts? = true [
    remove-parts
    ask bikes with [remove? = true and show? = true][
      bikes-talk
    ]
  ]
  ;calls the procedure that moves police agents
  move-police

  ask thieves[
    ;like bicycles, thieves do not spend all their time at the location
    if (ticks - birth-tick) = random 8 + 3 [hide-turtle set hidden? true]
    if (ticks - birth-tick) = 15 + random 5 [show-turtle set hidden? false set birth-tick ticks]
    if random 1000 = 5 [die]
    if random 1000 = 5 [thief-enter]
    ;low threshold, once this is reached thief-elsewhere procedure is called
    if crime-probability < 0.1 [
      thief-elsewhere
    ]
    ]
  ;new thieves enter the environment
  if count thieves < ((ratio-thieves * population-size ) - (ratio-thieves * population-size * 0.4)) [create-thieves random (ratio-thieves * population-size) [spawn-thief]]
  ;new people decide to cycle to work
 if count bikes < ((ratio-bikes * population-size) - (ratio-bikes * population-size) * 0.15) [create-bikes (ratio-bikes * population-size * 0.1 ) [spawn-bike]]

tick
  ;model stops once 261 days has been reached
  if ticks = 6264 [stop]
end

;sets out the value of patches for thieves
;as each patch is 1 pixel in the image, a radius of 5 is used to make it as close to real life as possible
to thief-patches
  ask patches in-radius 5 with [(accessible?) and (count turtles-here > 1)][
    if (any? thieves in-radius 5 with [accessible?])[
        set q-val-north 0
        set q-val-east 0
        set q-val-south 0
        set q-val-west 0
      ]
    if (any? bikes in-radius 5 with [accessible?])[
        set q-val-north 10
        set q-val-east 10
        set q-val-south 10
        set q-val-west 10
      ]
    if (any? policeofficer in-radius 5 with [accessible?])[
        set q-val-north -10
        set q-val-east -10
        set q-val-south -10
        set q-val-west -10
      ]
    ]
end

;sets out the value of patches for police
to police-patches
  ask patches in-radius 5 with [(accessible?) and (count turtles-here > 1)][
    if (any? thieves in-radius 5 with [accessible?])[
        set q-val-north 10
        set q-val-east 10
        set q-val-south 10
        set q-val-west 10
      ]
    if (any? bikes in-radius 5 with [accessible?])[
        set q-val-north 2
        set q-val-east 2
        set q-val-south 2
        set q-val-west 2
      ]
    if (any? policeofficer in-radius 5 with [accessible?])[
        set q-val-north -10
        set q-val-east -10
        set q-val-south -10
        set q-val-west -10
      ]
    ]
end

;movement of all agents
to move
  ;gets the current x and y co-ordinates
  let current-xcor xcor
    let current-ycor ycor
  ;25% chance of moving north, east, south, west
    set heading ((random 4) * 90)
      let probability random-float 1
      ifelse (probability < 0.8)[ ;80% chance going in intended  direction (MDP)
      ][
        ifelse (probability < 0.9)[
          set heading (heading + 90)];go left of intended direction
        [set heading (heading - 90)];go right of intended direction
      ]
  fd 10 ; direction is set, go forwards 10 patches
  ;accidently entered an area that is marked as a building, reverse
      if pcolor = 28.6[
    bk 10
  ]
  ;set the q-values
      set-qvalue current-xcor current-ycor heading xcor ycor
end

;movement of thief agents that are active
to move-thief
  ask thieves with [hidden? = false][
    move
    if crime-probability > 0.2[
    steal-bike
    ]
    sell-bike
  ;]
    thief-patches
  ]
end

;police need to check for stolen bikes with trackers
to move-police
  ;ifelse enforce? = true[
  ifelse (police-thief? = true) or (police-bike? = true) or (bikemarking? = true)[
  ask policeofficer[
    move
      if police-thief? = true [police-thief]
      ;policebike recover bicycles
      if (police-bike? = true) or (bikemarking? = true)[police-bike]
     ; if bikemarking? = true [police-recover]
  police-patches
  ]
  ]
  [ask policeofficer[hide-turtle]]

end

;thief steals a bicycle
to steal-bike
 let randomnumber random-float 1
 let randomnumber2 random-float 1
;  ask bikes in-radius 6 with [(hidden? = false) and (shape = "bike") and (color = green) and (not stolen?)][
  ask bikes in-radius 2 with [(show? = true) and (shape = "bike") and (color = green) and (not stolen?)][
    ;if (shape = "bike") and (color = green) and (not stolen?)[
      if (desirability > randomnumber) and (security < randomnumber2)[
        set count-total count-total + 1
        hatch-bikes 1 [set stolen? true set color red]
        die
      ]
    ]
 ; ]
end

;bicycles are sold outside the area
to sell-bike
  ask bikes with [color = red and show? = true][
  ;ask bikes with [stolen? = true][
    ;if ticks - birth-tick > localvariable2 + random 10 [show-turtle set hidden? false set birth-tick ticks]
    ;bike is sold in the area
    if ticks - birth-tick = random 40 [hatch-bikes 1 die]
    ;bike is sold outside of the area
    if ticks - birth-tick > random 50 [die]
  ]
end

;thief comes to area
to thief-enter
  hatch-thieves 1 [spawn-thief]
end

;thieves detered from stealing/go to another area
to thief-elsewhere
  die
end

;police interaction with thieves
to police-thief
  ask thieves in-radius 5 with [hidden? = false][
    if random-float 1 > 0.5 [
    set crime-probability crime-probability - (crime-probability * 0.25)
    thieves-talk
    ;thieves go elsewhere/stop thieving here
    if crime-probability < 0.2 [die]
  ]
  ]
end

;police have greater 'vision' of the environment
to police-bike
  ask bikes in-radius 50 with [show? = true and advised? = false][
    ;if the giving advice intervention is active,  advise them on safer locking through verbally or leaflet
    if police-bike? = true[
    let chance random-float 1
    if chance > 0.5 [set security security + 0.2 set advised? true]
    ]
    ;if the bike marking intervention is active and a bicycle is found, take it.
    if bikemarking? = true[
    if any? bikes in-radius 3 with [(stolen? = true) and (marked? = true)][
        if random-float 1 > 0.8[
          let time ticks
          set recovered recovered + 1
          die
          ;bicycle is returned to the owner
          if ticks = time + 48 [
      hatch-bikes 1 [spawn-bike set marked? true set security random-float 1 + 0.2]
        ]
        ]
  ]
  ]
  ]
end


;bikes have bikemarking trackers- if recovered, possible to return to owner
to bike-bikemarking
  ask bikes with [(show? = true) and (random-float 1 < 0.02)][
    if random-float 1 < 0.02 [
    set marked? true
    set desirability desirability - 0.1
    set security security + 0.05
  ]
  ]
end

;bicycle parts are removed if the owner has finally decided upon
to remove-parts
  ask bikes with [(show? = true) and (random-float 1 < 0.02) and (remove? = not true)][
      set remove? true
      set desirability desirability - 0.1
  ]
  end

;thieves talk to other thieves
to thieves-talk
  ask thieves in-radius 15 with [(hidden? = false) and (random-float 1 > 0.5)][
    set crime-probability crime-probability - 0.05
  ]
end

;bike owners talk to other bike owners
to bikes-talk
  ask bikes in-radius 5 with [(show? = true) and (random-float 1 > 0.2)][
    if bikemarking? = true [set marked? true]
    if removeparts? = true [remove-parts]
  ]
end

;open source code that has been adapted from Larry Lin
to set-qvalue[current-xcor current-ycor current-heading new-xcor new-ycor]
  ; Q(s',a') optimal future value
  let optimal-f-val 0

  ;compute optimal future value
  ;finds the maximum reward possible (north, east, south, west)
  ask patch new-xcor new-ycor[
     set optimal-f-val (max (list q-val-north q-val-east q-val-south q-val-west))
  ]

  ;computed q-values
  ask patch current-xcor current-ycor[
    let alpha 0.8 ;learning rate
    let gamma 0.8 ;discount factor
    let reward 10
  if(current-heading = 0)[
    ;; north
    set q-val-north (precision (q-val-north + alpha * (reward + (gamma * optimal-f-val) - q-val-north)) 1)
    ]
  if(current-heading = 90)[
    ;; east
    set q-val-east (precision (q-val-east + alpha * (reward + (gamma * optimal-f-val) - q-val-east)) 1)
    ]
  if(current-heading = 180)[
    ;; south
    set q-val-south (precision (q-val-south + alpha * (reward + (gamma * optimal-f-val) - q-val-south)) 1)

    ]
  if(current-heading = 270)[
    ;; west
    set q-val-west (precision (q-val-west + alpha * (reward + (gamma * optimal-f-val) - q-val-west)) 1)
    ]
]
end

;sets all characteristics and variables of police
to spawn-police
  set shape "person"
  set color blue
  set size 20
  move-to one-of patches with [accessible?]
end

;sets all characteristics and variables of bicycles
to spawn-bike
  set shape "bike"
  set color green
  set size 20
  set desirability random-float 1
  set security random-float 1
  set stolen? false
  set birth-tick ticks
  set marked? false
  set show? true
  set advised? false
  move-to one-of patches with [accessible?]
end

;sets all characteristics and variables of thieves
to spawn-thief
  setxy random-xcor random-ycor
  set shape "person"
  set color red
  set size 20
  set crime-probability random-float 1
  move-to one-of patches with [accessible?]
  set birth-tick ticks
  set hidden? false
end
@#$#@#$#@
GRAPHICS-WINDOW
217
21
1490
459
-1
-1
1.0
1
10
1
1
1
0
1
1
1
-632
632
-214
214
0
0
1
ticks
30.0

BUTTON
34
196
98
229
Setup
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

SLIDER
14
21
186
54
population-size
population-size
5000
30000
12000.0
1000
1
NIL
HORIZONTAL

SLIDER
15
66
188
99
ratio-thieves
ratio-thieves
0
0.01
0.01
0.001
1
NIL
HORIZONTAL

SLIDER
16
108
187
141
ratio-bikes
ratio-bikes
0
0.3
0.25
0.005
1
NIL
HORIZONTAL

BUTTON
113
196
176
229
Go
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

MONITOR
154
240
211
285
Police
count policeofficer
17
1
11

SLIDER
16
153
188
186
ratio-policeofficer
ratio-policeofficer
0
0.1
0.1
0.01
1
NIL
HORIZONTAL

MONITOR
10
299
103
344
bicycles stolen
count-total
17
1
11

BUTTON
24
391
194
424
Police warn thieves
set police-thief? true
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
24
435
196
468
Offer locking advice
set police-bike? true
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
271
493
1077
806
Bicycle thefts over time
time (in ticks)
stolen bicycles
0.0
2545.0
0.0
800.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count-total"

BUTTON
23
482
197
515
Bike marking
set bikemarking? true
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
112
299
182
344
recovered
recovered
17
1
11

MONITOR
84
239
141
284
Bicycles
count bikes with [show? = true]
17
1
11

MONITOR
10
239
72
284
Thieves
count thieves with [hidden? = false]
17
1
11

TEXTBOX
75
367
225
385
INTERVENTIONS
11
0.0
1

BUTTON
15
529
214
570
Advise removal of expensive parts
set removeparts? true
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This model is a 2D agent-based model of bicycle theft within a small area in the City of London specifically focussing upon interventions that may be implemented to deter bicycle thefts. 

## HOW IT WORKS

Agents are broken down into 3 types: bicycles, thieves and police. It is the sole aim for thieves to steal bicycles within the environment, bicycles are naturally in the environment and police are there to try and limit thefts. 

## HOW TO USE IT

Click on the SETUP button to set up the environment. Set the NUMBER slider to change the number of agents within the environment. Click on GO to start the agents moving. Interventions can be activated by clicking on the button of the intervention, remember to setup the model again with the new intervention. 



## THINGS TO TRY

Change the number of agents within the environment and experiment with the interventions provided. To note, multiple interventions are allowed in the model.

## EXTENDING THE MODEL

The inclusion of environmental features for example street lighting, CCTV and bus stops.
Greater interventions.



## CREDITS AND REFERENCES

Emily Liu

Q-learning: Larry Lin, Modelling Commons.
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

bike
false
1
Line -7500403 false 163 183 228 184
Circle -7500403 false false 213 184 22
Circle -7500403 false false 156 187 16
Circle -16777216 false false 28 148 95
Circle -2674135 false true 24 144 102
Circle -16777216 false false 174 144 102
Circle -2674135 false true 177 148 95
Polygon -2674135 true true 75 195 90 90 98 92 97 107 192 122 207 83 215 85 202 123 211 133 225 195 165 195 164 188 214 188 202 133 94 116 82 195
Polygon -2674135 true true 208 83 164 193 171 196 217 85
Polygon -2674135 true true 165 188 91 120 90 131 164 196
Line -7500403 false 159 173 170 219
Line -7500403 false 155 172 166 172
Line -7500403 false 166 219 177 219
Polygon -2674135 true true 187 92 198 92 208 97 217 100 231 93 231 84 216 82 201 83 184 85
Polygon -2674135 true true 71 86 98 93 101 85 74 81
Rectangle -16777216 true false 75 75 75 90
Polygon -2674135 true true 70 87 70 72 78 71 78 89
Circle -7500403 false false 153 184 22
Line -7500403 false 159 206 228 205

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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
