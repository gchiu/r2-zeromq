REBOL [
    author:  ["Andreas Bolka" "Gregg Irwin"]
    email:   gregg_a_pointillistic_*_com
    date:    30-Mar-2011
    Purpose: {
        Weather update client
        Connects SUB socket to tcp://localhost:5556
        Collects weather updates and finds avg temp in zipcode
    }
]

do %zmq-helpers.r2

print "WUClient"

ctx: zmq-init 1

subscriber: zmq-socket ctx zmq-constants/sub
zmq-connect subscriber "tcp://localhost:5556"

;; Subscribe to a zipcode, default to NYC (10001)
;filter: to-integer any [attempt [first system/options/args] 10001]
;filter: to-integer any [attempt [first system/options/args] 10]
;zmq-setsockopt-binary subscriber zmq-constants/subscribe to-binary mold filter
zmq-setsockopt-binary subscriber zmq-constants/subscribe filter: #{}

;; Process 100 updates
total-temp: 0
repeat i 100 [
    msg: z-recv-msg subscriber
    print mold set [zipcode temperature rel-humidity] load msg
    total-temp: total-temp + temperature
]
print ["Average temperature for zipcode" filter "was" (total-temp / 100) "F"]

;; Shut down
zmq-close subscriber
zmq-term ctx

halt