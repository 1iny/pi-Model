
extensions [r]

globals
[
;; parameters and global variables for the hexagonal packing:
  x-hex
  y-hex
  i-hex
  j-hex
  spacingx
  spacingy
  y-offset
  
  steps
  number-dead
  number-alive   ;; for calculating mortality
  size-factor    ;; depending on the grid size, take care of the sizes of individuals
  
  Path
]

turtles-own
[ 
  a            ;; a constant of growth function, intrinsic growth rate of mass
  B            ;; body biomass
  Bmax         ;; maximum biomass (asymptotic biomass)
  
  Ae     ;; effective area
  Af     ;; positive area of effect
  rad    ;; radius
  
  f-c    ;; Index for Competition

  Bo           ;; optimal biomass (without interaction and with stress)
  Bo-max        ;; optimal biomass (without interaction and without stress)
  
  plant-dead     ;; plants with gr of 0 will have this value true
]

patches-own 
[ 
  nb-compete     ;; sharing of competition
  nb-facilitate  ;; sharing of facilitation
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;  initialisation of plants  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to plant-setting
    set Bmax random-normal 2000000 200000
    set B random-normal 2 0.2
    set a random-normal 1 0.1
           
    set Bo B
    set Bo-max B
             
    set rad ( B ^ ( 3 / 8 ) ) * ( PI ^ ( -1 / 2 ) )
    set Ae B ^ ( 3 / 4 )

    set plant-dead false  
    
    set size rad * size-factor * 2
    set color scale-color lime  size (size-factor * 0.1) (size-factor * 3.5)
end

;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;  setup  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;

to setup  
  
  ca    
  
  r:clear
  r:eval "library(spatstat)" ;; load R package spatstat for spatial statistics
  
  random-seed randomseed
    
  set-default-shape turtles "circle"  
  
  ask patches 
  [
     set pcolor white
     set nb-compete 0
     set nb-facilitate 0
  ]
  
  set size-factor ( world-width / 100)
         
  if grid [print-grid]
  
  if organisation = "regular" 
  [ 
     set j-hex factor initial_density
     set i-hex initial_density / (2 * j-hex)
     set spacingx world-width / (2 * i-hex)
     set spacingy world-height / (2 * j-hex)
     set x-hex spacingx / 2
     set y-hex spacingy / 2
     set y-offset spacingy / 2 
  ]
  
  ifelse organisation = "cluster"  
  [ ask n-of number_of_cohort patches
     [
       sprout initial_density / number_of_cohort
         [
           plant-setting
                    
           left random 360
           forward random (size-factor * cluster_scale / 2) ;random-normal 0 (size-factor * cluster_scale / 4)            
         ]
     ]
     crt (initial_density - count turtles) [ plant-setting
                                             setxy random-xcor random-ycor ]
  ]
  [  
    crt initial_density 
     [
       plant-setting
    
       if organisation = "regular"
       [ hexagonal ]
        
       if organisation = "random"    
       [ setxy random-xcor random-ycor ]         
     ]
  ]
  
  if L-function [ L-caluclation ]
  if go-with-file-output [ file-output ]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;  runtime  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

to go
   
  set number-dead 0  
  set number-alive count turtles  ;; variable for calculating mortality
  if not any? turtles [ stop ]  
  
;; type of competition
  if competition = "off" 
  [
    ask turtles [ set f-c 1
                  set Ae ( B ^ ( 3 / 4 ) ) ]
  ]
  
  if competition = "complete symmetry"
  [ 
    ask patches [ set nb-compete 0 ]
    ask turtles [ ask patches in-radius (rad * size-factor) [ set nb-compete nb-compete + 1 ] ]
    ask patches with [nb-compete > 0] [set nb-compete 1 / nb-compete]
    ask turtles [ let nbtot-compete (count patches in-radius (rad * size-factor) )
                  let nbsh-compete  (sum ([nb-compete] of patches in-radius (rad * size-factor)))
                  set f-c nbsh-compete / nbtot-compete 
                  set Ae ( B ^ ( 3 / 4 ) ) * f-c ]
  ]
  
  if competition = "allometric symmetry"
  [
    ask patches [set nb-compete 0]
    ask turtles [ask patches in-radius (rad * size-factor) [ set nb-compete nb-compete + [B ^ (3 / 4)] of myself ]]
    ask patches with [nb-compete > 0] [set nb-compete 1 / nb-compete]
    ask turtles [ let nbtot-compete (count patches in-radius (rad * size-factor) )
                  let nbsh-compete  (sum ([nb-compete * [B ^ (3 / 4)] of myself] of patches in-radius (rad * size-factor)))
                  set f-c nbsh-compete / nbtot-compete 
                  set Ae ( B ^ ( 3 / 4 ) ) * f-c ] 
  ]
  
  if competition = "size symmetry"
  [
    ask patches [set nb-compete 0]
    ask turtles [ask patches in-radius (rad * size-factor) [ set nb-compete nb-compete + [B] of myself ]]
    ask patches with [nb-compete > 0] [set nb-compete 1 / nb-compete]
    ask turtles [ let nbtot-compete (count patches in-radius (rad * size-factor) )
                  let nbsh-compete  (sum ([nb-compete * [B] of myself] of patches in-radius (rad * size-factor)))
                  set f-c nbsh-compete / nbtot-compete 
                  set Ae ( B ^ ( 3 / 4 ) ) * f-c ] 
  ]
  
  if competition = "allometric asymmetry"  
  [
    ask patches [set nb-compete 0]
    ask turtles [ask patches in-radius (rad * size-factor) [ set nb-compete nb-compete + [B ^ 10] of myself ]]
    ask patches with [nb-compete > 0] [set nb-compete 1 / nb-compete]
    ask turtles [ let nbtot-compete (count patches in-radius (rad * size-factor) )
                  let nbsh-compete  (sum ([nb-compete * [B ^ 10] of myself] of patches in-radius (rad * size-factor)))
                  set f-c nbsh-compete / nbtot-compete 
                  set Ae ( B ^ ( 3 / 4 ) ) * f-c ] 
  ]
  
  if competition = "complete asymmetry"
  [
    ask patches [set nb-compete 0]
    ask turtles [ ask patches in-radius (rad * size-factor)
                   [ ifelse nb-compete = 0 
                      [ set nb-compete [who] of myself ]
                      [ ifelse ( [B] of turtle ( nb-compete ) ) > [B] of myself
                         [ ] ;do nothing
                         [ set nb-compete [who] of myself ] ] ] ]
    ask turtles [ let nbtot-compete (count patches in-radius ( rad * size-factor ) )
                  let nbsh-compete  (count patches in-radius ( rad * size-factor ) with [nb-compete = [who] of myself] )
                  set f-c nbsh-compete / nbtot-compete 
                  set Ae ( B ^ ( 3 / 4 ) ) * f-c ] 
  ]
  
  
;; type of facilitation  
  if facilitation = "off"
  [ ask turtles [ set Af 0 ] ]
  
  if facilitation = "reciprocity" ;; original facilitation from Chu et al., 2008
  [
    ask patches [ set nb-facilitate 0 ]
    ask turtles [ ask patches in-radius (rad * size-factor) [ set nb-facilitate nb-facilitate + 1 ] ]
    ask turtles [ let nbtot-facilitate (count patches in-radius (rad * size-factor) )
                  let nbsh-facilitate  (count patches in-radius (rad * size-factor) with [nb-facilitate > 1])
                  set Af ( B ^ ( 3 / 4 ) ) * (nbsh-facilitate / nbtot-facilitate)  ]
  ]
  
  if facilitation = "complete symmetry"
  [ 
    ask patches [ set nb-facilitate 0 ]
    ask turtles [ ask patches in-radius (rad * size-factor) [ set nb-facilitate nb-facilitate + 1 ] ] 
    ask patches with [ nb-facilitate > 0 ] [ set nb-facilitate 1 / nb-facilitate ]
    ask turtles [ let nbtot-facilitate (count patches in-radius (rad * size-factor) )
                  let nbsh-facilitate  (sum ([nb-facilitate] of patches in-radius (rad * size-factor)))
                  set Af ( B ^ ( 3 / 4 ) ) * (1 - (nbsh-facilitate / nbtot-facilitate)) ]
  ]
  
  if facilitation = "allometric symmetry"
  [
    ask patches [ set nb-facilitate 0 ]
    ask turtles [ ask patches in-radius (rad * size-factor) [ set nb-facilitate nb-facilitate + [B ^ (3 / 4)] of myself ] ] 
    ask patches with [ nb-facilitate > 0 ] [ set nb-facilitate 1 / nb-facilitate ]
    ask turtles [ let nbtot-facilitate (count patches in-radius (rad * size-factor) )
                  let nbsh-facilitate  (sum ([nb-facilitate * [B ^ (3 / 4)] of myself] of patches in-radius (rad * size-factor)))
                  set Af ( B ^ ( 3 / 4 ) ) * (1 - (nbsh-facilitate / nbtot-facilitate))]
  ]
  
  if facilitation = "size symmetry"
  [
    ask patches [ set nb-facilitate 0 ]
    ask turtles [ ask patches in-radius (rad * size-factor) [ set nb-facilitate nb-facilitate + [B] of myself ] ] 
    ask patches with [ nb-facilitate > 0 ] [ set nb-facilitate 1 / nb-facilitate ]
    ask turtles [ let nbtot-facilitate (count patches in-radius (rad * size-factor) )
                  let nbsh-facilitate  (sum ([nb-facilitate * [B] of myself] of patches in-radius (rad * size-factor)))
                  set Af ( B ^ ( 3 / 4 ) ) * (1 - (nbsh-facilitate / nbtot-facilitate))]
  ]

  if facilitation = "allometric asymmetry"
  [
    ask patches [ set nb-facilitate 0 ]
    ask turtles [ ask patches in-radius (rad * size-factor) [ set nb-facilitate nb-facilitate + [B ^ 10] of myself ] ] 
    ask patches with [ nb-facilitate > 0 ] [ set nb-facilitate 1 / nb-facilitate ]
    ask turtles [ let nbtot-facilitate (count patches in-radius (rad * size-factor) )
                  let nbsh-facilitate  (sum ([nb-facilitate * [B ^ 10] of myself] of patches in-radius (rad * size-factor)))
                  set Af ( B ^ ( 3 / 4 ) ) * (1 - (nbsh-facilitate / nbtot-facilitate))]
  ]
  
  if facilitation = "complete asymmetry"
  [
    ask patches [ set nb-facilitate 0 ]
    ask turtles [ ask patches in-radius (rad * size-factor)
                   [ ifelse nb-facilitate = 0 
                      [ set nb-facilitate [who] of myself ]
                      [ ifelse ( [B] of turtle ( nb-facilitate ) ) > [B] of myself
                         [ ] ;do nothing 
                         [ set nb-facilitate [who] of myself ] ] ] ]
    ask turtles [ let nbtot-facilitate (count patches in-radius ( rad * size-factor ) )
                  let nbsh-facilitate  (count patches in-radius ( rad * size-factor ) with [nb-facilitate != [who] of myself])           
                  set Af ( B ^ ( 3 / 4 ) ) * nbsh-facilitate / nbtot-facilitate ]
  ]
  
;; growth and death
  ask turtles with [plant-dead = false] [growth]
  ask turtles with [plant-dead = true] [decompose]
  
  set steps steps + 1
  
  tick

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; data output as files   
  if go-with-file-output and (count turtles <= 260) and ((count turtles mod 50 <= 10) or ((300 - count turtles) mod 50 <= 10) ) [ file-output ]

;; calculatting L function with confidence
;; if L-function and (steps mod output-period = 0) [ L-caluclation ]
  if L-function and (count turtles <= 260) and ((count turtles mod 50 <= 10) or ((300 - count turtles) mod 50 <= 10) ) [ L-caluclation ]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       
;; plotting
  auto-plot-on  
  
;; mortality
  set-current-plot "Mortality"
  if count turtles > 1
  [ plot number-dead * 100 / number-alive ]   
  
  set-current-plot "Mortality-Biomass (log-log)" 
  if number-dead > 0 and number-alive > 1
  [ set-current-plot-pen "Total"
    plotxy (log (mean [B] of turtles) 10) (log (number-dead / number-alive) 10)  
  ]
  
;; size distridutions
  set-current-plot "Histogram of Sizes of Individuals"
  histogram [B] of turtles
  
;; coefficient of variation  
  set-current-plot "Coefficient of Variation - Biomass"
  if count turtles > 1
  [  
    set-current-plot-pen "CV-total"
    plotxy (ticks + 1)  ( 100 * standard-deviation [B] of turtles / mean [B] of turtles )  
  ]
  
;; biomass  
  set-current-plot "Mean biomass through time"
  if count turtles > 1
  [   
      set-current-plot-pen "Mean"
      plotxy (ticks + 1) mean [B] of turtles
  ]
  
  set-current-plot "Total biomass through time"
  if count turtles > 0
  [ 
     set-current-plot-pen "Total"
     plotxy (ticks + 1) sum [B] of turtles
  ]
  
;; Self-thinning
  set-current-plot "Self-thinning pattern (ln-ln)"
  if count turtles > 1
  [  
    set-current-plot-pen "Total"
    plotxy (ln count turtles) (ln mean [B] of turtles)  
  ]
  
  set-current-plot "Self-thinning pattern (log-log)"
  if count turtles > 1
  [  
    set-current-plot-pen "Total"
    plotxy (log count turtles 10) (log mean [B] of turtles  10)  
  ]
  
;; Relative Interaction Index
  set-current-plot "Relative Interaction Intensity"
  if count turtles > 0
  [   
      set-current-plot-pen "0"
      plotxy (ticks + 1) 0
      set-current-plot-pen "RII"
      plotxy (ticks + 1) (mean [B] of turtles - mean [Bo] of turtles) / (mean [B] of turtles + mean [Bo] of turtles)
  ]

;; Relative Neighbor Importance
  set-current-plot "Relative Neighbor Importance"
  if count turtles > 0
  [   
      set-current-plot-pen "0"
      plotxy (ticks + 1) 0
      set-current-plot-pen "RNI"
      plotxy (ticks + 1) (mean [B] of turtles - mean [Bo] of turtles) / (2 * mean [Bo-max] of turtles - mean [B] of turtles - mean [Bo] of turtles)
  ]

;; Coverage
  set-current-plot "Coverage"
  if count turtles > 1
  [  
    set-current-plot-pen "Coverage"
    plotxy (ticks + 1)  ( count patches with [nb-compete != 0] / 400)   
  ]
 
end

;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;  growth  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to growth
  let f-r 1 - resource-limitation
  let f-s 1 - abiotic-stress
  
  ifelse f-r <= 0 or f-c <= 0
  [ set plant-dead true ]
  [
    ifelse abiotic-stress >= 1
    [ set Bo 0 
      set Bo-max 0
    ]
    [ let Bo-gr a * (Bo ^ 0.75) * ( 1 - ((Bo / Bmax) ^ 0.25) / (f-s * f-r) ) * f-r * f-s   ;; optimal growth without neighbors and with stress      
      set Bo Bo + Bo-gr 
      
      let Bo-max-gr a * (Bo-max ^ 0.75) * ( 1 - ((Bo-max / Bmax) ^ 0.25))  ;; optimal growth without neighbors and without stress      
      set Bo-max Bo-max + Bo-max-gr 
    ]
 
  ;; actual growth rate
  let gr a * Ae * ( 1 - ((B / Bmax) ^ 0.25) / (( 1 - ( abiotic-stress / ( Af + 1) ) ) * f-r * f-c) ) * f-r * ( 1 - ( abiotic-stress / ( Af + 1) ) ) 
 
  ;; growth and death
  ifelse gr <= 0 or gr <= ( (B ^ 0.75) * threshold-of-death ) ;f-r * f-s * f-c * a <= 0.05 
  [ set plant-dead true ]
  [ set B B + gr 
    set rad ( B ^ ( 3 / 8 ) ) * ( PI ^ ( -1 / 2 ) ) ] 
  ] 
  
  set size rad * size-factor * 2

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;  decompose  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to decompose
  
 ifelse decomposition
 [
  set color yellow
  set B B * decomposition-period
  set rad ( B ^ ( 3 / 8 ) ) * ( PI ^ ( -1 / 2 ) )  
  if B < 1 
   [ set number-dead number-dead + 1
     die ]
 ]
 [ set number-dead number-dead + 1 
   die ]
  
 set size rad * size-factor * 2
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;  hexagonal packing installation  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to hexagonal
  ifelse y-hex > world-height
  [    show "too many point"  ]
  [
    setxy x-hex y-offset ;install at the prepared spot
    ;prepare the next one...
    set x-hex x-hex + spacingx
    ifelse y-offset = y-hex
    [  set y-offset y-offset + spacingy ]
    [  set y-offset y-hex ]
    
    if x-hex > world-width
    [    set x-hex spacingx / 2 
         set y-hex y-hex + 2 * spacingy 
         set y-offset y-hex
    ]
  ]
end

to-report factor [n]  ;; return the smallest integer divider of n larger than its square root (translated directly from Weiner's code)
  let root floor(sqrt(n))    
  while [(n / root) < root] 
  [
   set root root + 1
  ]
  report root
end

;; display stuffs
to print-grid
  ask patches with [remainder (pxcor + pycor ) 2 > 0 ]
  [ set pcolor grey ] 
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;  L-caluclation  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to L-caluclation
  
;; send agent variables into an R data-frame
  (r:putagentdf "agentset" turtles "who" "xcor" "ycor")

;; create point pattern with vectors of x- and y-coordinates of turtles and the dimension of the window/world
  let revalstring (word "agppp <- ppp(agentset$xcor, agentset$ycor, c(" min-pxcor "," max-pxcor "), c(" min-pycor "," max-pycor ") )")
  r:eval revalstring
  
;; calculate L function with confidence bands from 500 simulations
  r:eval "Lsim <- envelope(agppp, fun=Lest, nsim=500, nrank=1)"    
  
;; get results from R
  let r r:get "Lsim$r"
  let obs r:get "Lsim$obs"
  let theo r:get "Lsim$theo"
  let hi r:get "Lsim$hi"
  let lo r:get "Lsim$lo"
  
;; combine results into a multidimensional list for plotting
  let ripl (map [(list ?1 ?2 ?3 ?4 ?5)] r obs theo hi lo)
  
;; plot the results  
  set-current-plot "L function"
  clear-plot
  foreach ripl
  [ 
    set-current-plot-pen "obs"
    plotxy (item 0 ?) (item 1 ? - item 2 ?)
    set-current-plot-pen "theo"
    plotxy (item 0 ?) (item 2 ? - item 2 ?)
    set-current-plot-pen "high"
    plotxy (item 0 ?) (item 3 ? - item 2 ?)
    set-current-plot-pen "low"
    plotxy (item 0 ?) (item 4 ? - item 2 ?)
  ]
;; save result of L-function as .csv file  
  if L-output 
  [
    let Path-L (word Directory organisation "-" initial_density "-" competition "-" facilitation "-stress" abiotic-stress "-size" count turtles "-LF.csv")
    let evalstring (word "write.table(Lsim,file='" Path-L "')")
    r:eval evalstring
  ]
   
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;  save data as .csv file  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to file-output
  
  set Path (word Directory organisation "-" initial_density "-" competition "-" facilitation "-stress" abiotic-stress "-size" count turtles ".csv")
  
  (r:putagentdf "ag" turtles "who" "B" "xcor" "ycor")
  let evalstring (word "write.table(ag,file='" Path "')")
  r:eval evalstring
  
end
@#$#@#$#@
GRAPHICS-WINDOW
462
10
897
466
-1
-1
2.125
1
10
1
1
1
0
1
1
1
0
199
0
199
1
1
1
ticks

BUTTON
297
350
380
392
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
297
297
381
339
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
188
442
254
475
go-180
repeat 180 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

PLOT
1042
54
1341
229
Histogram of Sizes of Individuals
Classes
Frequency
0.0
3000.0
0.0
100.0
true
false
PENS
"default" 100.0 1 -2674135 true

SWITCH
16
10
150
43
grid
grid
1
1
-1000

PLOT
1347
10
1646
229
Coefficient of Variation - Biomass
time
CV %
0.0
30.0
0.0
100.0
true
false
PENS
"CV-total" 1.0 0 -2674135 true

BUTTON
297
401
380
444
go-once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

PLOT
1042
235
1341
454
Mean biomass through time
time
Biomass
0.0
30.0
0.0
100.0
true
false
PENS
"Mean" 1.0 0 -2674135 true

PLOT
1653
460
1952
680
Self-thinning pattern (ln-ln)
ln density
ln mean biomass
0.0
10.0
0.0
10.0
true
false
PENS
"Total" 1.0 2 -2674135 true

MONITOR
1191
10
1341
55
Maximum individual biomass
max [B] of turtles with [plant-dead = false]
2
1
11

MONITOR
1042
10
1192
55
Minimum individual biomass
min [B] of turtles with [plant-dead = false]
2
1
11

BUTTON
16
403
82
436
go-30
repeat 30 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
102
403
168
436
go-60
repeat 60 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

CHOOSER
16
227
181
272
competition
competition
"off" "complete symmetry" "allometric symmetry" "size symmetry" "allometric asymmetry" "complete asymmetry"
1

CHOOSER
188
227
353
272
facilitation
facilitation
"off" "reciprocity" "complete symmetry" "allometric symmetry" "size symmetry" "allometric asymmetry" "complete asymmetry"
2

SLIDER
16
320
255
353
abiotic-stress
abiotic-stress
0
1
0.9
0.1
1
NIL
HORIZONTAL

PLOT
1347
235
1646
454
Total biomass through time
time
Biomass
0.0
30.0
0.0
400000.0
true
false
PENS
"Total" 1.0 0 -2674135 true

SLIDER
16
280
255
313
resource-limitation
resource-limitation
0
1
0
0.1
1
NIL
HORIZONTAL

BUTTON
188
403
254
436
go-90
repeat 90 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

SWITCH
155
10
296
43
decomposition
decomposition
1
1
-1000

SLIDER
16
360
255
393
threshold-of-death
threshold-of-death
0
0.5
0.05
0.005
1
NIL
HORIZONTAL

SLIDER
16
48
256
81
decomposition-period
decomposition-period
0
1
1
0.05
1
NIL
HORIZONTAL

PLOT
1652
235
1951
454
Coverage
time
Coverage %
0.0
30.0
0.0
100.0
true
false
PENS
"Coverage" 1.0 0 -16777216 true

BUTTON
16
441
82
474
go-120
repeat 120 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
102
442
168
475
go-150
repeat 150 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

PLOT
748
470
1004
643
Relative Interaction Intensity
time
RII
0.0
30.0
-1.0
1.0
true
true
PENS
"RII" 1.0 0 -2674135 true
"0" 1.0 0 -7500403 true

PLOT
1651
10
1950
229
Mortality
time
Mortality %
0.0
30.0
0.0
100.0
true
false
PENS
"default" 1.0 1 -16777216 true

PLOT
1042
461
1341
680
Self-thinning pattern (log-log)
log 10 (density)
log 10 (mean biomass)
0.0
5.0
0.0
5.0
true
false
PENS
"Total" 1.0 2 -2674135 true

INPUTBOX
16
95
132
155
randomseed
123456789
1
0
Number

SLIDER
268
136
409
169
number_of_cohort
number_of_cohort
1
200
6
1
1
NIL
HORIZONTAL

MONITOR
137
96
253
149
Population
count turtles
17
1
13

SLIDER
268
175
409
208
cluster_scale
cluster_scale
0
100
100
1
1
%
HORIZONTAL

CHOOSER
16
163
154
208
organisation
organisation
"cluster" "random" "regular"
0

SWITCH
290
54
388
87
L-function
L-function
1
1
-1000

PLOT
380
471
722
747
L function
distance
L(d)
-1.0
51.0
-3.0
3.0
true
true
PENS
"obs" 1.0 0 -2674135 true
"theo" 1.0 0 -10899396 true
"high" 1.0 0 -7500403 true
"low" 1.0 0 -7500403 true

SWITCH
16
483
184
516
go-with-file-output
go-with-file-output
1
1
-1000

INPUTBOX
16
516
344
576
Directory
C:/Lin/setting 1/
1
0
String

SLIDER
184
483
344
516
output-period
output-period
1
50
1
1
1
NIL
HORIZONTAL

PLOT
1347
460
1646
680
Mortality-Biomass (log-log)
log 10 (mean biomass)
log (mortality)
0.0
5.0
-4.0
0.0
true
false
PENS
"Total" 1.0 2 -2674135 true

INPUTBOX
158
155
259
215
initial_density
300
1
0
Number

SWITCH
290
94
388
127
L-output
L-output
1
1
-1000

PLOT
748
645
1004
819
Relative Neighbor Importance
time
RNI
0.0
30.0
-0.03
0.03
true
true
PENS
"RNI" 1.0 0 -10899396 true
"0" 1.0 0 -7500403 true

@#$#@#$#@

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 4.1.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Experiment-cluster" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>count turtles &lt;= 50</exitCondition>
    <metric>count turtles</metric>
    <metric>mean [B] of turtles</metric>
    <metric>(mean [B] of turtles - mean [Bo] of turtles with [Bo != 0]) / (mean [B] of turtles + mean [Bo] of turtles with [Bo != 0])</metric>
    <enumeratedValueSet variable="abiotic-stress">
      <value value="0.1"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="threshold-of-death">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_density">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomseed">
      <value value="123456789"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="competition">
      <value value="&quot;complete symmetry&quot;"/>
      <value value="&quot;complete asymmetry&quot;"/>
      <value value="&quot;allometric asymmetry&quot;"/>
      <value value="&quot;size symmetry&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="facilitation">
      <value value="&quot;off&quot;"/>
      <value value="&quot;complete symmetry&quot;"/>
      <value value="&quot;complete asymmetry&quot;"/>
      <value value="&quot;reciprocity&quot;"/>
      <value value="&quot;allometric asymmetry&quot;"/>
      <value value="&quot;size symmetry&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="organisation">
      <value value="&quot;cluster&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="go-with-file-output">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="L-function">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="L-output">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment-random" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>count turtles &lt;= 50</exitCondition>
    <metric>count turtles</metric>
    <metric>mean [B] of turtles</metric>
    <metric>(mean [B] of turtles - mean [Bo] of turtles with [Bo != 0]) / (mean [B] of turtles + mean [Bo] of turtles with [Bo != 0])</metric>
    <enumeratedValueSet variable="abiotic-stress">
      <value value="0.1"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="threshold-of-death">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_density">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomseed">
      <value value="123456789"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="competition">
      <value value="&quot;complete symmetry&quot;"/>
      <value value="&quot;complete asymmetry&quot;"/>
      <value value="&quot;allometric asymmetry&quot;"/>
      <value value="&quot;size symmetry&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="facilitation">
      <value value="&quot;off&quot;"/>
      <value value="&quot;complete symmetry&quot;"/>
      <value value="&quot;complete asymmetry&quot;"/>
      <value value="&quot;reciprocity&quot;"/>
      <value value="&quot;allometric asymmetry&quot;"/>
      <value value="&quot;size symmetry&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="organisation">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="go-with-file-output">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="L-function">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="L-output">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment-cluster-Pmax" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="230"/>
    <exitCondition>count turtles &lt;= 50</exitCondition>
    <metric>count turtles</metric>
    <metric>mean [B] of turtles</metric>
    <enumeratedValueSet variable="abiotic-stress">
      <value value="0"/>
      <value value="0.1"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="threshold-of-death">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_density">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomseed">
      <value value="123456789"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="competition">
      <value value="&quot;off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="facilitation">
      <value value="&quot;off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="organisation">
      <value value="&quot;cluster&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="go-with-file-output">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="L-function">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="L-output">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment-Random-Pmax" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="230"/>
    <exitCondition>count turtles &lt;= 50</exitCondition>
    <metric>count turtles</metric>
    <metric>mean [B] of turtles</metric>
    <enumeratedValueSet variable="abiotic-stress">
      <value value="0"/>
      <value value="0.1"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="threshold-of-death">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_density">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomseed">
      <value value="123456789"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="competition">
      <value value="&quot;off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="facilitation">
      <value value="&quot;off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="organisation">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="go-with-file-output">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="L-function">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="L-output">
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
