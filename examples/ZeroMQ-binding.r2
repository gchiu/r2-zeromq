REBOL [
    Title:		"ZeroMQ Binding"
    Author:		["Kaj de Vos" "Gregg Irwin"]
    Rights:		"Copyright (c) 2011 Kaj de Vos. All rights reserved."
    License: {
        Redistribution and use in source and binary forms, with or without modification,
        are permitted provided that the following conditions are met:

            * Redistributions of source code must retain the above copyright notice,
              this list of conditions and the following disclaimer.
            * Redistributions in binary form must reproduce the above copyright notice,
              this list of conditions and the following disclaimer in the documentation
              and/or other materials provided with the distribution.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
        ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
        WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
        DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
        FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
        DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
        SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
        CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
        OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
        OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    }
    Needs:		"0MQ >= 2.1"
    Notes:		"Switch the zmq_init call in the new-pool routine for 0MQ <= 2.0.6"
]


context [
    binary: make struct! [value [binary!]] none
    pointer: make struct! [address [long]] none

    set 'address-of func [series [series!]] [
        binary/value: series
        change  third pointer  third binary

        binary/value: none  ; Don't block recycling
        pointer/address
    ]
]


; C library

c-library: load/library either windows?: system/version/4 = 3 [%msvcrt.dll] [%libc.so.6]

copy-memory: make routine! ["Copy memory block."
    target	[long]
    source	[long]
    size	[long]
;	return:	[long]
] c-library "memcpy"


;-------------------------------------------------------------------------------

int-struct: make struct! [value [integer!]] none
bin-struct: make struct! [value [binary!]]  none

bin-to-int: func [binary [binary!] /local struct] [
    struct: make struct! int-struct none
    change third struct binary
    struct/value
]
; This is just to get us rolling on little endian for simple cases. Endianness
; and signedness not taken into account, since we may not want to use this
; long-term.
int-to-bin-8: func [integer [integer!] /local struct] [
    struct: make struct! int-struct reduce [integer]
    append third struct #{00000000}
]

;-------------------------------------------------------------------------------


; 0MQ interface

zmq: load/library join %libzmq.  either windows? [%dll] [%so]

