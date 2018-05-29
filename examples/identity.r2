REBOL [
    author:  "Gregg Irwin"
    email:   gregg_a_pointillistic_*_com
    date:    28-Mar-2011
    Purpose: {
        Demonstrates identities used by the request-reply pattern.
        Run this program by itself.
    }
]

do %zmq-helpers.r2

print "Identity"

ctx: zmq-init 1

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
zmq-term ctx


halt