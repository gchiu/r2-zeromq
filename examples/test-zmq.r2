REBOL [
    author: "Gregg Irwin" 
    email:  gregg_a_pointillistic_*_com
    date:   30-mar-2011
    Purpose: {
        Test a few 0MQ features
    }
]

import: :do

import %zmq-helpers.r2

;-------------------------------------------------------------------------------

print ["0MQ version:" zmq-version type? zmq-version]
z-assert-version 2.0.0
;z-assert-version 3.0.0

print zmq-strerror 0

ctx: zmq-init 1

sender: zmq-socket ctx ZMQ-CONSTANTS/PUSH
zmq-bind sender "tcp://*:5555"


;-------------------------------------------------------------------------------


res: z-set-id sender
print ["Set identity returned:" mold res]
if res <> ZMQ_SUCCESS [
    print [tab "error:" zmq-strerror zmq-errno]
]

print ["Get identity returned:" mold z-get-id sender]

print ["Get rate returned:" mold zmq-getsockopt-int sender ZMQ-CONSTANTS/RATE]
print ["set rate 50 returned:" mold res: zmq-setsockopt-int sender ZMQ-CONSTANTS/RATE 50]
if res <> ZMQ_SUCCESS [
    print [tab "error:" zmq-strerror zmq-errno]
]
print ["Get rate returned:" mold zmq-getsockopt-int sender ZMQ-CONSTANTS/RATE]
print ["set rate 25 returned:" mold zmq-setsockopt-int sender ZMQ-CONSTANTS/RATE 25]
print ["Get rate returned:" mold zmq-getsockopt-int sender ZMQ-CONSTANTS/RATE] 

print ["Get hwm returned:" mold zmq-getsockopt-int sender ZMQ-CONSTANTS/HWM]
print ["set hwm <256> returned:" mold zmq-setsockopt-int sender ZMQ-CONSTANTS/HWM 256]
print ["Get hwm returned:" mold zmq-getsockopt-int sender ZMQ-CONSTANTS/HWM]

print ["Get send-buffer returned:" mold zmq-getsockopt-int sender ZMQ-CONSTANTS/SNDBUF]

;!! R2 binding returns a correct result. R3 extension does not.
print ["Get socket type returned:" mold zmq-getsockopt-int sender ZMQ-CONSTANTS/TYPE] ; needs 0mq 2.1.1

;-------------------------------------------------------------------------------

sink: zmq-socket ctx zmq-constants/xrep
zmq-bind sink "inproc://example"

; First allow 0MQ to set the identity
anonymous: zmq-socket ctx zmq-constants/req
zmq-connect anonymous "inproc://example"
z-send-msg anonymous "XREP uses a generated UUID"
z-dump sink

; Then set the identity ourself
identified: zmq-socket ctx zmq-constants/req
zmq-setsockopt-binary identified ZMQ-CONSTANTS/IDENTITY to binary! "Hello"
zmq-connect identified "inproc://example"
z-send-msg identified "XREP uses REQ's socket identity"
z-dump sink

zmq-close sink
zmq-close anonymous
zmq-close identified

;-------------------------------------------------------------------------------




zmq-close sender

; See doc notes about pending outgoing messages and setting LINGER to 0 before
; calling zmq-term.
zmq-term ctx

halt