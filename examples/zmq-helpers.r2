REBOL [
    title:  "0MQ helper functions for R2 binding"
    author: ["Gregg Irwin"]
    email:  gregg_a_pointillistic_*_com
    ; name:   helpers
    ; type:   module
    ; exports: [
    ;     ZMQ_SUCCESS NO_FLAGS
    ;     
    ;     z-assert-version z-cur-time-msec 
    ;     z-close
    ;     z-send-msg z-recv-msg z-more-to-come? z-broker-message z-send-msg-ex
    ;     z-set-id z-get-id
    ;     z-subscribe z-unsubscribe ; z-subscribe-to-all 
    ;     z-dump z-print
    ; ]
]

import: :do

do %ZeroMQ-binding.r2

;-------------------------------------------------------------------------------

ZMQ_SUCCESS: 0
NO_FLAGS: 0

; Patched from R3. (My COLLECT syntax is different, but this needs to be standard)
collect: func [
    {Evaluates a block, storing values via KEEP function, and returns block of collected values.}
    body [block!] "Block to evaluate"
    /into {Insert into a buffer instead (returns position after insert)}
    output [series!] "The buffer series (modified)"
][
    unless output [output: make block! 16]
    do func [keep] body func [value [any-type!] /only] [
        output: apply :insert [output :value none none only]
        :value
    ]
    either into [output] [head output]
]

pad: func [value [integer!] len [integer!] /local s] [
    s: form value
    head insert/dup s #"0" len - length? s
]

;-------------------------------------------------------------------------------


z-assert-version: func [want-version [tuple!]] [
    ;assert [want-version > zmq-version]
    if want-version > zmq-version [
        print ["Current 0MQ version is" zmq-version]
        print ["This application needs at least version" want-version "of 0MQ. Unable to continue."]
        halt
    ]
    true
]

z-broker-message: func [
    "Broker a message from a source to a destination socket. Handles multipart messages."
    source "0MQ Socket"
    dest   "0MQ Socket"
    /local msg
][
    forever [
        ; Process all parts of the message
        msg: z-recv-msg/binary source
        ;z-send-msg-ex frontend msg either z-more-to-come? backend [ZMQ-CONSTANTS/SNDMORE] [NO_FLAGS]
        ;if not z-more-to-come? backend [break]
        either z-more-to-come? source [
            z-send-msg/more-to-come dest msg
        ][
            ; Last message part
            z-send-msg dest msg
            break
        ]
    ]
]

z-close: func [
    sockets [integer! block!] "0MQ sockets"
][
    collect [
        foreach socket compose [(sockets)] [
            keep zmq-close socket
        ]
    ]
]

; s_clock replacement
z-cur-time-msec: does [to integer! now/time/precise]

z-dump: func [
    "Receives all message parts from socket, prints neatly."
    socket "0MQ socket"
    /local msg is-text?
][
    print "-------------------------------------------"
    forever [
        ; Process all parts of the message
        msg: z-recv-msg/binary socket

        ; Dump the message as text or binary
        is-text?: yes
        foreach byte msg [
            if any [byte < 32  byte > 127] [is-text?: no]
        ]
        print reform [
            rejoin ["[" pad length? msg 3 "]"]
            either is-text? [to string! msg] [msg]
        ]
        if not z-more-to-come? socket [break]
    ]
]


z-more-to-come?: func [
    socket "0MQ socket"
][
    to logic! zmq-getsockopt-int socket ZMQ-CONSTANTS/RCVMORE
]

;  Print formatted string to stdout, prefixed by date/time and
;  terminated with a newline.
z-print: func [value [any-type!]] [  ; s_console (const char *format, ...)
    prin now
    print value
]

; The ØMQ standard helper func is called s_recv.
z-recv-msg: func [
    "Receive a 0MQ message from the socket and return a REBOL string. Returns none if the context is being terminated or the process was interrupted."
    socket "0MQ socket"
    /binary "Return a binary! value instead of a string."
    /options ; allow specifying option flags
        opts [integer!]
    /local msg res data
][
    ; This is using Kaj's func in the zmq context, which hasn't been changed.
    ; Need to look at return value consistency.
    data: copy #{}
    res: zmq-recv socket data any [opts NO_FLAGS]
    if res [either binary [data] [to string! data]]
]


z-recv-multipart-msg: func [
    "Receive a 0MQ message from the socket and return a REBOL string. Returns none if the context is being terminated or the process was interrupted."
    socket "0MQ socket"
    /binary "Return a binary! value instead of a string."
][
    collect [
        until [
            keep either binary [z-recv-msg/binary] [z-recv-msg] socket
            not z-more-to-come? socket
        ]
    ]    
]