zmq-constants: [
    ;; socket types
    pair    0
    pub     1
    sub     2
    req     3
    rep     4
    dealer  5 ;; >= 0MQ 2.1
    router  6 ;; >= 0MQ 2.1
    pull    7
    push    8

    xreq    5 ;; deprecated in 0MQ 2.1
    xrep    6 ;; deprecated in 0MQ 2.1

    ;; socket options
    hwm         1
    swap        3
    affinity    4
    identity    5
    subscribe   6
    unsubscribe 7
    rate        8
    recovery-ivl 9
    mcast-loop  10
    sndbuf      11
    rcvbuf      12
    rcvmore     13
    fd          14 ;; >= 0MQ 2.1
    events      15 ;; >= 0MQ 2.1
    type        16 ;; >= 0MQ 2.1
    linger      17 ;; >= 0MQ 2.1
    reconnect-ivl 18 ;; >= 0MQ 2.1
    backlog     19 ;; >= 0MQ 2.1
    recovery-ivl-msec 20 ;; >= 0MQ 2.1
    reconnect-ivl-max 21 ;; >= 0MQ 2.1

    ;; send/recv options
    noblock     1
    sndmore     2

    ;; poll options
    pollin      1
    pollout     2
    ;pollerr 4 ;; not used for 0MQ sockets (& we can't support standard sockets)

    ;; device options
    streamer    1 ;; >= 0MQ 2.0.11
    forwarder   2 ;; >= 0MQ 2.0.11
    queue       3 ;; >= 0MQ 2.0.11

    ;; useful error codes
    eintr       4
    eagain      11
]


; I don't like reusing 'zmq here, but if nobody else complains, I guess I can
; live with it. Word reuse outside of small funcs leads to confusion IMO.
zmq: context [
    
    ;!! We're wrapping this with a func of the same name, so we
    ;   give it a slightly special name internally.
    zmq-version*: make routine! ["Return 0MQ version."
        major       [struct! [value [integer!]]]
        minor       [struct! [value [integer!]]]
        patch       [struct! [value [integer!]]]
    ] zmq "zmq_version"

    zmq-init: make routine! ["Return context handle."
;		app-threads	[integer!]  ; For 0MQ <= 2.0.6
        io-threads	[integer!]
;		flags		[integer!]  ; For 0MQ <= 2.0.6
        return: 	[long]
    ] zmq "zmq_init"
    
    ; poll: 1
    
    zmq-term: make routine! ["Clean up context."
        pool		[long]
        return: 	[integer!]
    ] zmq "zmq_term"

    zmq-socket: make routine! ["Open a socket."
        pool		[long]
        type		[integer!]
        return: 	[long]
    ] zmq "zmq_socket"

    ; Socket types    
    ; pair:                0
    ; publish:            1
    ; subscribe:            2
    ; request:            3
    ; reply:                4
    ; extended-request:    5
    ; extended-reply:        6
    ; push:                7
    ; pull:                8

    zmq-close: make routine! ["Clean up a socket from a context."
        socket		[long]
        return: 	[integer!]
    ] zmq "zmq_close"

    zmq-bind: make routine! ["Set up server socket binding."
        socket		[long]
        end-point	[url!]
        return: 	[integer!]
    ] zmq "zmq_bind"
    zmq-connect: make routine! ["Connect to a server socket."
        socket		[long]
        destination	[url!]
        return: 	[integer!]
    ] zmq "zmq_connect"


    ;!! We're wrapping this with a func of the same name, so we
    ;   give it a slightly special name internally.
	zmq-getsockopt*: make routine! ["Get socket option."
		socket		[long]
		name		[integer!]
		value		[binary!]  ; Currently max 255 bytes
		size		[struct! [value [integer!]]]
		return: 	[integer!]
	] zmq "zmq_getsockopt"

;     max-messages:        1
; ;    min-messages:        2
;     swap-size:            3
;     io-affinity:        4
;     identity:            5
;     max-rate:            8
;     recovery-interval:    9
;     loop-back?:            10
;     send-buffer:        11
;     receive-buffer:        12
;     socket-type:        16
	
    ;!! We're wrapping this with a func of the same name, so we
    ;   give it a slightly special name internally.
	zmq-setsockopt*: make routine! ["Set socket option."
		socket		[long]
		name		[integer!]
		value		[binary!]
		size		[integer!]
		return: 	[integer!]
	] zmq "zmq_setsockopt"
	
    ; filter:                6
    ; unsubscribe:        7

    zmq-msg-init-size: make routine! ["Create new message."
        message		[binary!]
        size		[long]
        return: 	[integer!]
    ] zmq "zmq_msg_init_size"
    zmq-msg-init: make routine! ["Initialize new message."
        message		[binary!]
        return: 	[integer!]
    ] zmq "zmq_msg_init"
    zmq-msg-init-data: make routine! ["Convert to new message."
        message		[binary!]
        data		[binary!]
        size		[long]
        free		[long]
        hint		[long]
        return: 	[integer!]
    ] zmq "zmq_msg_init_data"
    zmq-msg-close: make routine! ["Clean up message."
        message		[binary!]
        return: 	[integer!]
    ] zmq "zmq_msg_close"

    zmq-msg-data: make routine! ["Return message data pointer."
        message		[binary!]
        return:		[long]
    ] zmq "zmq_msg_data"
    zmq-msg-size: make routine! ["Return message data size."
        message		[binary!]
        return: 	[long]
    ] zmq "zmq_msg_size"


    ;!! We're wrapping zmq-send and zmq-recv with funcs of the same name, so we
    ;   give them slightly special names internally.
    zmq-send*: make routine! ["Send message."
        socket		[long]
        message		[binary!]
        flags		[integer!]
        return: 	[integer!]
    ] zmq "zmq_send"

    ; Receive flags    
    ;no-block: 1
    
    zmq-recv*: make routine! ["Receive a message."
        socket		[long]
        message		[binary!]
        flags		[integer!]
        return: 	[integer!]
    ] zmq "zmq_recv"


    zmq-errno: make routine! ["Return last status."
        return: 	[integer!]
    ] zmq "zmq_errno"
    
    zmq-strerror: make routine! ["Return status message."
        code		[integer!]
        return:		[string!]
    ] zmq "zmq_strerror"


	zmq-msg-copy: make routine! ["Copy message content to another message."
		target		[binary!]
		source		[binary!]
		return: 	[integer!]
	] zmq "zmq_msg_copy"
	zmq-msg-move: make routine! ["Move message content to another message."
		target		[binary!]
		source		[binary!]
		return: 	[integer!]
	] zmq "zmq_msg_move"

    zmq-poll: make routine! ["Wait for selected events or timeout."
        events      [binary!]
        length      [integer!]
        timeout     [long]
        return:     [integer!]
    ] zmq "zmq_poll"
    
    ; poll-in:        1
    ; poll-out:       2
    ; poll-error:     4

    zmq-device: make routine! [ "Start built-in 0MQ device"
        device      [integer!]
        frontend    [long]
        backend     [long]
        return:     [integer!]
    ] zmq "zmq_device"


;-------------------------------------------------------------------------------


    ; Higher level interface

    zmq-version: has [major minor patch] [
        major: make struct! [value [integer!]] none
        minor: make struct! [value [integer!]] none
        patch: make struct! [value [integer!]] none
        
        zmq-version* major minor patch
        
        to tuple! reduce [major/value minor/value patch/value]
    ]

    ;?? Is this safe? I know we're not multi-threaded, but context-level vars
    ;   in this...context, seem like a bad idea. -GSI
    message: head insert/dup  copy #{}  #{00} 42  ; Hopefully 0MQ isn't compiled to use larger Very Small Messages

    ;!! This is still Kaj's func and logic, just renamed.
    zmq-send: funct [  ; Send message.
        socket  [integer!]
        data    [string! binary!]
        flags   [integer!]
    ][
        data: to binary! data
        either zero? zmq-msg-init-data message  data  length? data  0 0 [
            either zero? zmq-send* socket message flags [
                zero? zmq-msg-close message
            ][
                zmq-msg-close message
                no
            ]
        ][
            no
        ]
    ]

    ;!! This is still Kaj's func and logic, just renamed.
    zmq-recv: funct [  ; Receive a message.
        socket  [integer!]
        data    [binary!]
        flags   [integer!]
        /local res
    ][
        either zero? zmq-msg-init message [
            either zero? zmq-recv* socket message flags [
                source: zmq-msg-data message
                size: zmq-msg-size message

                either size > length? data [
                    insert/dup  tail data  #{00}  size - length? data
                ][
                    clear skip data size
                ]
                copy-memory  address-of data  source size

                zero? zmq-msg-close message
            ][
                zmq-msg-close message
                no
            ]
        ][
            no
        ]
    ]


    ;-- This might be a way to combine the int and binary options into single
    ;   funcs. For now, though, these are here to make the other wrapper/
    ;   emulators easier to write.
    zmq-setsockopt: func [
        socket [integer!]
        name   [integer!]
        value  [any-string! binary! integer!]
    ] [
        value: either integer? value [int-to-bin-8 value] [to binary! value]
        ;print [socket  name  length? value  mold value  to string! value]
        zmq-setsockopt* socket name value length? value
    ]
    
    zmq-getsockopt: func [
        socket [integer!]
        name   [integer!]
        /size
          sz   [integer!]
        /int   "Get an integer socket option value. Overrides size arg if given."
        /local buff struct res
    ] [
        if int [sz: 8]
        buff: head insert/dup copy #{} #{00} any [sz 255]
        struct: make struct! int-struct reduce [any [sz 255]]
        res: zmq-getsockopt* socket name buff struct
        either res <> -1 [
            res: copy/part buff struct/value
            either int [bin-to-int res] [res]
        ] [none]
    ]

    
    

]

export: func [ctx [object!] words [word! block!]] [
    foreach word compose [(words)] [
        set word get in ctx word
    ]
]

export zmq [
    zmq-version
    zmq-init zmq-term
    zmq-socket zmq-close zmq-getsockopt zmq-setsockopt
    zmq-bind zmq-connect
    zmq-msg-init-size zmq-msg-init zmq-mst-init-data
    zmq-msg-close zmq-msg-data zmq-msg-size
    zmq-send zmq-recv
    zmq-errno zmq-strerror
    zmq-msg-copy zmq-msg-move
    zmq-poll
    zmq-device
]

;-------------------------------------------------------------------------------
;-- Wrappers
;
;   These are here to provide compatible interfaces to the 0MQ binding
;   by Andreas. i.e. the separate int and binary funcs.

; zmq-setsockopt-binary: func [
;     socket [integer!]
;     name   [integer!]
;     value  [binary!]
; ] [
;     zmq/zmq-setsockopt* socket name value length? value
; ]
zmq-setsockopt-binary: func [
    socket [integer!]
    name   [integer!]
    value  [binary!]
] [
    zmq-setsockopt socket name value
]

; zmq-getsockopt-binary: func [
;     socket [integer!]
;     name   [integer!]
;     ;/size ; << TBD
;       sz   [integer!]
;     /local buff struct res
; ] [
;     buff: head insert/dup copy #{} #{00} any [sz 255]
;     struct: make struct! int-struct reduce [any [sz 255]]
;     res: zmq/zmq-getsockopt* socket name buff struct
;     either res <> -1 [copy/part buff struct/value] [none]
; ]
zmq-getsockopt-binary: func [
    socket [integer!]
    name   [integer!]
    ;/size ; << TBD
      sz   [integer!]
] [
    zmq-getsockopt socket name
]

zmq-setsockopt-int: func [
    socket [integer!]
    name   [integer!]
    value  [integer!]
] [
    zmq-setsockopt socket name value
]

zmq-getsockopt-int: func [
    socket [integer!]
    name   [integer!]
] [
    zmq-getsockopt/int socket name
]


;-------------------------------------------------------------------------------

comment {
; Hello World client/server

server: funct [] [
    pool: zmq/new-pool 1
    ; For 0MQ <= 2.0.6:
;	pool: zmq/new-pool 1 1 0

    socket: zmq/open pool zmq/reply
    zmq/serve socket tcp://*:5555

    print "Awaiting requests..."

    data: copy #{}  ; Reuse buffer for each message

    forever [
        zmq/receive socket data 0

        print ["Received request:"  to-string data]

        wait 1
        zmq/send socket  to-binary "World"  0
    ]
    ;zmq/close socket
    ;zmq/end-pool pool
]

client: funct [] [
    pool: zmq/new-pool 1
    ; For 0MQ <= 2.0.6:
;	pool: zmq/new-pool 1 1 0

    print "Connecting to Hello World server..."

    socket: zmq/open pool zmq/request
    zmq/connect socket tcp://localhost:5555

    data: copy #{}  ; Reuse buffer for each message

    repeat count 10 [
        print ["Sending request" count]

        zmq/send socket  to-binary "Hello"  0
        zmq/receive socket data 0

        print rejoin ["Received reply " count ": "  to-string data]
    ]
    zmq/close socket
    zmq/end-pool pool
]

;server
;client

}
