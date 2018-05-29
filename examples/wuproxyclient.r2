REBOL [
    author:  "Gregg Irwin"
    email:   gregg_a_pointillistic_*_com
    date:    30-Mar-2011
    Purpose: "Weather proxy client. Like wuclient, but subscribes to the proxy port."
]

do %zmq-helpers.r2

print "WUProxyClient"

ctx: zmq-init 1

subscriber: zmq-socket ctx zmq-constants/sub
zmq-connect subscriber "tcp://localhost:8100"

; Subscribe to a zipcode, default to NYC (10001)
;filter: to-integer any [attempt [first system/options/args] 10001]
;filter: to-integer any [attempt [first system/options/args] 10]
;zmq-setsockopt-binary subscriber zmq-constants/subscribe to-binary mold filter
;zmq-setsockopt-binary subscriber zmq-constants/subscribe #{}
z-subscribe subscriber
filter: "all"

; Process 100 updates
total-temp: 0
repeat i 100 [
    msg: z-recv-msg subscriber
    print mold set [zipcode temperature rel-humidity] load msg
    total-temp: total-temp + temperature
]
print ["Average temperature for zipcode" filter "was" (total-temp / 100) "F"]

; Shut down
zmq-close subscriber
zmq-term ctx

halt