; The ØMQ standard helper funcs are called s_send and s_sendmore.
z-send-msg: func [
    "Send the string to the 0MQ socket"
    socket "0MQ socket" 
    data [string! binary!]
    /more-to-come "This is the first part of a multi-part message"
    /local res
][
    ; This is using Kaj's func in the zmq context, which hasn't been changed.
    ; Need to look at return value consistency.
    res: zmq-send socket to binary! data either more-to-come [ZMQ-CONSTANTS/SNDMORE] [NO_FLAGS]
]

; I like not having to specify flags for each send, and the /more-to-come flag
; above is probably the most common case, easily extended to include a /no-wait
; or /async refinment. If flags don't grow too much, that will work well, except
; that refinements are a bit of a pain to propagate.
z-send-msg-ex: func [
    "Send the string to the 0MQ socket"
    socket "0MQ socket" 
    data  [string! binary!]
    flags [integer!]
    /local msg res
][
    ; This is using Kaj's func in the zmq context, which hasn't been changed.
    ; Need to look at return value consistency.
    res: zmq-send socket to binary! data either more-to-come flags
]

z-send-multipart-msg: func [
    "Send a multipart message to the 0MQ socket"
    socket "0MQ socket" 
    data  [block!]
    ;?? Do we want to support the no-block flag? 
][
    repeat i (length? data) - 1 [
        if none? z-send-msg/more-to-come socket to binary! data/:i [return none]
    ]
    if none? z-send-msg socket to binary! last data [return none]
    ; Res will be -1 if an error occurs. 
    ; If that's the case, Use zmq-errono to get the exact error code.
    ;either negative? res [zmq-errno] [res]
    true
]


; I think this could use a better name. This is their example directly ported.
; z-set-id shoudl take an identity parameter, and this should have 'random in
; the name. Maybe z-set-socket-id?
z-set-id: func [
    "Set simple random printable identity on socket."
    socket "0MQ socket" 
    /local rand-hex-4 identity
][
    random/seed to-integer checksum/secure to binary! form now/precise
    rand-hex-4: does [skip tail form to-hex random 65'535 -4] ; keep just the last 4 digits of the to-hex result.
    identity: rejoin [rand-hex-4 "-" rand-hex-4]
    print ["Identity set to" mold identity]
    zmq-setsockopt-binary socket ZMQ-CONSTANTS/IDENTITY to binary! identity
    ;zmq-setsockopt socket ZMQ-CONSTANTS/IDENTITY to binary! identity
]

z-get-id: func [
    "Get identity on socket, as string."
    socket "0MQ socket" 
][
    to string! zmq-getsockopt-binary socket ZMQ-CONSTANTS/IDENTITY 255 ; 255 is the max identity size.
]



z-subscribe: func [
    "Subscribe to all incoming messages on a socket."
    socket "0MQ socket"
    /filter "Recieve only messages beginning with given prefix or set of prefixes."
        prefix [any-string! binary! block!] "Prefix used to filter messages. If a block is passed, a message shall be accepted if it matches at least one filter."
][
    if not filter [prefix: #{}]
    ;?? Should we only call setsockopt for any-string! and binary! values, in
    ;   the case where other values are given?
    collect [
        foreach value compose [(prefix)] [
            keep zmq-setsockopt-binary socket ZMQ-CONSTANTS/SUBSCRIBE to binary! value
        ]
    ]
]

; z-subscribe-to-all: func [
;     socket "0MQ socket"
; ][
;     zmq-setsockopt-binary socket ZMQ-CONSTANTS/SUBSCRIBE #{} 0
; ]

z-unsubscribe: func [
    "Unsubscribe a socket subscription filter."
    socket "0MQ socket"
    /filter "Remove an existing prefix or set of prefixes previously subscribed to."
        prefix [any-string! binary! block!] "Prefix used to filter messages. Each value removes one prefix filter instance."
][
    if not filter [prefix: #{}]
    ;?? Should we only call setsockopt for any-string! and binary! values?
    collect [
        foreach value compose [(prefix)] [
            keep zmq-setsockopt-binary socket ZMQ-CONSTANTS/UNSUBSCRIBE to binary! value
        ]
    ]
]

; z-version helper not ported. The R3 extension already returns a tuple for us.


;-------------------------------------------------------------------------------

; //  ---------------------------------------------------------------------
; //  Signal handling
; //
; //  Call s_catch_signals() in your application at startup, and then exit 
; //  your main loop if s_interrupted is ever 1. Works especially well with 
; //  zmq_poll.
; 
; static int s_interrupted = 0;
; static void s_signal_handler (int signal_value)
; {
;     s_interrupted = 1;
; }
; 
; static void s_catch_signals (void)
; {
;     struct sigaction action;
;     action.sa_handler = s_signal_handler;
;     action.sa_flags = 0;
;     sigemptyset (&action.sa_mask);
;     sigaction (SIGINT, &action, NULL);
;     sigaction (SIGTERM, &action, NULL);
; }

